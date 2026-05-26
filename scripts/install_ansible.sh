#!/usr/bin/env bash
# ============================================================
#  Install Ansible + the Docker collection + Python SDK.
#  Run once in a fresh Codespace.
#  Usage:  ./scripts/install_ansible.sh
# ============================================================
set -euo pipefail

echo "📦 Installing Ansible and sshpass..."
sudo apt-get update
sudo apt-get install -y ansible sshpass

echo "🔌 Installing the community.docker collection..."
ansible-galaxy collection install community.docker

echo "🐍 Installing the Docker Python SDK..."
pip install docker

echo ""
echo "✅ Ansible is ready:"
ansible --version | head -n 1
