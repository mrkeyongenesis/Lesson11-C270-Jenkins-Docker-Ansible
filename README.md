# Lesson11-C270-Jenkins-Docker-Ansible

A simple two-tier Docker demo: FastAPI backend + Streamlit frontend.

## Prerequisites
- Docker installed and running
- Terminal open in the repository root

## Local staging deployment

### 1) Build images

```bash
docker build -t student-backend:latest backend
docker build -t student-frontend:latest frontend
```

### 2) Create the staging network

```bash
docker network create appnet-staging || true
```

### 3) Start the backend

```bash
docker rm -f backend-staging >/dev/null 2>&1 || true
docker run -d --name backend-staging --network appnet-staging -p 8001:8000 student-backend:latest
```

### 4) Start the frontend

```bash
docker rm -f frontend-staging >/dev/null 2>&1 || true
docker run -d --name frontend-staging --network appnet-staging -e API_URL=http://backend-staging:8000 -p 8501:8501 student-frontend:latest
```

### 5) Verify the deployment

```bash
curl -sS http://localhost:8001/ || echo "backend did not respond"
```

Open the frontend in a browser:

```text
http://localhost:8501
```

### 6) Cleanup

```bash
docker rm -f backend-staging frontend-staging || true
docker network rm appnet-staging || true
```

## Production deployment

Use different ports so staging and production can coexist.

```bash
docker build -t student-backend:latest backend
docker build -t student-frontend:latest frontend

docker network create appnet-production || true

docker rm -f backend-production >/dev/null 2>&1 || true
docker run -d --name backend-production --network appnet-production -p 8002:8000 student-backend:latest

docker rm -f frontend-production >/dev/null 2>&1 || true
docker run -d --name frontend-production --network appnet-production -e API_URL=http://backend-production:8000 -p 8502:8502 student-frontend:latest
```

Verify production:

```bash
curl -sS http://localhost:8002/ || echo "production backend did not respond"
```

Open in a browser:

```text
http://localhost:8502
```

Cleanup production:

```bash
docker rm -f backend-production frontend-production || true
docker network rm appnet-production || true
```

## Troubleshooting
- Use `docker logs <container>` to inspect crashes
- Use `docker ps` to confirm containers are running
- If ports conflict, stop the process or container using them
