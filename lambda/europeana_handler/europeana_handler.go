// lambda/europeana_handler/europeana_handler.go
package main

import (
	"context"
	"fmt"
	"io"
	"net/http"

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
	// load AWS SDK config (region from env or default)
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(fmt.Errorf("loading AWS config: %w", err))
	}

	// Create SSM client
	ssmClient := ssm.NewFromConfig(cfg)

	// Get the SecureString parameter
	resp, err := ssmClient.GetParameter(context.Background(), &ssm.GetParameterInput{
		Name:           awsString("/taptupo/europeana/api-key"),
		WithDecryption: awsBool(true),
	})
	if err != nil {
		panic(fmt.Errorf("fetching parameter: %w", err))
	}
	europeanaKey = *resp.Parameter.Value
}

// handler invokes Europeana and proxies the JSON response
func handler(ctx context.Context, _ events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	req, err := http.NewRequestWithContext(ctx, "GET",
		"https://api.europeana.eu/record/v2/search.json?query=Vermeer", nil)
	if err != nil {
		return errorResp(500, err)
	}
	req.Header.Set("X-Api-Key", europeanaKey)

	res, err := httpClient.Do(req)
	if err != nil {
		return errorResp(502, err)
	}
	defer res.Body.Close()

	body, err := io.ReadAll(res.Body)
	if err != nil {
		return errorResp(500, err)
	}

	// return upstream JSON
	return events.APIGatewayProxyResponse{
		StatusCode:      res.StatusCode,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            string(body),
		IsBase64Encoded: false,
	}, nil
}

func errorResp(code int, err error) (events.APIGatewayProxyResponse, error) {
	msg := fmt.Sprintf(`{"error": %q}`, err.Error())
	return events.APIGatewayProxyResponse{
		StatusCode:      code,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            msg,
		IsBase64Encoded: false,
	}, nil
}

func awsString(s string) *string { return &s }

func awsBool(b bool) *bool { return &b }

func main() {
	lambda.Start(handler)
}
