#!/usr/bin/env bash
# ============================================================
#  Build the target "server" image and spin up the 2 environments
#  (staging + production) as SSH-able Docker-in-Docker containers.
#  Usage:  ./scripts/setup_environments.sh
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🏗️  Building the deploy-target image..."
docker build -t deploy-target:latest "$REPO_ROOT/ansible/target-image"

echo "🧹 Removing any old environment containers..."
docker rm -f deploy-target-stag prod 2>/dev/null || true

echo "🚀 Starting STAGING  (SSH 2211, UI 8501->8501, API 8001->8000)..."
docker run -d --rm --name deploy-target-stag --privileged \
  -p 2211:22 -p 8501:8501 -p 8001:8000 \
  deploy-target:latest

echo "🚀 Starting PRODUCTION (SSH 2212, UI 8502->8501, API 8002->8000)..."
docker run -d --rm --name prod --privileged \
  -p 2212:22 -p 8502:8501 -p 8002:8000 \
  deploy-target:latest

echo "⏳ Waiting for the in-container Docker daemons to start..."
sleep 8

echo ""
echo "✅ Environments are up:"
docker ps --filter name=deploy-target-stag --filter name=prod --format "table {{.Names}}\t{{.Ports}}"
echo ""
echo "Login for each target: user 'root', password 'root'."
echo "Next: cd ansible && ansible all -m ping"
