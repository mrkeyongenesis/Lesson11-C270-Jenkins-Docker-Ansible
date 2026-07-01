#!/usr/bin/env bash
set -euo pipefail

echo "Checking staging deployment (non-invasive host-side checks)"

echo ""
echo "1) Containers and ports:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'backend-staging|frontend-staging' || true

echo ""
echo "2) Processes (host-level):"
docker top backend-staging || true
docker top frontend-staging || true

echo ""
echo "3) Tail recent logs (backend then frontend):"
docker logs backend-staging --tail 200 || true
docker logs frontend-staging --tail 200 || true

echo ""
echo "4) Inspect main process cmdline (if ps missing inside):"
docker exec backend-staging cat /proc/1/cmdline || true
docker exec frontend-staging cat /proc/1/cmdline || true

echo ""
echo "5) Internal-network HTTP check via temporary curl container:"
docker run --rm --network appnet-staging curlimages/curl:8.1.2 -sS http://backend-staging:8000/ || true

echo ""
echo "6) Host-mapped HTTP checks (what your browser uses):"
if command -v curl >/dev/null 2>&1; then
  curl -sS http://localhost:8001/ || true
  curl -sS http://localhost:8501/ || true
else
  echo "curl not installed on host — open http://localhost:8501 in browser and check http://localhost:8001/ manually"
fi

echo ""
echo "Done. Use 'docker exec -it <container> sh' to inspect files if needed."