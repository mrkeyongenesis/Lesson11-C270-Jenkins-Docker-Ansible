#!/usr/bin/env bash
# ============================================================
#  Build the target "server" image and spin up the 2 environments
#  (staging + production) as SSH-able Docker-in-Docker containers.
#  Usage:  ./scripts/setup_environments.sh
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cleanup_existing_targets() {
  echo "🧹 Checking for containers using ports 2211/2212..."
  local ports=(2211 2212)
  local removed=()

  for port in "${ports[@]}"; do
    while IFS= read -r container; do
      if [[ -n "$container" ]]; then
        echo "    • Removing container using port $port: $container"
        docker rm -f "$container" 2>/dev/null || true
        removed+=("$container")
      fi
    done < <(docker ps -a --format '{{.Names}} {{.Ports}}' | grep -E "0\.0\.0\.0:$port|:$port->" | awk '{print $1}' || true)
  done

  for old in staging deploy-target-stag prod; do
    if docker ps -a --format '{{.Names}}' | grep -xq "$old"; then
      echo "    • Removing old container named $old"
      docker rm -f "$old" 2>/dev/null || true
      removed+=("$old")
    fi
  done

  if [[ "${#removed[@]}" -gt 0 ]]; then
    printf "✅ Removed containers: %s\n" "${removed[*]}"
  fi
}

echo "🏗️  Building the deploy-target image..."
docker build -t deploy-target:latest "$REPO_ROOT/ansible/target-image"

echo "🧹 Removing any old environment containers..."
cleanup_existing_targets

wait_for_target_docker() {
  local name="$1"
  local max=30
  local count=0

  echo "⏳ Waiting for Docker daemon inside $name..."
  until docker exec "$name" docker version >/dev/null 2>&1; do
    count=$((count + 1))
    if [[ $count -ge $max ]]; then
      echo "❌ Docker daemon did not become ready inside $name after $max seconds."
      docker logs "$name" --tail 20
      exit 1
    fi
    sleep 2
  done
  echo "✅ Docker daemon ready inside $name."
}

echo "🚀 Starting STAGING  (SSH 2211, UI 8501->8501, API 8001->8000)..."
docker run -d --rm --name deploy-target-stag --privileged \
  -p 2211:22 -p 8501:8501 -p 8001:8000 \
  deploy-target:latest

wait_for_target_docker deploy-target-stag

echo "🚀 Starting PRODUCTION (SSH 2212, UI 8502->8501, API 8002->8000)..."
docker run -d --rm --name prod --privileged \
  -p 2212:22 -p 8502:8501 -p 8002:8000 \
  deploy-target:latest

wait_for_target_docker prod

echo ""
echo "✅ Environments are up:"
docker ps --filter name=deploy-target-stag --filter name=prod --format "table {{.Names}}\t{{.Ports}}"
echo ""
echo "Login for each target: user 'root', password 'root'."
echo "Next: cd ansible && ansible all -m ping"
