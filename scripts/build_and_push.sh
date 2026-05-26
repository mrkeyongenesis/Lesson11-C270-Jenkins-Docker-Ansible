#!/usr/bin/env bash
# ============================================================
#  Build BOTH app images and push them to Docker Hub.
#  Usage:  ./scripts/build_and_push.sh <your-dockerhub-username>
# ============================================================
set -euo pipefail

DH="${1:-}"
if [ -z "$DH" ]; then
  echo "Usage: $0 <your-dockerhub-username>"
  echo "Example: $0 yourname"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔐 Logging in to Docker Hub as '$DH' (paste your access token as the password)..."
docker login -u "$DH"

echo "🏗️  Building back-end image: $DH/student-backend:latest"
docker build -t "$DH/student-backend:latest" "$REPO_ROOT/backend"

echo "🏗️  Building front-end image: $DH/student-frontend:latest"
docker build -t "$DH/student-frontend:latest" "$REPO_ROOT/frontend"

echo "⬆️  Pushing back-end..."
docker push "$DH/student-backend:latest"

echo "⬆️  Pushing front-end..."
docker push "$DH/student-frontend:latest"

echo ""
echo "✅ Done. Two images are now on Docker Hub:"
echo "   - $DH/student-backend:latest"
echo "   - $DH/student-frontend:latest"
echo ""
echo "Next: ./scripts/setup_environments.sh   then   deploy with Ansible."
