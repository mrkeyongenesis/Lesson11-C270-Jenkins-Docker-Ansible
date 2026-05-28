docker run -d --name manual-backend --network appnet-local -p 8001:8000 student-backend:latest
docker run -d --name manual-frontend --network appnet-local -e API_URL=http://manual-backend:8000 -p 8501:8501 student-frontend:latest
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' frontend-staging
docker logs frontend-staging --tail 200
docker network rm appnet-staging || true
docker rm -f manual-backend manual-frontend || true
docker network rm appnet-local || true

# Quick Step-by-Step Guide — Simple and Beginner Friendly

This minimal guide shows the exact, copy/paste commands to build, run, and verify the two-tier app (backend + frontend) on your local machine. It keeps each step small and shows what you should expect.

Prerequisites
- Docker installed and running (`docker ps` works)
- A terminal in this repo root

1) Build the local images
Run these two commands to build the images the playbook uses.

```bash
docker build -t student-backend:latest backend
docker build -t student-frontend:latest frontend
```

Expected: Both commands complete without errors. `docker images` will show `student-backend` and `student-frontend`.

2) Quick smoke test (optional)
Run the repo's simple smoke test to catch obvious errors.

```bash
chmod +x scripts/* || true
./scripts/test_local.sh
```

Expected: Script prints successful checks or clear failure messages (which you can debug with `docker logs`).

3) Deploy to local "staging" with Ansible (one command)
This runs the playbook against your local Docker host and creates `backend-staging` and `frontend-staging` containers.

```bash
./scripts/deploy.sh local staging
```

Expected: Playbook output shows network creation, containers started, and final health checks passed. At the end you should see mapped host ports (8001 for backend, 8501 for frontend) listed.

4) Verify containers are running (three quick checks)

List containers and ports:
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'backend-staging|frontend-staging' || true
```

Check backend responds on the mapped host port:
```bash
curl -sS http://localhost:8001/ || true
```

Open the frontend in your browser:
```
http://localhost:8501
```

5) Inspect container internal IPs (optional, useful for learning)
These commands show the Docker-network IPs used for container-to-container communication.

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' backend-staging
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' frontend-staging
```

6) Run a one-off internal-network curl (what Ansible does to verify)
This runs a temporary container attached to the same Docker network and calls the backend by name.

```bash
docker run --rm --network appnet-staging curlimages/curl:8.1.2 -sS http://backend-staging:8000/
```

Expected: A successful HTTP response body from the backend.

7) Troubleshooting quick tips
- If `port already allocated` appears: run `lsof -i :8001` or `docker ps` and stop the conflicting process.
- If a container crashed immediately: check its logs with `docker logs <name>`.
- If frontend can't reach backend: ensure the frontend container's `API_URL` environment is set to `http://backend-staging:8000` (the playbook should handle this).

8) Cleanup commands
Run these to remove staging containers and the network.

```bash
docker rm -f backend-staging frontend-staging || true
docker network rm appnet-staging || true
```

9) Login to containers and verify the apps (inside the container)
These commands show how to "get a shell" inside each container and run a few checks there. This helps you confirm the correct processes, environment variables, and that each service is reachable from inside the Docker network.

- Backend container (FastAPI)

```bash
# open an interactive shell in the backend container (tries bash, falls back to sh)
docker exec -it backend-staging bash || docker exec -it backend-staging sh

# inside the container run these (copy/paste inside the shell):
ps aux | grep -E 'uvicorn|python' --color=auto || true
# check the API locally inside the container
curl -sS http://localhost:8000/ || true
# show env variables (verify API_URL or other vars)
env | grep -i 'api\|port' || true
# view the last lines of the app log file if present
tail -n 200 /app/*.log 2>/dev/null || true
```

What to expect inside backend:
- `ps aux` should show the Python/uvicorn process serving the API.
- `curl http://localhost:8000/` should return a small JSON or health response.

- Frontend container (Streamlit)

