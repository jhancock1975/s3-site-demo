#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import requests
import logging, logging_config
from security import get_cognito_tokens



def call_api_with_token(token, api_url):
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    payload = {
        "prompt": "hello"
    }
    logging.info("Sending request to API")
    response = requests.post(api_url, json=payload, headers=headers)
    logging.info(f'Status code: {response.status_code}')
    logging.info(f'Response: {response.text}')

if __name__ == "__main__":
    api_urls = ['https://uaylfafva3.execute-api.us-east-1.amazonaws.com/prod/gpt-4o',
                'https://api.taptupo.com/gpt-4o/gpt-4o']
    logging.info("Starting authentication process")
    id_token, access_token = get_cognito_tokens()
    logging.info("ID token acquired, calling API...")
    for url in api_urls:
        logging.info(f"Calling API: {url}")
        logging.info(f"ID token: {id_token}")
        call_api_with_token(id_token, url)
