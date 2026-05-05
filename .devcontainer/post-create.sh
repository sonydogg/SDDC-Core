#!/bin/bash
set -e

# Perforce Helix CLI (p4) — no official devcontainer feature exists
curl -fsSL https://package.perforce.com/perforce.pubkey \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/perforce-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/perforce-archive-keyring.gpg] \
https://package.perforce.com/apt/ubuntu jammy release" \
  | sudo tee /etc/apt/sources.list.d/perforce.list

sudo apt-get update -qq
sudo apt-get install -y helix-cli libvirt-clients

echo "post-create complete: p4, virsh available"
