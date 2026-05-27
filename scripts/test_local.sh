#!/usr/bin/env bash
# ============================================================
#  Test the app LOCALLY before building/pushing any images.
#  Builds both images, runs them together, and curls the API
#  to confirm everything works. Cleans up after itself.
#
#  Usage:  ./scripts/test_local.sh
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

cleanup() {
  echo "🧹 Cleaning up test containers..."
  docker rm -f test-backend test-frontend >/dev/null 2>&1 || true
  docker network rm test-net >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "🏗️  Building images locally (no push)..."
docker build -t student-backend:test -t student-backend:latest ./backend
docker build -t student-frontend:test -t student-frontend:latest ./frontend

echo "🌐 Creating a test network..."
docker network create test-net >/dev/null 2>&1 || true

echo "🚀 Starting backend + frontend..."
docker run -d --name test-backend  --network test-net -p 8000:8000 student-backend:test
docker run -d --name test-frontend --network test-net \
  -e API_URL=http://test-backend:8000 -p 8501:8501 student-frontend:test

echo "⏳ Waiting for the backend to come up..."
ok=""
for i in $(seq 1 15); do
  if curl -fs http://localhost:8000/ >/dev/null 2>&1; then ok="yes"; break; fi
  sleep 2
done

echo ""
if [ -n "$ok" ]; then
  echo "✅ Backend responded:"
  curl -s http://localhost:8000/ ; echo
  echo "✅ Stats endpoint:"
  curl -s http://localhost:8000/stats ; echo
  echo ""
  echo "🎉 Local test PASSED. Open port 8501 in the PORTS tab to click through the UI."
  echo "   (Containers will be removed when this script exits — press Enter to finish,"
  echo "    or Ctrl+C now and run 'docker rm -f test-backend test-frontend' later.)"
  read -r _
else
  echo "❌ Local test FAILED — backend never responded on :8000."
  echo "   Check logs:  docker logs test-backend"
  exit 1
fi
