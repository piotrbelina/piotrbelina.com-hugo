---
title: "Go Graceful Shutdown"
date: 2023-11-27T22:55:29+01:00
tags: ["go", "kubernetes"]
---

Graceful shutdown is a technique used to smoothly terminate an app. It allows the clients to receive data from the app. Also it gives time for the load balancer to deregister it and not send a traffic to it.

```go
// this is not an app with graceful shutdown
package main

import (
    "fmt"
    "log"
    "net/http"
    "time"
)

// this request takes long time to complete
func indexHandler(w http.ResponseWriter, r *http.Request) {
    log.Println("got request")
    time.Sleep(10 * time.Second)
    fmt.Fprintf(w, "ok\n")
    log.Println("finished request")
}

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/", indexHandler)

    log.Printf("Starting listening")
    srv := &http.Server{
        Addr:    ":8080",
        Handler: mux,
    }
    log.Fatal(srv.ListenAndServe())
}
```

Let’s consider following example without graceful shutdown. We have here an `indexHandler` which takes significant time to complete (here 10 seconds).  If we run it and then we (we or for example Kubernetes) send an interrupt signal to the app (Ctrl+C), it will cause the process to immediately exist.
```
$ go run main.go
2023/11/13 22:14:12 Starting listening
2023/11/13 22:43:56 got request
^C
Process finished with the exit code 130 (interrupted by signal 2: SIGINT)
```

If we send a request and in the middle of the request the server gets an interrupt signal, this will cause an empty reply. This can result in sudden spike of errors as lots of clients don’t get a response.
```
$ curl 127.0.0.1:8080 -v
*   Trying 127.0.0.1:8080...
* Connected to 127.0.0.1 (127.0.0.1) port 8080 (#0)
> GET / HTTP/1.1
> Host: 127.0.0.1:8080
> User-Agent: curl/8.1.2
> Accept: */*
>
* Empty reply from server
* Closing connection 0
curl: (52) Empty reply from server
```

## Implementing graceful shutdown
To do it better, we will need to listen for the interrupt signal. When it arrives, we need to give some time for the requests in progress to finish and disable the traffic in healthcheck.

Here is a full example.

The main difference is:
* we are using [`signal.NotifyContext`](https://pkg.go.dev/os/signal#NotifyContext) (you can use [`signal.Notify`](https://pkg.go.dev/os/signal#Notify) as well). [`NotifyContext`](https://henvic.dev/posts/signal-notify-context/) was introduced in Go 1.16 and it returns Context instead of channel.
* we are starting the server with `srv.ListenAndServe()` in goroutine 
* to prevent immediate exit, we are waiting for `<-ctx.Done()`
* then we are sleeping for some time to allow load balancer to deregister
* finally finishing with `srv.Shutdown(ctxTimeout)`

```go
package main

import (
    "context"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/signal"
    "sync/atomic"
    "syscall"
    "time"
)

var ready atomic.Bool

func healthHandler(w http.ResponseWriter, r *http.Request) {
    if ready.Load() {
        w.WriteHeader(http.StatusOK) // 200
        w.Write([]byte("ok\n"))
    } else {
        w.WriteHeader(http.StatusServiceUnavailable) // 503
        w.Write([]byte("not ready\n"))
    }
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
    log.Println("got request")
    time.Sleep(10 * time.Second)
    fmt.Fprintf(w, "ok\n")
    log.Println("finished request")
}

func disableTraffic() {
    ready.Store(false)
    log.Printf("traffic disabled")
}

func main() {
    ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer stop()

    mux := http.NewServeMux()
    mux.HandleFunc("/health", healthHandler)
    mux.HandleFunc("/", indexHandler)

    srv := &http.Server{
        Addr:    ":8082",
        Handler: mux,
    }

    go func() {
        log.Printf("Starting listening")
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()
    log.Printf("The server is ready to listen and serve")

    // enable traffic
    ready.Store(true)

    // Block until a signal is received.
    <-ctx.Done()
    log.Println("Got shutdown signal")

    disableTraffic()

    // wait for kubernetes to deregister, duration has to be greater than healtcheck probe time
    time.Sleep(15 * time.Second)

    // ctxTimeout will force shutdown after 5 seconds
    ctxTimeout, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    log.Printf("Service is shutting down")
    // We received an interrupt signal, shut down.

    if err := srv.Shutdown(ctxTimeout); err != nil {
        // Error from closing listeners, or context timeout:
        log.Printf("HTTP server Shutdown: %v", err)
    }
    log.Printf("Bye")
}
```

This time although the request took 10 seconds to finish, we got 200 OK response with ok body. 

```
$ curl 127.0.0.1:8080 -v
*   Trying 127.0.0.1:8080...
* Connected to 127.0.0.1 (127.0.0.1) port 8080 (#0)
> GET / HTTP/1.1
> Host: 127.0.0.1:8080
> User-Agent: curl/8.1.2
> Accept: */*
>
< HTTP/1.1 200 OK
< Date: Mon, 13 Nov 2023 21:12:43 GMT
< Content-Length: 3
< Content-Type: text/plain; charset=utf-8
< Connection: close
<
ok
* Closing connection 0

---

$ go run main.go
2023/11/13 22:46:28 Starting listening
2023/11/13 22:46:28 The server is ready to listen and serve
2023/11/13 22:46:32 got request
^C
2023/11/13 22:46:34 Got shutdown signal
2023/11/13 22:46:34 traffic disabled
2023/11/13 22:46:42 finished request
2023/11/13 22:46:49 Service is shutting down
2023/11/13 22:46:49 Bye
```
