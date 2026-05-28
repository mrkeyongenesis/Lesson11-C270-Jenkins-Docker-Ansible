#!/usr/bin/env bash
# ============================================================
#  Deploy the app stack to an environment with Ansible.
#  Usage:  ./scripts/deploy.sh <dockerhub-username|local> <staging|production>
#  Examples:
#    ./scripts/deploy.sh myuser staging
#    ./scripts/deploy.sh local staging
# ============================================================
set -euo pipefail

DH="${1:-}"
TARGET="${2:-staging}"

if [ -z "$DH" ]; then
  echo "Usage: $0 <dockerhub-username|local> <staging|production>"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Prepare the local Docker environment and remove old target containers/networks.
"$REPO_ROOT/scripts/setup_environments.sh"

cd "$REPO_ROOT/ansible"

if [ "$DH" = "local" ]; then
  echo "🚀 Deploying '$TARGET' using local images..."
  DH=""

  if ! docker image inspect student-backend:latest >/dev/null 2>&1 || ! docker image inspect student-frontend:latest >/dev/null 2>&1; then
    echo "🔨 Local Docker images not found. Building backend and frontend images now..."
    docker build -t student-backend:latest "$REPO_ROOT/backend"
    docker build -t student-frontend:latest "$REPO_ROOT/frontend"
  else
    echo "✅ Local Docker images already exist. Skipping build."
  fi
else
  echo "🚀 Deploying '$TARGET' using images from Docker Hub user '$DH'..."
fi

ansible-playbook deploy_stack_playbook.yaml -e "target=$TARGET" -e "dh_user=$DH"

echo ""
if [ "$TARGET" = "staging" ]; then
  echo "✅ Staging deployed. Open port 8501 (UI) and 8001/docs (API) in the PORTS tab."
else
  echo "✅ Production deployed. Open port 8502 (UI) and 8002/docs (API) in the PORTS tab."
fi
