---
title: "Measuring Elapsed Time in Go"
date: 2024-10-29T13:10:07+01:00
tags: ["go"]
cover:
  image: "measuring-elapsed-time-in-go.jpg"
  alt: "Measuring Elapsed Time in Go"
---

To measure elapsed time in Go you go use following code.

```go
package main

import (
    "fmt"
    "time"
    
    "go.opentelemetry.io/otel/metric"
)

func expensiveCall() { }

func main() {
    // setup meter
    opDurationHistogration, _ := meter.Int64Histogram("operation_duration", metric.WithDescription("Operation duration"), metric.WithUnit("ms"))

    start := time.Now()

    expensiveCall()

    elapsed := time.Since()

    fmt.Printf("Took %s\n", elapsed)
    opDurationHistogration.Record(context.TODO(), elapsed)
}
```

Output 

```
Took 11.583µs
```

