// lambda/europeana_handler/europeana_handler.go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
)

var (
	europeanaKey string
	httpClient   = http.DefaultClient
)

func init() {
	// load AWS SDK config
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(fmt.Errorf("loading AWS config: %w", err))
	}

	// fetch API key from SSM
	ssmClient := ssm.NewFromConfig(cfg)
	resp, err := ssmClient.GetParameter(context.Background(), &ssm.GetParameterInput{
		Name:           awsString("/taptupo/europeana/api-key"),
		WithDecryption: awsBool(true),
	})
	if err != nil {
		panic(fmt.Errorf("fetching parameter: %w", err))
	}
	europeanaKey = *resp.Parameter.Value
}

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// read and validate the 'query' parameter
	term, ok := req.QueryStringParameters["query"]
	if !ok || term == "" {
		return clientError(400, "missing required query parameter 'query'")
	}

	// build the Europeana API URL
	u := fmt.Sprintf(
		"https://api.europeana.eu/record/v2/search.json?query=%s",
		url.QueryEscape(term),
	)
	httpReq, err := http.NewRequestWithContext(ctx, "GET", u, nil)
	if err != nil {
		return serverError(err)
	}
	httpReq.Header.Set("X-Api-Key", europeanaKey)

	// call Europeana
	res, err := httpClient.Do(httpReq)
	if err != nil {
		return serverError(err)
	}
	defer res.Body.Close()

	body, err := io.ReadAll(res.Body)
	if err != nil {
		return serverError(err)
	}

	return events.APIGatewayProxyResponse{
		StatusCode:      res.StatusCode,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            string(body),
		IsBase64Encoded: false,
	}, nil
}

func clientError(code int, message string) (events.APIGatewayProxyResponse, error) {
	body, _ := json.Marshal(map[string]string{"error": message})
	return events.APIGatewayProxyResponse{
		StatusCode:      code,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            string(body),
		IsBase64Encoded: false,
	}, nil
}

func serverError(err error) (events.APIGatewayProxyResponse, error) {
	msg := fmt.Sprintf(`{"error":"%s"}`, err.Error())
	return events.APIGatewayProxyResponse{
		StatusCode:      502,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            msg,
		IsBase64Encoded: false,
	}, nil
}

func awsString(s string) *string { return &s }
func awsBool(b bool) *bool       { return &b }

func main() {
	lambda.Start(handler)
}
