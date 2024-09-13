---
title: "How Does Web Work With Go Part 1"
date: 2024-09-13T23:31:30+02:00
tags: ["go", "web"]
---

This evening I was wondering if my 5-year old son would ask me, what is the Internet and how it works, what I would reply to him? Maybe he is a bit young to go into the details, but I would like to explain what I know about it and to structure my knowledge and learn more in the process. Because as Seneka said: while we teach, we learn. I would like to dive deep into the details in this series with some Go examples. Let's start then.

## What is Internet?

Internet is network of computers connected and communicating together. Internet is technical infrastructure needed for World Wide Web (or Web) to exists. So how it is possible that when you are typing an address into the browser, you are getting an interactive website?

## What happens when you type an address into the browser

What probably everyone happened to meet are website addresses, known as URLs. URL stands for Uniform Resource Location. This is human-friendly address of other computer where is some content you would like to get. URLs consists of 5 elements: scheme, authority (userinfo, host and port), path, query and fragment.

Taking for example an URL to one of my blog posts:

```
https://www.piotrbelina.com/blog/http-log/?test=1&foo=bar#using-withoptions-pattern
```

You can get following parts:
* scheme - `https`
* host - `www.piotrbelina.com`
* path - `/blog/http-log/`
* query - `test=1&foo=bar`
* fragment - `using-withoptions-pattern`

URL can be more complex. In Wikipedia there is a article explaining [URLs more in-depth](https://en.wikipedia.org/wiki/Uniform_Resource_Identifier). And if this is not enough, you can also read [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986). 
## Parsing URL 

URL to be used by machine has to be parse into individual parts.

```go
func main() {  
    u, err := url.Parse("https://www.piotrbelina.com/blog/http-log/?test=1&foo=bar#using-withoptions-pattern")  
    if err != nil {  
       log.Fatal(err)  
    }  
    fmt.Println(u.Scheme)  
    fmt.Println(u.Host)  
    fmt.Println(u.Path)  
    fmt.Println(u.RawQuery)  
    fmt.Println(u.Query())  // this will return a map of params
    fmt.Println(u.Fragment)  
}
```

Output

```
https
www.piotrbelina.com
/blog/http-log/
test=1&foo=bar
map[foo:[bar] test:[1]]
using-withoptions-pattern
```

## Translating hostname to IP address

To get data from other computer you can use hostname which is human-friendly alias for computer address. Computers prefer ones and zeros, so the addresses are just numbers in specific format. They are called **IP addresses**. IP stands for Internet Protocol. There is IP version 4 (IPv4) and IP version 6 (IPv6).

IPv4 address look like this: `192.168.12.23` and
IPv6 looks like this `2001:0db8:0000:0000:0000:ff00:0042:8329`.


```go
func main() {  
    addrs, err := net.LookupHost("www.piotrbelina.com")  
    if err != nil {  
       log.Fatal(err)  
    }  
  
    fmt.Println(addrs)  
}
```

Output

```
[172.67.205.232 104.21.34.155 2606:4700:3035::ac43:cde8 2606:4700:3037::6815:229b]
```

`net.LookupHost` returns an slice of IPv4 and IPv6 addresses. One of this can be address can be chosen to get the data we want. 

