---
title: "Healthchecks - two most important Pod endpoints - Readiness & Liveness Check with Go examples"
date: 2023-11-12T23:23:40+01:00
tags: ["go", "kubernetes"]
---

Every application should contain at least two endpoints:
* readiness check,
* health check.

Readiness check should indicate when the app is ready to serve traffic. It should allow traffic when the app is correctly initialized. For example it should wait for the database connection to be established. The connection to cache or external API as well.  This probe allows to cut off the traffic in case the app is unable to handle it. For example when downstream service is down or the app is processing large data. In this case you don’t want to kill the app, but you don’t want to handle these requests as well.

The liveness probe (or healthcheck) is used to periodically check the state of the app. The kubelet uses it to check when to restart the container.

The liveness probe should be as lightweight as possible. It should give information if the app is responsive, whether load balancer can open a connection and have a response in given time.
## Basic example

Here I will show a simple readiness and liveness probe. The common endpoints for those probes are `/ready` or `/readyz` and `/health` or `/healthz`. 

```go
package main

import (
	"log"
	"net/http"
	"sync/atomic"
	"time"
)

// using sync/atomic to guarantee concurrency safety
var ready atomic.Bool

func main() {
	ready.Store(false)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/ready", readyHandler)
	go func() {
		// connecting to db, cache, downstream services...
		time.Sleep(time.Second * 5) // let's wait to simulate setting up the app
		ready.Store(true)
	}()
	log.Fatal(http.ListenAndServe(":8080", mux))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok\n"))
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	if ready.Load() {
		w.WriteHeader(http.StatusOK) // 200
		w.Write([]byte("ok\n"))
	} else {
		w.WriteHeader(http.StatusServiceUnavailable) // 503
		w.Write([]byte("not ready\n"))
	}
}
```


```
$ go run main.go &; while sleep 1; do curl localhost:8080/ready; done
[1] 14906
curl: (7) Failed to connect to localhost port 8080 after 5 ms: Couldn't connect to server
not ready
not ready
not ready
not ready
ok
ok
```

Here you can find an example Pod manifest to deploy our app with both probes.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probes
spec:
  containers:
    - name: probes
      image: probes
      livenessProbe:
        httpGet:
          port: 8080
          path: /health
        initialDelaySeconds: 3
        periodSeconds: 3
      readinessProbe:
        httpGet:
          port: 8080
          path: /ready
        initialDelaySeconds: 5
        periodSeconds: 5
```
## Using third party library
Go ecosystem provides several packages, which makes the job easier to create the healthchecks.

* [alexliesenfeld/health: A simple and flexible health check library for Go.](https://github.com/alexliesenfeld/health)
## Reference
* [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
* [Kubernetes Liveness and Readiness Probes: How to Avoid Shooting Yourself in the Foot](https://blog.colinbreck.com/kubernetes-liveness-and-readiness-probes-how-to-avoid-shooting-yourself-in-the-foot/)
* [Kubernetes Probes How to use readiness, liveness, and startup probes](https://www.innoq.com/en/blog/2020/03/kubernetes-probes/)
* [Liveness Probes are Dangerous](https://srcco.de/posts/kubernetes-liveness-probes-are-dangerous.html)
