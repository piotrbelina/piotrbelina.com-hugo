---
title: "Adding trace id to access log with rs/zerolog"
date: 2024-03-25T21:38:08+01:00
tags: ["go"]
---
This is an code based on [opentelemetry dice example](https://github.com/open-telemetry/opentelemetry-go/tree/main/example/dice) which uses [rs/zerolog](https://github.com/rs/zerolog) and adds trace id to logs.

Working code example can be found on [GitHub](https://github.com/piotrbelina/code-for-blog/tree/main/zerolog-traceid)

## TraceIDHandler
This is a standard access logger. What is extra here is 

```traceID := traceIDHandler("trace_id", "span_id")```

`traceIDHandler` adds those two fields to zerolog if it finds them in context.

```go
func requestLogger(next http.Handler) http.Handler {
	h := hlog.NewHandler(logger)
	accessHandler := hlog.AccessHandler(func(r *http.Request, status, size int, duration time.Duration) {
		hlog.FromRequest(r).Info().
			Str("method", r.Method).
			Stringer("url", r.URL).
			Int("status", status).
			Int("size", size).
			Dur("duration", duration).
			Msg("access log")
	})
	addr := hlog.RemoteAddrHandler("ip")
	userAgent := hlog.UserAgentHandler("user_agent")
	traceID := traceIDHandler("trace_id", "span_id")
	requestID := hlog.RequestIDHandler("req_id", "X-Request-Id")

	return h(addr(userAgent(traceID(requestID(accessHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		next.ServeHTTP(w, r)
	})))))))
}

func traceIDHandler(traceFieldKey, spanFieldKey string) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			spanContext := trace.SpanFromContext(r.Context()).SpanContext()
			traceID := spanContext.TraceID().String()
			spanID := spanContext.SpanID().String()
			if traceID != "" {
				l := zerolog.Ctx(r.Context())
				l.UpdateContext(func(c zerolog.Context) zerolog.Context {
					return c.Str(traceFieldKey, traceID)
				})
			}
			if spanID != "" {
				l := zerolog.Ctx(r.Context())
				l.UpdateContext(func(c zerolog.Context) zerolog.Context {
					return c.Str(spanFieldKey, spanID)
				})
			}
			next.ServeHTTP(w, r)
		})
	}
}

```

## Adding requestLogger middleware
To have access logger working, we need to change
```go
handler := otelhttp.NewHandler(mux, "/")
```
to
```go
handler := otelhttp.NewHandler(requestLogger(mux), "/")
```
## Contextual logging in HTTP handler
To have proper tracing ids in logs, we need to pass context. In `func rolldice`
```go
//...
roll := 1 + rand.Intn(6)

rollValueAttr := attribute.Int("roll.value", roll)
span.SetAttributes(rollValueAttr)
rollCnt.Add(ctx, 1, metric.WithAttributes(rollValueAttr))

l := zerolog.Ctx(ctx)
l.Info().Ctx(ctx).Int("value", roll).Msg("roll")
//...
```
## Testing
We can test our endpoint with curl. In response we are getting `X-Request-Id`.
```
$ curl -v 127.0.0.1:8888/rolldice
*   Trying 127.0.0.1:8888...
* Connected to 127.0.0.1 (127.0.0.1) port 8888 (#0)
> GET /rolldice HTTP/1.1
> Host: 127.0.0.1:8888
> User-Agent: curl/8.1.2
> Accept: */*
>
< HTTP/1.1 200 OK
< X-Request-Id: co0totvnl535vf6rnob0
< Date: Sun, 25 Feb 2024 22:14:57 GMT
< Content-Length: 2
< Content-Type: text/plain; charset=utf-8
<
6
* Connection #0 to host 127.0.0.1 left intact
```

In server logs there are more information. We can see that our request have trace id `5fdc14f10cb4c2d1f253f853c16162e7`. Both log messages share the same trace id. 

```json
❯ go run .
// first log "roll"
{"level":"info","ip":"127.0.0.1:59065","user_agent":"curl/8.1.2","trace_id":"5fdc14f10cb4c2d1f253f853c16162e7","span_id":"47e1ebf518ef9e7d","req_id":"co0totvnl535vf6rnob0","value":6,"time":"2024-03-25T21:20:07+01:00","message":"roll"}
// access log, both have same trace id
{"level":"info","ip":"127.0.0.1:59065","user_agent":"curl/8.1.2","trace_id":"5fdc14f10cb4c2d1f253f853c16162e7","span_id":"47e1ebf518ef9e7d","req_id":"co0totvnl535vf6rnob0","method":"GET","url":"/rolldice","status":200,"size":2,"duration":1.260792,"time":"2024-03-25T21:20:07+01:00","message":"access log"}

{
        "Name": "roll",
        "SpanContext": {
                "TraceID": "5fdc14f10cb4c2d1f253f853c16162e7",
                "SpanID": "7f39c00b122c6044",
                "TraceFlags": "01",
                "TraceState": "",
                "Remote": false
        },
        "Parent": {
                "TraceID": "5fdc14f10cb4c2d1f253f853c16162e7",
                "SpanID": "47e1ebf518ef9e7d",
                "TraceFlags": "01",
                "TraceState": "",
                "Remote": false
        },
        "SpanKind": 1,
        "StartTime": "2024-03-25T21:20:07.035488+01:00",
        "EndTime": "2024-03-25T21:20:07.036643458+01:00",
        "Attributes": [
                {
                        "Key": "roll.value",
                        "Value": {
                                "Type": "INT64",
                                "Value": 6
                        }
                }
        ],
        "Events": null,
        "Links": null,
        "Status": {
                "Code": "Unset",
                "Description": ""
        },
        "DroppedAttributes": 0,
        "DroppedEvents": 0,
        "DroppedLinks": 0,
        "ChildSpanCount": 0,
        "Resource": [
                {
                        "Key": "service.name",
                        "Value": {
                                "Type": "STRING",
                                "Value": "unknown_service:___go_build_zerolog_traceid"
                        }
                },
                {
                        "Key": "telemetry.sdk.language",
                        "Value": {
                                "Type": "STRING",
                                "Value": "go"
                        }
                },
                {
                        "Key": "telemetry.sdk.name",
                        "Value": {
                                "Type": "STRING",
                                "Value": "opentelemetry"
                        }
                },
                {
                        "Key": "telemetry.sdk.version",
                        "Value": {
                                "Type": "STRING",
                                "Value": "1.24.0"
                        }
                }
        ],
        "InstrumentationLibrary": {
                "Name": "rolldice",
                "Version": "",
                "SchemaURL": ""
        }
}
{
        "Name": "/",
        "SpanContext": {
                "TraceID": "5fdc14f10cb4c2d1f253f853c16162e7",
                "SpanID": "47e1ebf518ef9e7d",
                "TraceFlags": "01",
                "TraceState": "",
                "Remote": false
        },
        "Parent": {
                "TraceID": "00000000000000000000000000000000",
                "SpanID": "0000000000000000",
                "TraceFlags": "00",
                "TraceState": "",
                "Remote": false
        },
        "SpanKind": 2,
        "StartTime": "2024-03-25T21:20:07.035326+01:00",
        "EndTime": "2024-03-25T21:20:07.036709792+01:00",
        "Attributes": [
                {
                        "Key": "http.method",
                        "Value": {
                                "Type": "STRING",
                                "Value": "GET"
                        }
                },
                {
                        "Key": "http.scheme",
                        "Value": {
                                "Type": "STRING",
                                "Value": "http"
                        }
                },
                {
                        "Key": "net.host.name",
                        "Value": {
                                "Type": "STRING",
                                "Value": "127.0.0.1"
                        }
                },
                {
                        "Key": "net.host.port",
                        "Value": {
                                "Type": "INT64",
                                "Value": 8888
                        }
                },
                {
                        "Key": "net.sock.peer.addr",
                        "Value": {
                                "Type": "STRING",
                                "Value": "127.0.0.1"
                        }
                },
                {
                        "Key": "net.sock.peer.port",
                        "Value": {
                                "Type": "INT64",
                                "Value": 59065
                        }
                },
                {
                        "Key": "user_agent.original",
                        "Value": {
                                "Type": "STRING",
                                "Value": "curl/8.1.2"
                        }
                },
                {
                        "Key": "http.target",
                        "Value": {
                                "Type": "STRING",
                                "Value": "/rolldice"
                        }
                },
                {
                        "Key": "net.protocol.version",
                        "Value": {
                                "Type": "STRING",
                                "Value": "1.1"
                        }
                },
                {
                        "Key": "http.route",
                        "Value": {
                                "Type": "STRING",
                                "Value": "/rolldice"
                        }
                },
                {
                        "Key": "http.wrote_bytes",
                        "Value": {
                                "Type": "INT64",
                                "Value": 2
                        }
                },
                {
                        "Key": "http.status_code",
                        "Value": {
                                "Type": "INT64",
                                "Value": 200
                        }
                }
        ],
        "Events": null,
        "Links": null,
        "Status": {
                "Code": "Unset",
                "Description": ""
        },
        "DroppedAttributes": 0,
        "DroppedEvents": 0,
        "DroppedLinks": 0,
        "ChildSpanCount": 1,
        "Resource": [
                {
                        "Key": "service.name",
                        "Value": {
                                "Type": "STRING",
                                "Value": "unknown_service:___go_build_zerolog_traceid"
                        }
                },
                {
                        "Key": "telemetry.sdk.language",
                        "Value": {
                                "Type": "STRING",
                                "Value": "go"
                        }
                },
                {
                        "Key": "telemetry.sdk.name",
                        "Value": {
                                "Type": "STRING",
                                "Value": "opentelemetry"
                        }
                },
                {
                        "Key": "telemetry.sdk.version",
                        "Value": {
                                "Type": "STRING",
                                "Value": "1.24.0"
                        }
                }
        ],
        "InstrumentationLibrary": {
                "Name": "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp",
                "Version": "0.49.0",
                "SchemaURL": ""
        }
}

```

## Resources
* [https://opentelemetry.io/docs/languages/go/getting-started/](https://opentelemetry.io/docs/languages/go/getting-started/)
* [A Complete Guide to Logging in Go with Zerolog](https://betterstack.com/community/guides/logging/zerolog/#using-zerolog-in-a-web-application)
* https://github.com/rs/zerolog
