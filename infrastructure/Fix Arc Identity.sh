🛠️ The Fix: Granting the Identity "Secret" Powers
Run this on your M1 Mac (where you have Owner rights) to give the Intel Mini the ability to read secrets:

# 1. Get the Principal ID of the Intel Mini's Identity
PRINCIPAL_ID=$(az connectedmachine show --name "mini-me-intel-01" --resource-group "SDDC" --query identity.principalId -o tsv)

# This finds the first vault in your SDDC resource group and grabs its name
export KV_NAME=$(az keyvault list --resource-group "SDDC" --query "[0].name" -o tsv)

# Verify it worked
echo "Your Key Vault is: $KV_NAME"

# 2. Assign the "Key Vault Secrets User" role
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee $PRINCIPAL_ID \
    --scope "/subscriptions/44be4360-5ab3-4c8c-a4aa-a28245851e3f/resourceGroups/SDDC/providers/Microsoft.KeyVault/vaults/$KV_NAME"