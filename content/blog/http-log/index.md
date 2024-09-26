---
title: "HTTP logger with slog"
date: 2024-04-24T11:04:14+02:00
tags: ["go", "slog"]
---

I wanted to create a logging middleware for HTTP client.

Working code example you can find on [GitHub](https://github.com/piotrbelina/code-for-blog/tree/main/http-log)

The basic structure is 

```go
type LoggingTransport struct {
   rt http.RoundTripper
}

func (t *LoggingTransport) RoundTrip(r *http.Request) (*http.Response, error) {
    // do before request is sent, ex. start timer, log request
    resp, err := t.rt.RoundTrip(r)
    // do after the response is received, ex. end timer, log response
    return resp, err
}
```

I found this code in [Kubernetes source](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/client-go/transport/round_trippers.go#L459) and I liked this implementation, I decided to adjust it to my needs.

## Using `WithOptions` pattern

In this example, I am using `WithOptions` pattern. This pattern sets sane defaults and allows to customize structs.

```go
type Option func(transport *LoggingTransport)

func NewLoggingTransport(options ...Option) *LoggingTransport {
	t := &LoggingTransport{
		rt:             http.DefaultTransport,
		logger:         slog.Default(),
		detailedTiming: false,
	}

	for _, option := range options {
		option(t)
	}

	return t
}

func WithRoundTripper(rt http.RoundTripper) Option {
	return func(t *LoggingTransport) {
		t.rt = rt
	}
}

func WithLogger(logger *slog.Logger) Option {
	return func(t *LoggingTransport) {
		t.logger = logger
	}
}

func WithDetailedTiming(level slog.Level) Option {
	return func(t *LoggingTransport) {
		t.detailedTiming = true
		t.detailedTimingLevel = level
	}
}

```

## Creating requestInfo
This is a struct copied from Kubernetes source. It has all info needed for logging. It also stores durations from `net/http/httptrace`

```go
// requestInfo keeps track of information about a request/response combination
type requestInfo struct {
	RequestHeaders http.Header
	RequestMethod  string
	RequestURL     string

	ResponseStatus  string
	ResponseHeaders http.Header
	ResponseErr     error

	muTrace          sync.Mutex // Protect trace fields
	DNSLookup        time.Duration
	Dialing          time.Duration
	GetConnection    time.Duration
	TLSHandshake     time.Duration
	ServerProcessing time.Duration
	ConnectionReused bool

	Duration time.Duration
}

func newRequestInfo(r *http.Request) *requestInfo {
	return &requestInfo{
		RequestURL:     r.URL.String(),
		RequestMethod:  r.Method,
		RequestHeaders: r.Header,
	}
}

```
## Logging request info

```go
func (t *LoggingTransport) RoundTrip(r *http.Request) (*http.Response, error) {
	rCtx := r.Context()

	reqInfo := newRequestInfo(r)

	methodAttr := slog.String("method", reqInfo.RequestMethod)
	urlAttr := slog.String("url", reqInfo.RequestURL)
	t.logger.DebugContext(rCtx, "request info", methodAttr, urlAttr)

	var headers []any
	for key, values := range reqInfo.RequestHeaders {
		for _, value := range values {
			value = maskValue(key, value)
			headers = append(headers, slog.String(key, value))
		}
	}

	t.logger.DebugContext(rCtx, "request headers", headers...)
// ...
}
```

## Measuring the detailed HTTP timing
If the detailed timing is enabling, the code here measures all the durations with [net/http/httptrace package](https://pkg.go.dev/net/http/httptrace). 

```go
// ...
startTime := time.Now()

if t.detailedTiming {
	var getConn, dnsStart, dialStart, tlsStart, serverStart time.Time
	var host string
	trace := &httptrace.ClientTrace{
		// DNS
		DNSStart: func(info httptrace.DNSStartInfo) {
			reqInfo.muTrace.Lock()
			defer reqInfo.muTrace.Unlock()
			dnsStart = time.Now()
			host = info.Host
		},
		DNSDone: func(info httptrace.DNSDoneInfo) {
			reqInfo.muTrace.Lock()
			defer reqInfo.muTrace.Unlock()
			reqInfo.DNSLookup = time.Since(dnsStart)
			t.logger.Log(rCtx, t.detailedTimingLevel, "HTTP Trace", slog.String("DNS_lookup", host), slog.String("resolved", fmt.Sprintf("%v", info.Addrs)))
		},
		// Dial
		ConnectStart: func(network, addr string) {
			reqInfo.muTrace.Lock()
			defer reqInfo.muTrace.Unlock()
			dialStart = time.Now()
		},
		ConnectDone: func(network, addr string, err error) {
			reqInfo.muTrace.Lock()
			defer reqInfo.muTrace.Unlock()
			reqInfo.Dialing = time.Since(dialStart)
			if err != nil {
				t.logger.Log(rCtx, t.detailedTimingLevel, "HTTP Trace: Dial failed", slog.String("network", network), slog.String("addr", addr), slog.Any("error", err))
			} else {
				t.logger.Log(rCtx, t.detailedTimingLevel, "HTTP Trace: Dial succeed", slog.String("network", network), slog.String("addr", addr))
			}
		},
		// TLS
		TLSHandshakeStart: func() {
			tlsStart = time.Now()
		},
		TLSHandshakeDone: func(_ tls.ConnectionState, _ error) {
			reqInfo.muTrace.Lock()
			defer reqInfo.muTrace.Unlock()
			reqInfo.TLSHandshake = time.Since(tlsStart)
		},
		// Connection (it can be DNS + Dial or just the time to get one from the connection pool)
		GetConn: func(hostPort string) {
			getConn = time.Now()
		},
		GotConn: func(info httptrace.GotConnInfo) {
			reqInfo.muTrace.Lock()
			defer reqInfo.muTrace.Unlock()
			reqInfo.GetConnection = time.Since(getConn)
			reqInfo.ConnectionReused = info.Reused
		},
		// Server Processing (time since we wrote the request until first byte is received)
		WroteRequest: func(info httptrace.WroteRequestInfo) {
			reqInfo.muTrace.Lock()
			defer reqInfo.muTrace.Unlock()
			serverStart = time.Now()
		},
		GotFirstResponseByte: func() {
			reqInfo.muTrace.Lock()
			defer reqInfo.muTrace.Unlock()
			reqInfo.ServerProcessing = time.Since(serverStart)
		},
	}
	r = r.WithContext(httptrace.WithClientTrace(r.Context(), trace))
}
// ...
```

##  Logging response
```go
// ...
resp, err := t.rt.RoundTrip(r)
reqInfo.Duration = time.Since(startTime)

reqInfo.complete(resp, err)

t.logger.InfoContext(rCtx, "response", methodAttr, urlAttr, slog.String("status", reqInfo.ResponseStatus), slog.Int64("Duration_ms", reqInfo.Duration.Nanoseconds()/int64(time.Millisecond)))

if t.detailedTiming {
	var stats []slog.Attr
	if !reqInfo.ConnectionReused {
		stats = append(stats, slog.Int64("DNSLookup_ms", reqInfo.DNSLookup.Nanoseconds()/int64(time.Millisecond)))
		stats = append(stats, slog.Int64("Dial_ms", reqInfo.Dialing.Nanoseconds()/int64(time.Millisecond)))
		stats = append(stats, slog.Int64("TLSHandshake_ms", reqInfo.TLSHandshake.Nanoseconds()/int64(time.Millisecond)))
	} else {
		stats = append(stats, slog.Int64("GetConnection_ms", reqInfo.GetConnection.Nanoseconds()/int64(time.Millisecond)))
	}
	if reqInfo.ServerProcessing != 0 {
		stats = append(stats, slog.Int64("ServerProcessing_ms", reqInfo.ServerProcessing.Nanoseconds()/int64(time.Millisecond)))
	}
	stats = append(stats, slog.Int64("Duration_ms", reqInfo.Duration.Nanoseconds()/int64(time.Millisecond)))
	t.logger.LogAttrs(rCtx, t.detailedTimingLevel, "HTTP statistics", stats...)

	var responseHeaders []slog.Attr
	for key, values := range reqInfo.ResponseHeaders {
		for _, value := range values {
			value = maskValue(key, value)
			responseHeaders = append(responseHeaders, slog.String(key, value))
		}
	}
	t.logger.LogAttrs(rCtx, slog.LevelDebug, "response headers", responseHeaders...)
}

return resp, err
}
```
## Creating the `http.Client`

```go
logger := slog.New(slog.NewTextHandler(os.Stderr, opts))
slog.SetDefault(logger)

ctx := context.Background()

// creating http.Client with LoggingTransport
// using WithOptions pattern
client := http.Client{Transport: NewLoggingTransport(WithLogger(logger), WithDetailedTiming(LevelTrace))}
req, err := http.NewRequestWithContext(ctx, "GET", "https://httpbin.org/get", nil)
if err != nil {
	slog.ErrorContext(ctx, "Error creating request", slog.Any("error", err))
	return
}
req.Header.Add("Accept", "application/json")
req.Header.Add("Authorization", "Bearer: XXX")

// doing two requests to check the connection reusing
resp, err := client.Do(req)
resp, err = client.Do(req)
if err != nil {
	slog.ErrorContext(ctx, "Error creating request", slog.Any("error", err))
	return
}

bytes, err := io.ReadAll(resp.Body)
if err != nil {
	slog.ErrorContext(ctx, "Error reading body", slog.Any("error", err))
	return
}

fmt.Printf("body: %s\n", string(bytes))
```

In this example, we are calling `https://httpbin.org/get` twice. In second run, we are seeing that the connection is reused. `GetConnection_ms=0 ServerProcessing_ms=119 Duration_ms=119`

## Results

```
time=2024-04-24T11:06:01.913+02:00 level=DEBUG msg="request info" method=GET url=https://httpbin.org/get
time=2024-04-24T11:06:01.913+02:00 level=DEBUG msg="request headers" Authorization=<masked> Accept=application/json
time=2024-04-24T11:06:02.709+02:00 level=DEBUG msg=response method=GET url=https://httpbin.org/get status="200 OK" Duration_ms=796
time=2024-04-24T11:06:02.709+02:00 level=DEBUG msg="response headers" Content-Type=application/json Content-Length=344 Server=gunicorn/19.9.0 Access-Control-Allow-Origin=* Access-Control-Allow-Credentials=true Date="Wed, 24 Apr 2024 09:06:02 GMT"
time=2024-04-24T11:06:02.709+02:00 level=DEBUG msg="request info" method=GET url=https://httpbin.org/get
time=2024-04-24T11:06:02.709+02:00 level=DEBUG msg="request headers" Accept=application/json Authorization=<masked>
time=2024-04-24T11:06:02.833+02:00 level=DEBUG msg=response method=GET url=https://httpbin.org/get status="200 OK" Duration_ms=123
time=2024-04-24T11:06:02.833+02:00 level=DEBUG msg="response headers" Content-Length=344 Server=gunicorn/19.9.0 Access-Control-Allow-Origin=* Access-Control-Allow-Credentials=true Date="Wed, 24 Apr 2024 09:06:02 GMT" Content-Type=application/json
body: {
  "args": {}, 
  "headers": {
    "Accept": "application/json", 
    "Accept-Encoding": "gzip", 
    "Authorization": "Bearer: XXX", 
    "Host": "httpbin.org", 
    "User-Agent": "Go-http-client/2.0", 
    "X-Amzn-Trace-Id": "Root=1-6628cb7a-40016ef64cca01b00c936393"
  }, 
  "origin": "xxx", 
  "url": "https://httpbin.org/get"
}
```

### With detailed timing

```
time=2024-04-24T11:04:56.793+02:00 level=DEBUG msg="request info" method=GET url=https://httpbin.org/get
time=2024-04-24T11:04:56.794+02:00 level=DEBUG msg="request headers" Accept=application/json Authorization=<masked>
time=2024-04-24T11:04:56.842+02:00 level=TRACE msg="HTTP Trace" DNS_lookup=httpbin.org resolved="[{54.91.228.73 } {3.221.38.252 } {34.236.135.224 } {52.200.250.127 } {34.196.110.25 } {174.129.50.9 } {3.211.223.136 } {23.23.165.157 }]"
time=2024-04-24T11:04:56.968+02:00 level=TRACE msg="HTTP Trace: Dial succeed" network=tcp addr=54.91.228.73:443
time=2024-04-24T11:04:57.341+02:00 level=DEBUG msg=response method=GET url=https://httpbin.org/get status="200 OK" Duration_ms=547
time=2024-04-24T11:04:57.341+02:00 level=TRACE msg="HTTP statistics" DNSLookup_ms=47 Dial_ms=125 TLSHandshake_ms=251 ServerProcessing_ms=121 Duration_ms=547
time=2024-04-24T11:04:57.341+02:00 level=DEBUG msg="response headers" Content-Type=application/json Content-Length=344 Server=gunicorn/19.9.0 Access-Control-Allow-Origin=* Access-Control-Allow-Credentials=true Date="Wed, 24 Apr 2024 09:04:57 GMT"
time=2024-04-24T11:04:57.341+02:00 level=DEBUG msg="request info" method=GET url=https://httpbin.org/get
time=2024-04-24T11:04:57.341+02:00 level=DEBUG msg="request headers" Accept=application/json Authorization=<masked>
time=2024-04-24T11:04:57.461+02:00 level=DEBUG msg=response method=GET url=https://httpbin.org/get status="200 OK" Duration_ms=119
time=2024-04-24T11:04:57.461+02:00 level=TRACE msg="HTTP statistics" GetConnection_ms=0 ServerProcessing_ms=119 Duration_ms=119
time=2024-04-24T11:04:57.461+02:00 level=DEBUG msg="response headers" Access-Control-Allow-Credentials=true Date="Wed, 24 Apr 2024 09:04:57 GMT" Content-Type=application/json Content-Length=344 Server=gunicorn/19.9.0 Access-Control-Allow-Origin=*
body: {
  "args": {}, 
  "headers": {
    "Accept": "application/json", 
    "Accept-Encoding": "gzip", 
    "Authorization": "Bearer: XXX", 
    "Host": "httpbin.org", 
    "User-Agent": "Go-http-client/2.0", 
    "X-Amzn-Trace-Id": "Root=1-6628cb39-643d17a8277c8fea613f82dd"
  }, 
  "origin": "xxx", 
  "url": "https://httpbin.org/get"
}
```
