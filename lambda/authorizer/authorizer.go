package main

import (
	"context"
	"fmt"
	"strings"

	"github.com/MicahParks/keyfunc"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/golang-jwt/jwt/v4"
)

// HTTP API authorizer request
type AuthRequest struct {
	Type    string            `json:"type"`
	Headers map[string]string `json:"headers"`
}

// HTTP API authorizer response
type AuthResponse struct {
	IsAuthorized bool                   `json:"isAuthorized"`
	Context      map[string]interface{} `json:"context,omitempty"`
}

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

func handler(ctx context.Context, req AuthRequest) (AuthResponse, error) {
	tokenStr := ""
	if req.Headers != nil {
		// The header might be lower-case or mixed, so check both
		if auth, ok := req.Headers["authorization"]; ok {
			tokenStr = auth
		} else if auth, ok := req.Headers["Authorization"]; ok {
			tokenStr = auth
		}
	}
	if !strings.HasPrefix(tokenStr, "Bearer ") {
		return AuthResponse{IsAuthorized: false}, nil
	}
	tokenStr = strings.TrimPrefix(tokenStr, "Bearer ")

	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		return jwks.Keyfunc(token)
	})
	if err != nil || !token.Valid {
		return AuthResponse{IsAuthorized: false}, nil
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return AuthResponse{IsAuthorized: false}, nil
	}

	// Check group claim
	groupClaim, found := claims["cognito:groups"]
	var groups []string
	if found {
		switch v := groupClaim.(type) {
		case []interface{}:
			for _, g := range v {
				if gs, ok := g.(string); ok {
					groups = append(groups, gs)
				}
			}
		case string:
			groups = append(groups, v)
		}
	}
	for _, g := range groups {
		if g == requiredGroup {
			return AuthResponse{IsAuthorized: true, Context: map[string]interface{}{"group": requiredGroup}}, nil
		}
	}
	return AuthResponse{IsAuthorized: false}, nil
}

func main() {
	lambda.Start(handler)
}
