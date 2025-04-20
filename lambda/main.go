package main

import (
  "context"
  "encoding/json"
  "fmt"

  "github.com/aws/aws-lambda-go/lambda"
)

type Request struct {
  Message string `json:"message"`
}

type Response struct {
  Echo string `json:"echo"`
}

func handler(ctx context.Context, req Request) (Response, error) {
  return Response{Echo: fmt.Sprintf("You said: %s", req.Message)}, nil
}

func main() {
  lambda.Start(handler)
}
