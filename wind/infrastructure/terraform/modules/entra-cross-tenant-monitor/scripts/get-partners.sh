#!/bin/bash
# Fetches all per-partner cross-tenant access configurations via Microsoft Graph.
# Returns a flat string map as required by the Terraform external data source.
# Requires: az CLI authenticated with Policy.Read.All (Graph API application permission)
set -euo pipefail

result=$(az rest \
  --method GET \
  --uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners" \
  --output json 2>&1) || {
  printf '{"error": "%s"}' "$(echo "$result" | tr -d '\n"')" >&2
  exit 1
}

echo "$result" | jq -c '{
  raw_json:  tostring,
  count:     (.value | length | tostring),
  # Sorted by tenantId for stable diffs — order changes in the API response will not create false drift.
  tenant_ids: ([.value[].tenantId] | sort | tostring),
  # Human-readable summary: tenantId + key access settings per org.
  summary: ([.value[] | {
    tenantId:        .tenantId,
    inboundB2B:      (.b2bCollaborationInbound.usersAndGroups.accessType  // "inherited"),
    outboundB2B:     (.b2bCollaborationOutbound.usersAndGroups.accessType // "inherited"),
    inboundTrustMFA: (.inboundTrust.isMfaAccepted                        // false | tostring)
  }] | sort_by(.tenantId) | tostring)
}'
