// lambda/gpt4_handler/gpt4_handler.go
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
)

var (
	openaiKey  string
	httpClient = http.DefaultClient
)

func init() {
	// Load AWS config
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(fmt.Errorf("loading AWS config: %w", err))
	}
	// Fetch OpenAI key from SSM
	ssmClient := ssm.NewFromConfig(cfg)
	param, err := ssmClient.GetParameter(context.Background(), &ssm.GetParameterInput{
		Name:           aws.String("/taptupo/openai/api-key"),
		WithDecryption: aws.Bool(true),
	})
	if err != nil {
		panic(fmt.Errorf("getting SSM parameter: %w", err))
	}
	openaiKey = *param.Parameter.Value
}

type requestBody struct {
	Prompt string `json:"prompt"`
}

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Expect POST with JSON body {"prompt": "..."}
	var r requestBody
	if err := json.Unmarshal([]byte(req.Body), &r); err != nil || r.Prompt == "" {
		return clientError(400, "invalid request body, need JSON with field 'prompt'")
	}

	// Call OpenAI Chat Completions endpoint
	payload := map[string]interface{}{
		"model": "gpt-4o",
		"messages": []map[string]string{
			{
				"role":    "user",
				"content": r.Prompt,
			},
		},
	}
	bodyBytes, _ := json.Marshal(payload)
	httpReq, err := http.NewRequestWithContext(ctx, "POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(bodyBytes))
	if err != nil {
		return serverError(err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+openaiKey)

	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return serverError(err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return serverError(err)
	}

	return events.APIGatewayProxyResponse{
		StatusCode:      resp.StatusCode,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            string(respBody),
		IsBase64Encoded: false,
	}, nil
}

func clientError(code int, msg string) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(map[string]string{"error": msg})
	return events.APIGatewayProxyResponse{
		StatusCode:      code,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            string(b),
		IsBase64Encoded: false,
	}, nil
}

func serverError(err error) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(map[string]string{"error": err.Error()})
	return events.APIGatewayProxyResponse{
		StatusCode:      502,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            string(b),
		IsBase64Encoded: false,
	}, nil
}

func main() {
	lambda.Start(handler)
}
