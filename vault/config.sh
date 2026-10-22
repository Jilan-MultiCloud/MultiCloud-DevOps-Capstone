#!/bin/bash
# vault/config.sh

echo "Initializing Capstone Vault Secret Engine..."

# 1. Enable Key-Value Secret Engine v2 at 'secret/'
vault secrets enable -version=2 kv

# 2. Populate your multi-cloud access matrix securely
vault kv put secret/multicloud-auth \
  aws_access_key="YOUR_AWS_ACCESS_KEY_ID" \
  aws_secret_key="YOUR_AWS_SECRET_ACCESS_KEY" \
  azure_client_id="YOUR_AZURE_CLIENT_ID" \
  azure_client_secret="YOUR_AZURE_CLIENT_SECRET" \
  azure_tenant_id="YOUR_AZURE_TENANT_ID" \
  azure_subscription_id="YOUR_AZURE_SUBSCRIPTION_ID" \
  gcp_service_account_json='{ "type": "service_account", "project_id": "capstone-gcp-project", ... }'

echo "Vault Secret engine configured. Key retrieval is ready."

