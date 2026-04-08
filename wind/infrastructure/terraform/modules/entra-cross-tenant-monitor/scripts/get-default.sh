#!/bin/bash
# Fetches the cross-tenant access default policy via Microsoft Graph.
# Returns a flat string map as required by the Terraform external data source.
# Requires: az CLI authenticated with Policy.Read.All (Graph API application permission)
set -euo pipefail

result=$(az rest \
  --method GET \
  --uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy" \
  --output json 2>&1) || {
  printf '{"error": "%s"}' "$(echo "$result" | tr -d '\n"')" >&2
  exit 1
}

# external data source requires all values to be strings — no nested objects.
echo "$result" | jq -c '{
  raw_json:           tostring,
  allow_invites_from: (.allowInvitesFrom // "notSet")
}'
