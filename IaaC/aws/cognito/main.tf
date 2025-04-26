provider "aws" {
  region = "us-east-1"
}

resource "aws_cognito_user_pool" "taptupo_user_pool" {
  name = "taptupo-user-pool"

  auto_verified_attributes = ["email"]

  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = true
  }
}

resource "aws_cognito_user_pool_client" "taptupo_app_client" {
  name                         = "taptupo"
  user_pool_id                 = aws_cognito_user_pool.taptupo_user_pool.id
  generate_secret              = false
  allowed_oauth_flows          = ["code", "implicit"]
  allowed_oauth_scopes         = ["email", "openid", "profile"]
  callback_urls                = ["https://taptupo.com/app/callback.html"] # <-- Adjust
  logout_urls                  = ["https://your-app/logout.html"]   # <-- Adjust
  supported_identity_providers = ["Google"]

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

resource "aws_cognito_identity_provider" "google_provider" {
  user_pool_id  = aws_cognito_user_pool.taptupo_user_pool.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id     = "YOUR_GOOGLE_CLIENT_ID"   # <-- Replace
    client_secret = "YOUR_GOOGLE_CLIENT_SECRET" # <-- Replace
    authorize_scopes = "openid email profile"
  }

  attribute_mapping = {
    email = "email"
    given_name = "given_name"
    family_name = "family_name"
  }
}

