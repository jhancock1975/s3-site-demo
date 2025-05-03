#!/bin/bash
# 1. Admins group (highest precedence)
aws cognito-idp create-group \
  --user-pool-id us-east-1_3k54fOQZH \
  --group-name Admins \
  --description "Administrators" \
  --precedence 1

# 2. PowerUsers group
aws cognito-idp create-group \
  --user-pool-id us-east-1_3k54fOQZH \
  --group-name PowerUsers \
  --description "Power users with elevated privileges" \
  --precedence 2

# 3. Users group (default/lowest precedence)
aws cognito-idp create-group \
  --user-pool-id us-east-1_3k54fOQZH \
  --group-name Users \
  --description "Standard users" \
  --precedence 3
