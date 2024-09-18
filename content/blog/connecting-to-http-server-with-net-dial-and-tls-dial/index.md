---
title: "Connecting to HTTP server and receiving data with net.Dial and tls.Dial"
date: 2024-09-18T23:40:06+02:00
tags: ["go", "http", "web"]
---

This is a continuation from previous article [How Does Web Work With Go Part 1](/blog/how-does-web-work-with-go-part-1/). 

To talk with web server, you need to speak the same language. In this case it is protocol HTTP. Currently there are 3 version of this protocol in use:
- HTTP 1.1 - TCP text format
- HTTP 2 - TCP binary format
- HTTP 3 - UDP binary format

In our case we will use HTTP 1.1 which is defined in [RFC2616](https://datatracker.ietf.org/doc/html/rfc2616#section-10.4.1). The protocol works by sending a request message and receiving a response message.

## Preparing request

```http
GET /blog/http-log/?test=1&foo=bar HTTP/1.1
Host: www.piotrbelina.com

```

This simple request consists of following parts
* HTTP verb - `GET`
* resource - path with query `/blog/http-log/?test=1&foo=bar`
* protocol version `HTTP/1.1`
* one header with host `Host: www.piotrbelina.com`
* [empty line](https://datatracker.ietf.org/doc/html/rfc2616#section-2.2) at the end `\r\n`

## Sending http request and receiving response in Go

In Go, you can pass domain name and `net.Dial` will resolve it under the hood.

```go
func main() {  
    conn, err := net.Dial("tcp", "www.piotrbelina.com:443")  
    if err != nil {  
       log.Fatal(err)  
    }
    fmt.Fprintf(conn, "GET /blog/http-log/?test=1&foo=bar HTTP/1.1\r\nHost: www.piotrbelina.com\r\n\r\n")  
  
    var buf bytes.Buffer  
    io.Copy(&buf, conn)  
    fmt.Println(buf.String())  
    
    conn.Close()
}
```

Output
```http
HTTP/1.1 400 Bad Request
Server: cloudflare
Date: Wed, 18 Sep 2024 20:28:02 GMT
Content-Type: text/html
Content-Length: 253
Connection: close
CF-RAY: -

<html>
<head><title>400 The plain HTTP request was sent to HTTPS port</title></head>
<body>
<center><h1>400 Bad Request</h1></center>
<center>The plain HTTP request was sent to HTTPS port</center>
<hr><center>cloudflare</center>
</body>
</html>

```

## Analyzing response

Let's analyze this response. [Response](https://datatracker.ietf.org/doc/html/rfc2616#section-6) consists of two parts status line with following headers and body.

Status line contains:
* http protocol version `HTTP/1.1`
* status code `400`
* reason `Bad Request`

### Status codes
There are five classes of response. They are grouped by first digit.
- 1xx - Informational
- 2xx - Success
- 3xx - Redirects
- 4xx - Client errors
- 5xx - Server errors

## Dealing with 400 response status code
You receive 400 Bad Request. According to [RFC](https://datatracker.ietf.org/doc/html/rfc2616#section-10.4.1) it means

> The request could not be understood by the server due to malformed
   syntax. The client SHOULD NOT repeat the request without
   modifications.

Also from response body we can see what is there real reason of failed request:

> The plain HTTP request was sent to HTTPS port

## Switching to TLS

To access the content, you need to use HTTPS which stands for HTTP Secure. This allows to send and receive data securely without anyone else listening to exchange between client and server. To have secure communication we are using public key cryptography with Transport Layer Security (TLS) protocol.

How TLS works is beyond scope of this article, but in short client and server create and exchange keys used to encrypt the conversation.

## Using TLS in Go

Go offers convenient way to setup secure connection. You only need to change

```go
conn, err := net.Dial("tcp", "www.piotrbelina.com:443")
```

to

```go
import "crypto/tls"

func main(){
// ...
	conn, err := tls.Dial("tcp", "www.piotrbelina.com:443", &tls.Config{})  
//...
}
```

Full example

```go
func main() {  
    conn, err := tls.Dial("tcp", "www.piotrbelina.com:443", &tls.Config{})  
    if err != nil {  
       log.Fatal(err)  
    }  
    fmt.Fprintf(conn, "GET /blog/http-log/?test=1&foo=bar HTTP/1.0\r\nHost: www.piotrbelina.com\r\n\r\n")  
  
    var buf bytes.Buffer  
    io.Copy(&buf, conn)  
    fmt.Println(buf.String())  
  
    conn.Close()  
}
```

Output
```http
HTTP/1.1 200 OK
Date: Wed, 18 Sep 2024 20:58:55 GMT
Content-Type: text/html; charset=utf-8
Connection: close
Access-Control-Allow-Origin: *
Cache-Control: public, max-age=0, must-revalidate
referrer-policy: strict-origin-when-cross-origin
x-content-type-options: nosniff
Report-To: {"endpoints":[{"url":"https:\/\/a.nel.cloudflare.com\/report\/v4?s=h9xOfa5EHezjtSD5hqz2lTZkSuS3cXFhvC6QDrqqf%2BEaQDUPecTM3VztMmrTLORiLt9OZdayOSjISLHTxN2K%2BuKRkGMfTAKpdmua%2BR6R0OEIE3aqlMPPuRipq%2BoJ%2FwVXiIKTOtq4"}],"group":"cf-nel","max_age":604800}
NEL: {"success_fraction":0,"report_to":"cf-nel","max_age":604800}
Vary: Accept-Encoding
CF-Cache-Status: DYNAMIC
Server: cloudflare
CF-RAY: 8c5441be68c53510-WAW
alt-svc: h3=":443"; ma=86400

<!DOCTYPE html>
<html lang="en" dir="auto">
<head><meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
<meta name="robots" content="index, follow">
<title>HTTP logger with slog | Piotr Belina</title>
...
```

## Analyzing response

In this example you can see that the response code is `200 OK`. There are multiple headers. And at the end there is HTML code for browser to render.