```bash
# open an interactive shell in the frontend container
docker exec -it frontend-staging bash || docker exec -it frontend-staging sh

# inside the frontend container run these:
ps aux | grep -i streamlit --color=auto || ps aux | grep -E 'python.*streamlit' --color=auto || true
# check Streamlit locally in the container (container port 8501)
curl -sS http://localhost:8501/ || true
# show environment variables used by the frontend
env | grep -i 'api\|url' || true
# tail possible logs
tail -n 200 /root/.streamlit/logs/* 2>/dev/null || true
```

What to expect inside frontend:
- `ps aux` should show `streamlit` (or a python process running the app).
- `curl http://localhost:8501/` should return HTML (Streamlit page) or a redirect.

Notes
- If `bash` is not present the `sh` fallback will open a shell.
- Some images may not include `curl` or `tail`; install not recommended inside running containers — instead check logs from the host `docker logs <name>`.
- Use `exit` to leave the container shell.

When `ps` or `curl` are missing inside a container
-------------------------------------------------
Some minimal container images don't include utilities like `ps`, `curl`, or `tail`. If you see `command not found` when running those inside the container, use these host-side alternatives which do not require modifying the image:

- See processes from the host (equivalent to `ps` inside container):
```bash
docker top backend-staging || true
docker top frontend-staging || true
```

- Check container logs (equivalent to `tail`):
```bash
docker logs backend-staging --tail 200
docker logs frontend-staging --tail 200
```

- Inspect the container's main process command line (useful when `ps` is missing):
```bash
docker exec backend-staging cat /proc/1/cmdline || true
docker exec frontend-staging cat /proc/1/cmdline || true
```

- Run network checks from a temporary container instead of `curl` inside the app container:
```bash
docker run --rm --network appnet-staging curlimages/curl:8.1.2 -sS http://backend-staging:8000/ || true
```

- Check the host-mapped ports (what a browser hits):
```bash
curl -sS http://localhost:8001/ || true
curl -sS http://localhost:8501/ || true
```

If you prefer a one-line helper that runs these host-side checks, see `scripts/check_staging.sh`.

Extras: Use Docker Hub images

- Build and push to Docker Hub:
```bash
./scripts/build_and_push.sh <your-dockerhub-username>
```

- Deploy using Docker Hub images:
```bash
./scripts/deploy.sh <your-dockerhub-username> staging
```

If you want, I can now:
- Add a tiny `scripts/check_staging.sh` that runs the verification commands in step 4–6, or
- Copy this simplified guide into `docs/ANSIBLE_DEPLOY.md`.

Tell me which next step you want me to do and I'll apply it.

===============================================================================

Full step-by-step tutorial (for students who want to appreciate each command)

Overview
- `backend/`: FastAPI app (container port 8000)
- `frontend/`: Streamlit app (container port 8501)
- Deploy modes: `local` (uses local images) or Docker Hub (requires pushing images)

Step 0 — sanity checks (1 minute)
- Verify Docker is running and you can use it:

```bash
docker version
docker ps
```

If these fail, start Docker Desktop or fix Docker on your machine before proceeding.

Step 1 — build images (2–3 minutes)
- Build backend and frontend images locally:

```bash
docker build -t student-backend:latest backend
docker build -t student-frontend:latest frontend
```

Expected: Both builds finish and `docker images` lists `student-backend:latest` and `student-frontend:latest`.

Why this matters: The Ansible `local` deploy uses these image names. If you later use Docker Hub, the playbook will pull images from the Hub instead.

Step 2 — quick local smoke test (optional, 30s)
- Run the repository's smoke test which performs simple checks:

```bash
chmod +x scripts/* || true
./scripts/test_local.sh
```

If the test fails, check `docker logs` for the failing container, fix, rebuild, and re-run Step 1.

Step 3 — deploy to staging with Ansible (2–4 minutes)
- Deploy using the convenience script (local mode uses `student-*` images):

```bash
./scripts/deploy.sh local staging
```

