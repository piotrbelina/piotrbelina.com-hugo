---
title: "Serving Static Website With Go"
date: 2023-10-25T17:12:31+02:00
tags: ["go", "webdev"]
---

# Serving static website in Go

I would like to describe here how to serve static content with Go. Go `http` package provides handy function [`http.FileServer`](https://pkg.go.dev/net/http#FileServer) to serve such content. `FileServer` also allows to browse files when `index.html` is missing in a catalog.
## Preparing files
Let’s create such structure. 

```bash
$ tree
.
├── assets
│   ├── page.html
│   └── styles
│       └── main.css
└── main.go
```

```
File: assets/page.html

<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Document</title>
    <link rel="stylesheet" href="/styles/main.css">
</head>
<body>
    <h1>Hello world!</h1>
</body>
</html>
```

```
File: assets/styles/main.css

body {
    background-color: #114FFF;
    color: #FFC14B;
}
```

## Serving only static content 
If you would like to serve only static content, you can pass `FileServer` handler to root path. 

```go
package main

import (
	"log"
	"net/http"
)

func main() {
	fs := http.FileServer(http.Dir("./assets"))
	http.Handle("/", fs)

	addr := ":8000"
	log.Printf("Listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
```

You can run it with
```
$ go run main.go
2023/10/25 17:16:13 Listening on :8000
```
Then you can check your browser with at [http://127.0.0.1:8000/page.html](http://127.0.0.1:8000/page).html and you should see `Hello world!`. When you go to [http://127.0.0.1:8000/](http://127.0.0.1:8000/) you can see the file listing. 
## Serving static assets for specific path
If you would like to serve only some portion of the routes with FileServer use [`http.StripPrefix`](https://pkg.go.dev/net/http#StripPrefix) . In this example`StripPrefix` will remove `/assets/` part from `/assets/styles/main.css` request. It is necessary because `FileServer` does not know about `assets` part. It only see `styles/main.css`

```go
package main

import (
	"fmt"
	"log"
	"net/http"
)


func indexHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, `<html><head><link rel="stylesheet"" href="/assets/styles/main.css"></head><body>Hello %s</body></html>`, r.URL.Path[1:])
}

func main() {
	fs := http.FileServer(http.Dir("./assets"))
	http.Handle("/assets/", http.StripPrefix("/assets/", fs))
	http.HandleFunc("/", indexHandler)

	addr := ":8000"
	log.Printf("Listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
```

Now running this 
```
$ go run main.go
2023/10/25 17:16:13 Listening on :8000
```
and going to [http://127.0.0.1:8000/World](http://127.0.0.1:8000/World) should show `Hello World` with styles. 
