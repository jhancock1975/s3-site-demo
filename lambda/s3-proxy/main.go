package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/MicahParks/keyfunc"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/golang-jwt/jwt/v4"
)

var (
	jwks          *keyfunc.JWKS
	requiredGroup = "ApprovedUsers"
	s3Bucket      = os.Getenv("S3_BUCKET") // Set this env var in Lambda config
)

func init() {
	region := "us-east-1"
	userPoolId := "us-east-1_3k54fOQZH"
	jwksURL := fmt.Sprintf("https://cognito-idp.%s.amazonaws.com/%s/.well-known/jwks.json", region, userPoolId)
	var err error
	jwks, err = keyfunc.Get(jwksURL, keyfunc.Options{})
	if err != nil {
		panic(fmt.Sprintf("Failed to get JWKS: %v", err))
	}
}

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	tokenStr := req.Headers["Authorization"]
	if tokenStr == "" {
		return events.APIGatewayProxyResponse{StatusCode: 401, Body: "Missing token"}, nil
	}
	if strings.HasPrefix(tokenStr, "Bearer ") {
		tokenStr = strings.TrimPrefix(tokenStr, "Bearer ")
	}

	token, err := jwt.Parse(tokenStr, jwks.Keyfunc)
	if err != nil || !token.Valid {
		return events.APIGatewayProxyResponse{StatusCode: 401, Body: "Invalid token"}, nil
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return events.APIGatewayProxyResponse{StatusCode: 401, Body: "Invalid claims"}, nil
	}
	// Check group
	groupClaim, found := claims["cognito:groups"]
	approved := false
	if found {
		groups, ok := groupClaim.([]interface{})
		if !ok {
			if str, isStr := groupClaim.(string); isStr {
				groups = []interface{}{str}
			}
		}
		for _, g := range groups {
			if g.(string) == requiredGroup {
				approved = true
				break
			}
		}
	}
	var key string
	if approved {
		key = "index.html"
	} else {
		key = "index-pending.html" // create this file in your S3 bucket!
	}
	// Fetch S3 object and return
	sess := session.Must(session.NewSession(&aws.Config{Region: aws.String("us-east-1")}))
	svc := s3.New(sess)
	obj, err := svc.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(s3Bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: "Failed to get file"}, nil
	}
	defer obj.Body.Close()
	bodyBytes, _ := io.ReadAll(obj.Body)
	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type": "text/html",
		},
		Body: string(bodyBytes),
	}, nil
}

func main() {
	lambda.Start(handler)
}
