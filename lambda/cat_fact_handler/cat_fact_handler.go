// main.go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type CatFactResponse struct {
	Fact   string `json:"fact"`
	Length int    `json:"length"`
}

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Call external API
	resp, err := http.Get("https://catfact.ninja/fact")
	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       fmt.Sprintf("Error fetching cat fact: %v", err),
		}, nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return events.APIGatewayProxyResponse{
			StatusCode: resp.StatusCode,
			Body:       fmt.Sprintf("Upstream API error: %s", resp.Status),
		}, nil
	}

	// Decode JSON
	var cf CatFactResponse
	if err := json.NewDecoder(resp.Body).Decode(&cf); err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       fmt.Sprintf("Error decoding response: %v", err),
		}, nil
	}

	// Re-marshal and return
	out, err := json.Marshal(cf)
	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       fmt.Sprintf("Error encoding JSON: %v", err),
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode:      200,
		Headers:         map[string]string{"Content-Type": "application/json"},
		Body:            string(out),
		IsBase64Encoded: false,
	}, nil
}

func main() {
	lambda.Start(handler)
}