What happens (summary):
- The playbook creates a Docker network `appnet-staging`.
- It removes any old containers named `backend-staging` or `frontend-staging`.
- It starts `backend-staging` mapping container port 8000 to host 8001.
- It starts `frontend-staging` mapping container port 8501 to host 8501 and sets its `API_URL` to `http://backend-staging:8000` for internal networking.
- It runs an internal-network health-check using a temporary `curl` container, then checks the host-mapped ports.

Step 4 — verify the deployment from the host (1 minute)

- List containers and ports:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'backend-staging|frontend-staging' || true
```

- Check backend via mapped host port:

```bash
curl -sS http://localhost:8001/ || echo "backend did not respond on host port 8001"
```

- Open the frontend in your browser:

```
http://localhost:8501
```

Step 5 — inspect container internals (optional, for understanding)

- Find container internal IPs (how containers reach each other):

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' backend-staging
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' frontend-staging
```

- One-off internal call using a temporary curl container (exact check Ansible performs):

```bash
docker run --rm --network appnet-staging curlimages/curl:8.1.2 -sS http://backend-staging:8000/ || echo "internal curl failed"
```

Step 6 — login to containers and in-container checks (if needed)

If you want to run checks inside the container, try opening a shell. Note many minimal images lack `bash`, `ps`, or `curl`.

- Backend (FastAPI):

```bash
docker exec -it backend-staging bash || docker exec -it backend-staging sh
# then inside container (if ps and curl exist):
ps aux | grep -E 'uvicorn|python' || true
curl -sS http://localhost:8000/ || true
exit
```

- Frontend (Streamlit):

```bash
docker exec -it frontend-staging bash || docker exec -it frontend-staging sh
# then inside container (if streamlit/curl available):
ps aux | grep -i streamlit || true
curl -sS http://localhost:8501/ || true
exit
```

If `ps` or `curl` are missing inside the container: use the host-side alternatives in Step 7.

Step 7 — host-side alternatives when container lacks tools (1 minute)

- Show processes for the container from the host:

```bash
docker top backend-staging
docker top frontend-staging
```

- Tail logs from the host (recommended):

```bash
docker logs backend-staging --tail 200
docker logs frontend-staging --tail 200
```

- Show main process cmdline (helpful when `ps` missing):

```bash
docker exec backend-staging cat /proc/1/cmdline || true
docker exec frontend-staging cat /proc/1/cmdline || true
```

- Internal-network check using a temporary container (no change to app image):

```bash
docker run --rm --network appnet-staging curlimages/curl:8.1.2 -sS http://backend-staging:8000/
```

Step 8 — quick automated verification script

Use the helper script `scripts/check_staging.sh` to run the host-side checks automatically.

```bash
chmod +x scripts/check_staging.sh
./scripts/check_staging.sh
```

Step 9 — common failures and fixes

- Port already allocated: "Bind for 0.0.0.0:8001 failed" — run `lsof -i :8001` or `docker ps` and stop the other service.
- Container exits immediately: `docker logs <name>` shows the Python traceback or error; fix code or dependencies and rebuild.
- Frontend cannot reach backend: ensure frontend environment contains `API_URL=http://backend-staging:8000` and that the Docker network exists.

Step 10 — cleanup (30s)

```bash
docker rm -f backend-staging frontend-staging || true
docker network rm appnet-staging || true
```

Step 11 — optional: push to Docker Hub and deploy from Hub

```bash
./scripts/build_and_push.sh <your-dockerhub-username>
./scripts/deploy.sh <your-dockerhub-username> staging
```

Notes and learning tips
- Use `docker inspect` to learn about networks and IPs.
- Prefer `docker logs` and `docker top` for debugging minimal containers rather than installing tools inside containers.
- The `local` deploy mode is the recommended student workflow.

If you want, I will:
- Copy this guide into `docs/ANSIBLE_DEPLOY.md`, and/or
- Add a one-line `Makefile` target and mark `scripts/check_staging.sh` as executable in the repo.

Tell me which next step to take.