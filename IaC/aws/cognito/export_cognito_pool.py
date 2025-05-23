#!/usr/bin/env python3
import boto3
import json
import argparse
import sys

def export_user_pool(client, user_pool_id):
    """Fetch User Pool configuration."""
    resp = client.describe_user_pool(UserPoolId=user_pool_id)
    return resp['UserPool']

def export_identity_providers(client, user_pool_id):
    """List & fetch full config for each IdP in the pool."""
    providers = []
    pages = client.get_paginator('list_identity_providers').paginate(UserPoolId=user_pool_id)
    for page in pages:
        for p in page.get('Providers', []):
            name = p['ProviderName']
            detail = client.describe_identity_provider(
                UserPoolId=user_pool_id,
                ProviderName=name
            )['IdentityProvider']
            # hide sensitive secret
            if 'ProviderDetails' in detail and 'client_secret' in detail['ProviderDetails']:
                detail['ProviderDetails']['client_secret'] = None
            providers.append(detail)
    return providers

def export_user_groups(client, user_pool_id):
    """List all groups defined in the User Pool."""
    groups = []
    pages = client.get_paginator('list_groups').paginate(UserPoolId=user_pool_id)
    for page in pages:
        groups.extend(page.get('Groups', []))
    return groups

def main():
    parser = argparse.ArgumentParser(
        description='Export AWS Cognito User Pool, Identity Providers, and Groups'
    )
    parser.add_argument(
        '--user-pool-id', '-p', required=True,
        help='The Cognito User Pool ID (e.g. us-east-1_ABCdefGHI)'
    )
    parser.add_argument(
        '--region', '-r', default=None,
        help='AWS region (falls back to AWS_DEFAULT_REGION or your profile)'
    )
    parser.add_argument(
        '--output', '-o', default='cognito_export.json',
        help='Filename to write the exported JSON to'
    )
    args = parser.parse_args()

    # init client
    kwargs = {}
    if args.region:
        kwargs['region_name'] = args.region
    client = boto3.client('cognito-idp', **kwargs)

    try:
        pool_cfg = export_user_pool(client, args.user_pool_id)
        idps = export_identity_providers(client, args.user_pool_id)
        groups = export_user_groups(client, args.user_pool_id)
    except client.exceptions.ResourceNotFoundException:
        print(f"Error: User Pool {args.user_pool_id} not found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print("Unexpected error:", e, file=sys.stderr)
        sys.exit(2)

    out = {
        'UserPool': pool_cfg,
        'IdentityProviders': idps,
        'Groups': groups
    }

    # write to file
    with open(args.output, 'w') as f:
        json.dump(out, f, default=str, indent=2)

    print(f"✔️ Export complete. Written to {args.output}")

if __name__ == '__main__':
    main()
