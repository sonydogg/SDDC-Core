#!/bin/bash
# SDDC Host Setup Script v2.0

echo "🚀 Starting SDDC Cattle Branding..."

# 1. Update and Install Core Dependencies
sudo apt-get update && sudo apt-get install -y curl wget gpg

# 2. Install Azure CLI (Noble)
if ! command -v az &> /dev/null; then
    echo "📦 Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# 3. Install Azure Arc Agent
if ! command -v azcmagent &> /dev/null; then
    echo "🌐 Installing Azure Arc Agent..."
    wget https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt-get update && sudo apt-get install -y azcmagent
fi

# 4. Identity Permissions
# Adding user to 'himds' so 'az login --identity' works without sudo
echo "🔑 Configuring Managed Identity permissions..."
sudo usermod -aG himds $USER

echo "✅ Setup complete. Please LOG OUT and LOG BACK IN to apply group changes."