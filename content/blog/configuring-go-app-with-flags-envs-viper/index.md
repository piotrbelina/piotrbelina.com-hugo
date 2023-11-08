---
title: "Configuring Go application with flags, pflags, environment variables and Viper"
date: 2023-11-06T18:40:25+01:00
tags: ["go"]
---

# 
There are multiple ways to configure your Go application. I will describe a few most common one in this article with code samples.
## Flags
Go supports command line flags with builtin package [flag](https://pkg.go.dev/flag).
```go
package main

import (
	"flag"
	"log"
	"net/http"
)

func main() {
	addrPtr := flag.String("addr", ":8000", "addr of http server")
	flag.Parse()
	log.Printf("Listening on %s", *addrPtr)
	log.Fatal(http.ListenAndServe(*addrPtr, nil))
}
```

```go
func main() {
	var addr string
	flag.StringVar(&addr, "addr", ":8000", "addr of http server")
	flag.Parse()
	log.Printf("Listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
```
You can use `flag.String` `flag.Int` and so on to return a pointer to variable. If you prefer you can bind the flag to a variable with Var() functions (as for example `flag.StringVar` `flag.IntVar`. The full list is [here](https://pkg.go.dev/flag#pkg-index).

```
go run main.go -addr :8888
2023/11/05 20:52:28 Listening on :8888
```

## POSIX-style --flags
[pflag](https://github.com/spf13/pflag/) is a drop-in replacement for Go's flag package, implementing POSIX/GNU-style --flags

```go
package main

import (
	"github.com/spf13/pflag"

	"log"
	"net/http"
)

func main() {
	addr := pflag.String("addr", ":8000", "addr of http server")
	pflag.Parse()
	log.Printf("Listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, nil))
}
```

```
go run main.go --addr :8888
2023/11/05 23:03:49 Listening on :8888
```
## Environment variables
According to [The Twelve-Factor App](https://12factor.net/config) the application should be configurable with environment variables. 

```go
import (
    "http"
    "log"
    "os"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8000"
	}
	log.Printf("Listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
```

```
ADDR=8888 go run main.go
2023/11/05 20:54:35 Listening on :8888
```
## Viper
[Viper](https://github.com/spf13/viper) is a full solution for app configuration. It supports:
* defaults
* multiple formats including JSON, TOML, YAML, HCL, envfile and Java properties config files 
* live watching and re-reading of config files (optional)
* reading from environment variables
* reading from remote config systems (etcd or Consul), and watching changes
* reading from command line flags
* reading from buffer

### Reading from files and envvars
```go
package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/spf13/viper"
)

func main() {
	viper.SetDefault("addr", ":8000")
	viper.AddConfigPath("./config")
	viper.SetConfigName("default")
	viper.AutomaticEnv()
	err := viper.ReadInConfig()
	if err != nil {
		log.Fatal(fmt.Errorf("fatal error config file: %w", err))
	}
	addr := viper.GetString("addr")

	log.Printf("Listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
```

```yaml
// config/default.yaml

ADDR: ":8888"
```

### Unmarshaling the config into a struct
Viper has an ability to unmarshal config to a struct or map.
```go
package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/spf13/viper"
)

type config struct {
	Addr string
}

func main() {
	// ...

	var c config
	err = viper.Unmarshal(&c)
	if err != nil {
		log.Fatal(fmt.Errorf("error unmarshalling: %w", err))
	}

	log.Printf("Listening on %s", c.Addr)
	log.Fatal(http.ListenAndServe(c.Addr, nil))
}
```
### Combining Viper and pflag full example
Viper supports binding to flags with pflag package. This way you can configure the app by:
- flag
- environment variable
- file

```go
package main

import (
	"fmt"
	"log"
	"net/http"
	
	"github.com/spf13/pflag"
	"github.com/spf13/viper"
)

type config struct {
	Addr string
}

func main() {
	pflag.String("addr", ":8000", "addr of http server")
	pflag.Parse()

	viper.SetDefault("addr", ":8000")
	err := viper.BindPFlags(pflag.CommandLine)
	if err != nil {
		log.Fatal(fmt.Errorf("fatal binding pflags: %w", err))
	}
	viper.AddConfigPath("./config")
	viper.SetConfigName("default")
	viper.AutomaticEnv()
	err = viper.ReadInConfig()
	if err != nil {
		log.Fatal(fmt.Errorf("fatal error config file: %w", err))
	}

	var c config
	err = viper.Unmarshal(&c)
	if err != nil {
		log.Fatal(fmt.Errorf("error unmarshalling: %w", err))
	}

	log.Printf("Listening on %s", c.Addr)
	log.Fatal(http.ListenAndServe(c.Addr, nil))
}
```
