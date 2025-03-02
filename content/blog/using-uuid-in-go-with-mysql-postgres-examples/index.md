---
title: "Using UUID in Go with MySQL & Postgres Examples"
date: 2025-03-02T14:51:39+01:00
cover:
  image: "uuid.jpg"
  alt: "Using UUID in Go with MySQL & Postgres Examples"
---

A UUID is 128 bits long identifier and is intended to guarantee uniqueness across space and time. The format is described in [RFC 9562](https://datatracker.ietf.org/doc/html/rfc9562). The most common versions are:
- UUIDv4 - which are generated in random or pseudorandom order
- UUIDv7 - which are are ordered by time generated

In Go there is a library [google/uuid](https://github.com/google/uuid) which generates the numbers according to RFC specification.

## MySQL with UUIDv4

In MySQL, you can store UUID as `BINARY(16)`. There are two database helper functions [`UUID_TO_BIN`](https://dev.mysql.com/doc/refman/8.4/en/miscellaneous-functions.html#function_uuid-to-bin) and inverse [BIN_TO_UUID](https://dev.mysql.com/doc/refman/8.4/en/miscellaneous-functions.html#function_bin-to-uuid). 

In following example, I am creating two users with UUID identifiers created in client code. Next I am fetching those users to `User` struct.

```go
package main  
  
import (  
    "fmt"  
  
    _ "github.com/go-sql-driver/mysql"  
    "github.com/google/uuid"    
    "github.com/jmoiron/sqlx"
)  
  
type User struct {  
    ID   uuid.UUID  
    Name string  
}  
  
func main() {  
	// connect to database
    db, err := sqlx.Open("mysql", "root@tcp(127.0.0.1:3306)/test")  
    if err != nil {  
       panic(err)  
    }  

    // create schema
    db.MustExec(`DROP TABLE IF EXISTS users;`)  
    db.MustExec(`CREATE TABLE users (
    id BINARY(16) PRIMARY KEY,
	name VARCHAR(255) NOT NULL);`)  

	// insert two records
    db.MustExec("INSERT INTO users (id, name) VALUES (UUID_TO_BIN(?), ?)", uuid.New().String(), "John Doe")  
    db.MustExec("INSERT INTO users (id, name) VALUES (UUID_TO_BIN(?), ?)", uuid.New().String(), "John Smith")  

	// get users
    var users []User  
    err = db.Select(&users, "SELECT * FROM users")  
    if err != nil {  
       panic(err)  
    }  

	// print result
    fmt.Printf("%v\n", users)  
}
```

Output. The ids are in random order
```
[{997b6e94-0e99-4421-8a1d-09f0547c09a5 John Smith} {2b8030e5-5376-4d89-ae6c-5a351c60f8b7 John Doe}]
```


## Postgres with UUIDv7

```go
package main  
  
import (  
    "fmt"  
  
    "github.com/google/uuid"
    "github.com/jmoiron/sqlx"
    _ "github.com/lib/pq"  
)  
  
type Article struct {  
    ID   uuid.UUID  
    Name string  
}  
  
func main() {  
    // connect to database
    // you can use following docker run command to start postgres
    // docker run --rm --name my-postgres --env POSTGRES_PASSWORD=admin --publish 5432:5432  postgres
    db, err := sqlx.Open("postgres", "user=postgres password=admin dbname=postgres sslmode=disable")  
    if err != nil {  
       panic(err)  
    }  
  
    // create schema  
    db.MustExec(`DROP TABLE IF EXISTS articles;`)  
    db.MustExec(`CREATE TABLE articles (  
       id uuid PRIMARY KEY,       name VARCHAR NOT NULL);`)  
  
    // insert two articles to the table  
    id, err := uuid.NewV7()  
    if err != nil {  
       panic(err)  
    }  
    db.MustExec("INSERT INTO articles (id, name) VALUES ($1, $2)", id.String(), "Intro to Go")  
  
    id2, err := uuid.NewV7()  
    if err != nil {  
       panic(err)  
    }  
    db.MustExec("INSERT INTO articles (id, name) VALUES ($1, $2)", id2.String(), "Intro to sqlx")  
  
    // get the articles  
    var articles []Article  
    err = db.Select(&articles, "SELECT * FROM articles")  
    if err != nil {  
       panic(err)  
    }  
  
    // print results  
    fmt.Printf("%v\n", articles)  
}
```

Output. The ids are time-sorted
```
[{019325f1-cd9e-73a9-a280-454c395a2668 Intro to Go} {019325f1-cda0-770c-a8e5-d4c104aecb5c Intro to sqlx}]
