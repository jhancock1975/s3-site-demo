from googleapiclient.discovery import build
from google.oauth2 import service_account

# see separate file in ~/Documents for secret/sensitive values
# Path to your service account key file (must have proper IAM permissions!)
SERVICE_ACCOUNT_FILE = "path/to/your/service-account.json"
PROJECT_ID = "taptupo"

# Define the OAuth Client details you want
CLIENT_NAME = "Taptupo OAuth Client"
REDIRECT_URIS = ["https://yourapp.com/oauth2callback"]
JAVASCRIPT_ORIGINS = ["https://yourapp.com"]

# Authenticate
credentials = service_account.Credentials.from_service_account_file(
    SERVICE_ACCOUNT_FILE,
    scopes=["https://www.googleapis.com/auth/cloud-platform"],
)

service = build("iamcredentials", "v1", credentials=credentials)
api_service = build('oauth2', 'v2', credentials=credentials)

# Building the API service
cloud_service = build('iam', 'v1', credentials=credentials)
apps_service = build('oauth2', 'v2', credentials=credentials)

# Now use the 'credentials' to call the API
# *** This is tricky: OAuth clients are actually managed under APIs & Services, so we use "projects.apps.oauthClients" from "cloudresourcemanager" or "apis" ***
# Using the API directly via HTTP POST is usually required here because Google API Python client doesn't expose "Create OAuth Client" easily

# So better: use discovery API to find the right endpoint
from googleapiclient.discovery import build_from_document

import requests
import json

def create_oauth_client():
    access_token_info = credentials.with_scopes(
        ["https://www.googleapis.com/auth/cloud-platform"]
    ).refresh(requests.Request())

    access_token = credentials.token

    url = f"https://oauth2.googleapis.com/v1/projects/{PROJECT_ID}/clients"

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    payload = {
        "applicationType": "WEB",
        "clientName": CLIENT_NAME,
        "redirectUris": REDIRECT_URIS,
        "javascriptOrigins": JAVASCRIPT_ORIGINS
    }

    response = requests.post(url, headers=headers, data=json.dumps(payload))

    if response.status_code == 200:
        print("OAuth client created successfully:")
        print(response.json())
    else:
        print("Error creating OAuth client:")
        print(response.status_code, response.text)

if __name__ == "__main__":
    create_oauth_client()
