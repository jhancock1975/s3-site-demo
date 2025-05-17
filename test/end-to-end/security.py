import boto3
import os
import hmac
import hashlib
import base64
from env_util import validate_env_vars

validate_env_vars('USERNAME', 'PASSWORD', 'COGNITO_REGION', 'USER_POOL_ID', 'CLIENT_ID', 'CLIENT_SECRET')

# Configuration - replace these with your values
COGNITO_REGION = os.environ['COGNITO_REGION']  # e.g., 'us-east-1'
USER_POOL_ID = os.environ['USER_POOL_ID']  # e.g., 'us-east-1_XXXXXXXXX'
CLIENT_ID = os.environ['CLIENT_ID']
CLIENT_SECRET = os.environ['CLIENT_SECRET']
USERNAME = os.environ['USERNAME']
PASSWORD = os.environ['PASSWORD']

def calculate_secret_hash(client_id, client_secret, username):
    message = username + client_id
    dig = hmac.new(client_secret.encode('utf-8'), message.encode('utf-8'), hashlib.sha256).digest()
    return base64.b64encode(dig).decode()

def get_cognito_tokens():
    client = boto3.client('cognito-idp', region_name=COGNITO_REGION)

    secret_hash = calculate_secret_hash(CLIENT_ID, CLIENT_SECRET, USERNAME)

    response = client.initiate_auth(
        AuthFlow='USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': USERNAME,
            'PASSWORD': PASSWORD,
            'SECRET_HASH': secret_hash
        },
        ClientId=CLIENT_ID
    )

    id_token = response['AuthenticationResult']['IdToken']
    access_token = response['AuthenticationResult']['AccessToken']
    return id_token, access_token