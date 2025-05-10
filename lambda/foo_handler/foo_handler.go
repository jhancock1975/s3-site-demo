package main

import (
	"context"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Log the incoming request method and path
	log.Printf("Received %s request for %s", req.HTTPMethod, req.Path)

	return events.APIGatewayProxyResponse{
		StatusCode:      200,
		Headers:         map[string]string{"Content-Type": "text/plain"},
		Body:            "OK",
		IsBase64Encoded: false,
	}, nil
}

func main() {
	lambda.Start(handler)
}
