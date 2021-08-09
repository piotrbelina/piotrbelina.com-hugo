---
title: "Gunzip S3 AWS Lambda in Go"
date: 2021-04-14 20:00:00
draft: false
type: blog
---
You have a gzipped file in S3 and you want to gunzip it. Better yet it is gunzipped on S3 upload event. I could not find a solution, so I am publishing my own. This solution uses streaming with `io.Pipe` so, it does not have a trouble with Lambda `/tmp` disk space limit. 

## Solution
Full code can be found in [GitHub repository](https://github.com/piotrbelina/s3-lambda-gunzip-go/blob/master/main.go).

```go
func HandleRequest(ctx context.Context, s3Event events.S3Event) {
	destinationBucket := os.Getenv("DESTINATION_BUCKET")
	for _, record := range s3Event.Records {
		s3obj := record.S3
		sourceBucket := s3obj.Bucket.Name
		key := s3obj.Object.Key
		Gunzip(sourceBucket, destinationBucket, key)
	}
}

func main() {
	lambda.Start(HandleRequest)
}
```
This is Lambda handler. It should gunzip all the S3 PUTs from source bucket to `DESTINATION_BUCKET` which is an environment variable.

```go
func Gunzip(sourceBucket, destinationBucket, key string) {
	// create pipe
	reader, writer := io.Pipe()

	sess, _ := session.NewSession(&aws.Config{
		Region: aws.String(region)},
	)
	// create downloader to download file from source bucket
	downloader := s3manager.NewDownloader(sess)
	
	// wait for downloader and uploader
	wg := sync.WaitGroup{}
	wg.Add(2)

	// run downloader
	go func() {
		defer func() {
			// it is important to close the writer or reading
			// from the other end of the pipe will never finish
			wg.Done()
			writer.Close()
		}()
		numBytes, err := downloader.Download(FakeWriterAt{writer},
			&s3.GetObjectInput{
				Bucket: aws.String(sourceBucket),
				Key:    aws.String(key),
			})
		if err != nil {
			exitErrorf("Unable to download item %q, %v", key, err)
		}

		log.Printf("Downloaded %d bytes", numBytes)
	}()

	// run uploader
	go func() {
		defer wg.Done()
		gzReader, _ := gzip.NewReader(reader)

		uploader := s3manager.NewUploader(sess)

		metadata := make(map[string]*string)
		metadata["Content-Type"] = aws.String("text/plain")

		result, err := uploader.Upload(&s3manager.UploadInput{
			Body:     gzReader,
			Bucket:   aws.String(destinationBucket),
			Key:      aws.String(strings.ReplaceAll(key, ".gz", "")),
			Metadata: metadata,
		})
		if err != nil {
			log.Fatalln("Failed to upload", err)
		}

		log.Println("Successfully uploaded to", result.Location)
	}()

	wg.Wait()
}
```

This solution was heavily inspired by article on dev.to:  [Using io.Reader/io.Writer in Go to stream data](https://dev.to/flowup/using-io-reader-io-writer-in-go-to-stream-data-3i7b).