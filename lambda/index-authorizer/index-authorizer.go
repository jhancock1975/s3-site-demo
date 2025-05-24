package main

import (
	"context"
	"encoding/json"
	"io"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

var (
	s3Client *s3.Client
	bucket   string
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic("unable to load AWS SDK config: " + err.Error())
	}
	s3Client = s3.NewFromConfig(cfg)

	bucket = os.Getenv("BUCKET_NAME")
	if bucket == "" {
		panic("BUCKET_NAME env var not set")
	}
}

func handler(ctx context.Context, req events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	// default to pending
	key := "index-pending.html"

	// extract cognito:groups claim
	if rawClaim, exists := req.RequestContext.Authorizer.JWT.Claims["cognito:groups"]; exists {
		var groups []string

		// Handle the claim as a string
		rawClaimStr := rawClaim
		if strings.HasPrefix(rawClaimStr, "[") {
			_ = json.Unmarshal([]byte(rawClaimStr), &groups)
		} else {
			groups = []string{rawClaimStr}
		}

		// Check if user is in approved group
		for _, g := range groups {
			if g == "Approved users" {
				key = "index.html"
				break
			}
		}
	}

	// fetch from S3
	out, err := s3Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Error fetching page"}, nil
	}
	defer out.Body.Close()

	data, err := io.ReadAll(out.Body)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Error reading page"}, nil
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode:      200,
		Headers:         map[string]string{"Content-Type": "text/html"},
		Body:            string(data),
		IsBase64Encoded: false,
	}, nil
}

func main() {
	lambda.Start(handler)
}
