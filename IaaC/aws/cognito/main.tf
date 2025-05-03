# generated from Claude Sonnet 3.5
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# User Pool
resource "aws_cognito_user_pool" "main" {
  name = "User pool - vwcht5"
  
  # Password Policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
    temporary_password_validity_days = 7
  }
  
  # Account Recovery Setting
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }
  
  # Auto Verified Attributes
  auto_verified_attributes = ["email", "phone_number"]
  
  # Alias Attributes
  alias_attributes = ["email", "phone_number"]
  
  # Admin Create User Config
  admin_create_user_config {
    allow_admin_create_user_only = false
    invite_message_template {
      email_message = null
      email_subject = null
      sms_message   = null
    }
    # unused_account_validity_days is not a valid attribute and has been removed
  }
  
  # Email Configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
  
  # SMS Configuration
  sms_configuration {
    external_id    = "2b8d177b-ef55-4937-8649-17e360695746"
    sns_caller_arn = "arn:aws:iam::071350569379:role/service-role/CognitoIdpSNSServiceRole"
    sns_region     = "us-east-1"
  }
  
  # MFA Configuration
  mfa_configuration = "OFF"
  
  # Username Configuration
  username_configuration {
    case_sensitive = false
  }
  
  # Verification Message Template
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }
  
  # Schema Attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "phone_number"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "given_name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "family_name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "middle_name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "nickname"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "profile"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "address"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "birthdate"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 10
      max_length = 10
    }
  }
  
  schema {
    name                     = "gender"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "locale"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "preferred_username"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "picture"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "website"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "zoneinfo"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "updated_at"
    attribute_data_type      = "Number"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    number_attribute_constraints {
      min_value = "0"
    }
  }
  
  # User Pool Tags
  tags = {}
  
  # Enable/disable deletion protection for the user pool
  deletion_protection = "ACTIVE"
}

# User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain = var.user_pool_domain
  user_pool_id = aws_cognito_user_pool.main.id
}

# Google Identity Provider
resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"
  
  provider_details = {
    attributes_url            = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = "true"
    authorize_scopes          = "email openid profile"
    authorize_url             = "https://accounts.google.com/o/oauth2/v2/auth"
    client_id                 = var.google_client_id
    # Note: client_secret should be set using a secure method such as environment variables or secrets manager
    client_secret             = var.google_client_secret
    oidc_issuer              = "https://accounts.google.com"
    token_request_method     = "POST"
    token_url                = "https://www.googleapis.com/oauth2/v4/token"
  }
  
  attribute_mapping = {
    email     = "email"
    username  = "sub"
  }
}

# User Pool Groups
resource "aws_cognito_user_group" "google_group" {
  name         = var.google_group_name
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Autogenerated group for users who sign in using Google"
  depends_on   = [aws_cognito_identity_provider.google]
}

resource "aws_cognito_user_group" "admins" {
  name         = "Admins"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administrators"
  precedence   = 1
}

resource "aws_cognito_user_group" "power_users" {
  name         = "PowerUsers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Power users with elevated privileges"
  precedence   = 2
}

resource "aws_cognito_user_group" "users" {
  name         = "Users"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Standard users"
  precedence   = 3
}

# Variables
variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.google_client_secret) > 0
    error_message = "The google_client_secret variable must be set and cannot be empty."
  }
}

variable "google_client_id" {
  description = "Google OAuth client ID"
  type        = string
  validation {
    condition     = length(var.google_client_id) > 0
    error_message = "The google_client_id variable must be set and cannot be empty."
  }
}

variable "user_pool_domain" {
  description = "Domain prefix for the Cognito User Pool"
  type        = string
}

variable "google_group_name" {
  description = "Name for the Google user group"
  type        = string
  default     = "GoogleUsers"
}