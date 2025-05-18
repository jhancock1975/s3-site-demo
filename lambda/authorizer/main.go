package main

import (
	"context"
	"fmt"
	"strings"

	"github.com/MicahParks/keyfunc"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/golang-jwt/jwt/v4"
)

var (
	jwks          *keyfunc.JWKS
	requiredGroup = "ApprovedUsers"
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

func handler(ctx context.Context, event events.APIGatewayCustomAuthorizerRequest) (events.APIGatewayCustomAuthorizerResponse, error) {
	tokenStr := event.AuthorizationToken
	if !strings.HasPrefix(tokenStr, "Bearer ") {
		return deny("No Bearer token"), nil
	}
	tokenStr = strings.TrimPrefix(tokenStr, "Bearer ")
	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		return jwks.Keyfunc(token)
	})
	if err != nil || !token.Valid {
		return deny("Invalid token"), nil
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return deny("Invalid claims"), nil
	}

	groupClaim, found := claims["cognito:groups"]
	if !found {
		return deny("User not approved"), nil
	}
	groups, ok := groupClaim.([]interface{})
	if !ok {
		if str, isStr := groupClaim.(string); isStr {
			groups = []interface{}{str}
		} else {
			return deny("Malformed group claim"), nil
		}
	}
	for _, g := range groups {
		if g.(string) == requiredGroup {
			return allow(), nil
		}
	}
	return deny("User not approved"), nil
}

func allow() events.APIGatewayCustomAuthorizerResponse {
	return events.APIGatewayCustomAuthorizerResponse{
		PrincipalID: "user",
		PolicyDocument: events.APIGatewayCustomAuthorizerPolicy{
			Version: "2012-10-17",
			Statement: []events.IAMPolicyStatement{
				{
					Action:   []string{"execute-api:Invoke"},
					Effect:   "Allow",
					Resource: []string{"*"},
				},
			},
		},
		Context: map[string]interface{}{"group": requiredGroup},
	}
}

func deny(reason string) events.APIGatewayCustomAuthorizerResponse {
	return events.APIGatewayCustomAuthorizerResponse{
		PrincipalID: "user",
		PolicyDocument: events.APIGatewayCustomAuthorizerPolicy{
			Version: "2012-10-17",
			Statement: []events.IAMPolicyStatement{
				{
					Action:   []string{"execute-api:Invoke"},
					Effect:   "Deny",
					Resource: []string{"*"},
				},
			},
		},
		Context: map[string]interface{}{"reason": reason},
	}
}

func main() {
	lambda.Start(handler)
}
