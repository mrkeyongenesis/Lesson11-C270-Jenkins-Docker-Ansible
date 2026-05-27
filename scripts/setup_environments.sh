#!/usr/bin/env bash
# ============================================================
#  Ensure the local Docker environment is ready for deployment.
#  Usage:  ./scripts/setup_environments.sh
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "🔍 Checking local Docker availability..."
docker version >/dev/null

echo "✅ Docker is available."

cleanup_old_containers() {
  echo "🧹 Removing legacy deployment containers and networks if present..."
  local containers=(deploy-target-stag prod backend-staging frontend-staging backend-production frontend-production)
  local networks=(appnet-staging appnet-production)

  for container in "${containers[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -xq "$container"; then
      echo "    • Removing old container: $container"
      docker rm -f "$container" >/dev/null 2>&1 || true
    fi
  done

  for network in "${networks[@]}"; do
    if docker network ls --format '{{.Name}}' | grep -xq "$network"; then
      echo "    • Removing old network: $network"
      docker network rm "$network" >/dev/null 2>&1 || true
    fi
  done
}

cleanup_old_containers

echo ""
echo "This repository now deploys staging and production on the local Docker host."
echo "Staging:  UI on port 8501, API on port 8001"
echo "Production: UI on port 8502, API on port 8002"
echo ""
echo "If you want to deploy, build your images first or push them to Docker Hub," \
     "then run ./scripts/deploy.sh <dockerhub-username> staging"
