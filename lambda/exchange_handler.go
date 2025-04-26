package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

var (
	clientID      = os.Getenv("CLIENT_ID")
	clientSecret  = os.Getenv("CLIENT_SECRET") // leave empty if none
	redirectURI   = os.Getenv("REDIRECT_URI")
	cognitoDomain = os.Getenv("COGNITO_DOMAIN") // e.g. your-prefix.auth.us-east-1.amazoncognito.com
)

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token,omitempty"`
	IDToken      string `json:"id_token"`
	TokenType    string `json:"token_type"`
}

type errorResponse struct {
	Message string `json:"message"`
}

func handler(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// 1) Parse the incoming JSON body for {"code": "..."}
	var body struct {
		Code string `json:"code"`
	}
	if err := json.Unmarshal([]byte(req.Body), &body); err != nil || body.Code == "" {
		return clientError(400, "Missing or invalid code")
	}

	// 2) Prepare form data
	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("client_id", clientID)
	data.Set("code", body.Code)
	data.Set("redirect_uri", redirectURI)

	// 3) Build HTTP request
	tokenURL := fmt.Sprintf("https://%s/oauth2/token", cognitoDomain)
	httpReq, err := http.NewRequest("POST", tokenURL, bytes.NewBufferString(data.Encode()))
	if err != nil {
		return serverError(err)
	}
	httpReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	// 4) If you have a client secret, add Basic auth
	if clientSecret != "" {
		cred := fmt.Sprintf("%s:%s", clientID, clientSecret)
		httpReq.Header.Set("Authorization", "Basic "+base64.StdEncoding.EncodeToString([]byte(cred)))
	}

	// 5) Execute the request
	client := &http.Client{}
	resp, err := client.Do(httpReq)
	if err != nil {
		return serverError(err)
	}
	defer resp.Body.Close()

	// 6) Read & parse response
	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return serverError(err)
	}
	if resp.StatusCode >= 400 {
		return events.APIGatewayProxyResponse{
			StatusCode: resp.StatusCode,
			Body:       string(bodyBytes),
			Headers:    corsHeaders(),
		}, nil
	}

	var tokens tokenResponse
	if err := json.Unmarshal(bodyBytes, &tokens); err != nil {
		return serverError(err)
	}

	// 7) Return tokens as JSON
	respBody, err := json.Marshal(tokens)
	if err != nil {
		return serverError(err)
	}
	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       string(respBody),
		Headers:    corsHeaders(),
	}, nil
}

func clientError(status int, msg string) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(errorResponse{Message: msg})
	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Body:       string(b),
		Headers:    corsHeaders(),
	}, nil
}

func serverError(err error) (events.APIGatewayProxyResponse, error) {
	fmt.Fprintf(os.Stderr, "Error: %v\n", err)
	return clientError(500, "Internal server error"), nil
}

func corsHeaders() map[string]string {
	return map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Headers": "Content-Type",
		"Content-Type":                 "application/json",
	}
}

func main() {
	// validate required env vars
	if clientID == "" || redirectURI == "" || cognitoDomain == "" {
		panic(errors.New("Missing one of CLIENT_ID, REDIRECT_URI, or COGNITO_DOMAIN"))
	}
	lambda.Start(handler)
}
