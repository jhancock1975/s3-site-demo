package main

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

var (
	clientID     = os.Getenv("CLIENT_ID")
	clientSecret = os.Getenv("CLIENT_SECRET")
	redirectURI  = os.Getenv("REDIRECT_URI")
	cognitoDomain = os.Getenv("COGNITO_DOMAIN")
)

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	type CodeRequest struct {
		Code string `json:"code"`
	}

	var body CodeRequest
	err := json.Unmarshal([]byte(request.Body), &body)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: http.StatusBadRequest, Body: `{"success":false,"error":"Invalid request body"}`}, nil
	}

	form := url.Values{}
	form.Add("grant_type", "authorization_code")
	form.Add("client_id", clientID)
	form.Add("client_secret", clientSecret)
	form.Add("redirect_uri", redirectURI)
	form.Add("code", body.Code)

	resp, err := http.PostForm(cognitoDomain+"/oauth2/token", form)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: `{"success":false,"error":"Failed to exchange code"}`}, nil
	}
	defer resp.Body.Close()

	tokenBody, _ := ioutil.ReadAll(resp.Body)

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(tokenBody),
	}, nil
}

func main() {
	lambda.Start(handler)
}
