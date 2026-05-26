#!/usr/bin/env bash
# ============================================================
#  Install Ansible + the Docker collection + Python SDK.
#  Works on macOS, Ubuntu, Debian, Fedora, CentOS, and other Linux distros.
#  Usage:  ./scripts/install_ansible.sh
# ============================================================
set -euo pipefail

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
      echo "debian"
    elif [[ "$ID" == "fedora" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "centos" ]]; then
      echo "redhat"
    elif [[ "$ID" == "arch" ]]; then
      echo "arch"
    else
      echo "unknown"
    fi
  else
    echo "unknown"
  fi
}

OS=$(detect_os)
echo "🖥️  Detected OS: $OS"
echo ""

# Install based on OS
case "$OS" in
  macos)
    echo "📦 Installing Ansible and sshpass via Homebrew..."
    if ! command -v brew &> /dev/null; then
      echo "❌ Homebrew not found. Please install Homebrew first:"
      echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      exit 1
    fi
    brew install ansible sshpass
    ;;
  debian)
    echo "📦 Installing Ansible and sshpass via apt-get..."
    sudo apt-get update
    sudo apt-get install -y ansible sshpass
    ;;
  redhat)
    echo "📦 Installing Ansible and sshpass via yum/dnf..."
    if command -v dnf &> /dev/null; then
      sudo dnf install -y ansible sshpass
    else
      sudo yum install -y ansible sshpass
    fi
    ;;
  arch)
    echo "📦 Installing Ansible and sshpass via pacman..."
    sudo pacman -Syu --noconfirm ansible sshpass
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    echo "Please install Ansible manually: https://docs.ansible.com/ansible/latest/installation_guide/"
    exit 1
    ;;
esac

echo ""
echo "🔌 Installing the community.docker collection..."
ansible-galaxy collection install community.docker

echo ""
echo "🐍 Installing the Docker Python SDK..."
pip3 install docker

echo ""
echo "✅ Ansible is ready:"
ansible --version | head -n 1
