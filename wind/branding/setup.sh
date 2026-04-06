#!/bin/bash
set -e

# --- 1. Environment Validation ---
if [[ -z "$SP_ID" || -z "$SP_SECRET" || -z "$AZURE_TENANT_ID" || -z "$AZURE_SUBSCRIPTION_ID" ]]; then
    echo "❌ ERROR: Missing Azure Service Principal variables (SP_ID, SP_SECRET, or AZURE_TENANT_ID)."
    exit 1
fi

echo "💎 Starting the Mini-Me branding process..."

# 1. Install Azure CLI & Arc Agent
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
wget https://aka.ms/azcmagent -O ~/Install_linux_azcmagent.sh
sudo bash ~/Install_linux_azcmagent.sh

# 2. Add user to identity group (must come after agent install — himds group created by installer)
sudo usermod -aG himds $USER

# --- 3. Management Plane Onboarding ---
echo "🚀 Connecting to Azure Arc..."
sudo azcmagent connect \
  --service-principal-id "$SP_ID" \
  --service-principal-secret "$SP_SECRET" \
  --tenant-id "$AZURE_TENANT_ID" \
  --subscription-id "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "SDDC" \
  --location "eastus" \
  --verbose

# --- 4. Repo Setup (Docker) ---
echo "🐳 Configuring Repositories for Noble (24.04)..."
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings

# Docker GPG & Repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# --- 5. Install the Cattle Toolkit ---
echo "🛠️ Installing Docker"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- 6. Building the Stones ---
echo "🗺️ Mapping the Stones..."
sudo mkdir -p /mnt/stones/{fire,water,earth,air}
sudo usermod -aG docker sonydogg

echo "✅ Cattle Branding Complete. Mini-Me is now part of the SDDC herd."