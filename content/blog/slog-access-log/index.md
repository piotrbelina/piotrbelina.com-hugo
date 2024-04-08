---
title: "slog access log"
date: 2024-04-08T22:28:22+02:00
tags: ["go"]
---

Recently I wanted to learn more about Go’s slog package. Also for some other project I needed to create an access logger. I could not find a solution so I decided to create my own. I was inspired by two solutions:
- [rs/zerolog/hlog package](https://github.com/rs/zerolog/tree/master/hlog)
- [great guide at betterstack](https://betterstack.com/community/guides/logging/logging-in-go)

Working code example can be found on [GitHub](https://github.com/piotrbelina/code-for-blog/tree/main/slog-access-log)


## Requirements
In my logger I wanted to have all standard data:
* request duration,
* status code,
* bytes written,
* method,
* url,
* user agent,
* remote addr

plus some extra
* correlation id - it is useful to group log entries from the same request,
* custom header field - useful for custom extensions. Here in this example I am adding `X-Forwarded-For` which contains user IP in case of the server being behind the proxy.

## Creating middleware
`AccessLogMiddleware` takes a closure which is responsible for logging the request. 

```go
alog := AccessLogMiddleware(func(r *http.Request, status, size int, duration time.Duration) {
	slog.InfoContext(
		r.Context(),
		"access log",
		slog.String("method", r.Method),
		slog.String("url", r.URL.RequestURI()),
		slog.String("user_agent", r.UserAgent()),
		slog.String("remote_addr", r.RemoteAddr),
		slog.String("remote_host", getHost(r.RemoteAddr)),
		slog.String("referer", r.Referer()),
		slog.String("proto", r.Proto),
		slog.Duration("took", duration),
		slog.Int("status_code", status),
		slog.Int("bytes", size),
	)
})

```

When creating the logger, I needed to add custom `ContextHandler` which is responsible for logging `slog.Attr` added to request’s context.

```go
handler := &ContextHandler{slog.NewTextHandler(os.Stdout, nil)}
logger := slog.New(handler)
slog.SetDefault(logger)
```

Here is full example of main function.

```go
func main() {
	handler := &ContextHandler{slog.NewTextHandler(os.Stdout, nil)}
	logger := slog.New(handler)
	slog.SetDefault(logger)

	mux := http.NewServeMux()
	mux.HandleFunc("/ping", pingHandler)

	addr := ":8888"
	slog.Info("starting listening", slog.String("addr", addr))

	alog := AccessLogMiddleware(func(r *http.Request, status, size int, duration time.Duration) {
		slog.InfoContext(
			r.Context(),
			"access log",
			slog.String("method", r.Method),
			slog.String("url", r.URL.RequestURI()),
			slog.String("user_agent", r.UserAgent()),
			slog.String("remote_addr", r.RemoteAddr),
			slog.String("remote_host", getHost(r.RemoteAddr)),
			slog.String("referer", r.Referer()),
			slog.String("proto", r.Proto),
			slog.Duration("took", duration),
			slog.Int("status_code", status),
			slog.Int("bytes", size),
		)
	})
	forwarded := CustomHeaderHandler("x-forwarded-for", "X-Forwarded-For")

	err := http.ListenAndServe(addr, forwarded(alog(mux)))
	if err != nil {
		slog.Error(err.Error())
	}
}


func pingHandler(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "test")
	fmt.Fprintf(w, "pong")
}
```

## AccessLogMiddleware

```go
// AccessLogMiddleware creates http.Handler which logs http requests.
// It measures duration of request. It records response code and response size.
// It also adds correlation ID to the log entry.
func AccessLogMiddleware(f func(r *http.Request, status, size int, duration time.Duration)) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // start is needed to measure the request duration
			start := time.Now()

            // this writer is needed to record status code and bytes written
			lrw := newLoggingResponseWriter(w)

			correlationID := xid.New().String()

            // we are creating a copy of request's context
			ctx := AppendCtx(r.Context(), slog.String("correlation_id", correlationID))
            // replacing request with updated context
			r = r.WithContext(ctx)

			w.Header().Add("X-Correlation-ID", correlationID)

            // executing f closure in defer so the request will be logged even if the code panics
			defer func() {
				f(r, lrw.statusCode, lrw.bytes, time.Since(start))
			}()

			next.ServeHTTP(lrw, r)
		})
	}
}

```

## ContextHandler

```go

type ctxKey string

const slogFields ctxKey = "slog_fields"

// ContextHandler is used to log slog.Attrs added to context.Context
type ContextHandler struct {
	slog.Handler
}

func (h ContextHandler) Handle(ctx context.Context, r slog.Record) error {
	if attrs, ok := ctx.Value(slogFields).([]slog.Attr); ok {
		for _, v := range attrs {
			r.AddAttrs(v)
		}
	}
	return h.Handler.Handle(ctx, r)
}

// AppendCtx returns a copy of context.Context with value named slogFields containing []slog.Attr needed for ContextHandler
func AppendCtx(parent context.Context, attr slog.Attr) context.Context {
	if parent == nil {
		parent = context.Background()
	}

	if v, ok := parent.Value(slogFields).([]slog.Attr); ok {
		v = append(v, attr)
		return context.WithValue(parent, slogFields, v)
	}
	v := []slog.Attr{}
	v = append(v, attr)
	return context.WithValue(parent, slogFields, v)
}
```

## Testing

### Sending the request

```
$ curl -v -H "X-Forwarded-For: 192.168.1.1"  http://127.0.0.1:8888/ping\?1
*   Trying 127.0.0.1:8888...
* Connected to 127.0.0.1 (127.0.0.1) port 8888
> GET /ping?1 HTTP/1.1
> Host: 127.0.0.1:8888
> User-Agent: curl/8.4.0
> Accept: */*
> X-Forwarded-For: 192.168.1.1
>
< HTTP/1.1 200 OK
< X-Correlation-Id: coa54o197i620lq8tchg
< Date: Mon, 08 Apr 2024 20:24:00 GMT
< Content-Length: 4
< Content-Type: text/plain; charset=utf-8
<
* Connection #0 to host 127.0.0.1 left intact
pong%
```

### Running the server
We can see here that the `text` log in `pingHandler` have the same correlation ID as access log.
#### Text log
```
time=2024-04-08T22:23:44.886+02:00 level=INFO msg="starting listening" addr=:8888
time=2024-04-08T22:24:00.325+02:00 level=INFO msg=test x-forwarded-for=192.168.1.1 correlation_id=coa54o197i620lq8tchg
time=2024-04-08T22:24:00.325+02:00 level=INFO msg="access log" method=GET url=/ping?1 user_agent=curl/8.4.0 remote_addr=127.0.0.1:61846 remote_host=127.0.0.1 referer="" proto=HTTP/1.1 took=149.708µs status_code=200 bytes=4 x-forwarded-for=192.168.1.1 correlation_id=coa54o197i620lq8tchg
```

#### JSON log
```
{"time":"2024-04-08T22:25:18.09855+02:00","level":"INFO","msg":"starting listening","addr":":8888"}
{"time":"2024-04-08T22:25:21.016254+02:00","level":"INFO","msg":"test","x-forwarded-for":"192.168.1.1","correlation_id":"coa55c997i6232p4q1tg"}
{"time":"2024-04-08T22:25:21.01635+02:00","level":"INFO","msg":"access log","method":"GET","url":"/ping?1","user_agent":"curl/8.4.0","remote_addr":"127.0.0.1:61853","remote_host":"127.0.0.1","referer":"","proto":"HTTP/1.1","took":95291,"status_code":200,"bytes":4,"x-forwarded-for":"192.168.1.1","correlation_id":"coa55c997i6232p4q1tg"}
```
