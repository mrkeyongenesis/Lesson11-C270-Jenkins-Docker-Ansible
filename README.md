# CI/CD + Ansible Teaching Lab

A student-friendly lab that takes a two-tier web app from source code to running deployment using Docker, Jenkins, and Ansible.

This repo is designed to work inside a **GitHub Codespace**. The goal is to learn the full path:
- run the app locally,
- package each tier as a Docker image,
- publish images to Docker Hub,
- automate builds with Jenkins,
- deploy staging and production with Ansible.

---

## What this repo contains

- `backend/` — FastAPI back-end service
- `frontend/` — Streamlit front-end UI
- `docker-compose.yml` — quick local stack runner
- `ansible/` — deployment playbooks and inventory
- `scripts/` — helper commands for local test, build/push, and deploy
- `Jenkinsfile` — CI/CD pipeline for building and pushing images
- `docs/` — deeper guides on Jenkins and Ansible workflows

---

## What you will learn

- How to run the app locally and confirm it works.
- How Docker images make the app portable.
- How Docker Hub stores images so any machine can pull them.
- How Jenkins can build, test, and push images automatically.
- How Ansible deploys a front-end and back-end to separate environments.

---

## Prerequisites

- A **GitHub account** with a Codespace.
- A **Docker Hub account** and an **access token**.
- The repo opened in a Codespace with Docker available.

---

## Student workflow

Below are the commands you should run in order, with clear expectations at each step.

### 1. Run the app locally and verify it works

This is the first and most important step.

```bash
docker compose up --build
```

Expected result:
- `frontend` is available on port **8501**
- `backend` is available on port **8000**
- the Streamlit UI shows the API URL and can call the back-end
- the FastAPI docs are available at `http://localhost:8000/docs`

If the app works, stop it with `Ctrl+C`.

### 2. Run the automated local smoke test

This builds the images and runs them in a temporary test network.

```bash
chmod 766 scripts/*
./scripts/test_local.sh
```

Expected result:
- `backend` and `frontend` images are built locally
- both containers start successfully
- the script curls `http://localhost:8000/` and `http://localhost:8000/stats`
- the test ends with a success message

If the smoke test fails, fix the app before continuing.

### 3. Build local images for deployment

This creates stable local image tags that the Ansible workflow can use.

```bash
docker build -t student-backend:latest backend
docker build -t student-frontend:latest frontend
```

Expected result:
- `student-backend:latest` is available locally
- `student-frontend:latest` is available locally

You can verify with:

```bash
docker images | grep student-
```

### 4. Deploy staging locally with Ansible

This repo uses Ansible to deploy two environments: staging and production.

The staging environment maps to these local host ports:
- UI → **8501**
- API → **8001**

Run:

```bash
./scripts/deploy.sh local staging
```

Expected result:
- backend container named `backend-staging` starts on port **8001**
- frontend container named `frontend-staging` starts on port **8501**
- the front-end is configured to call `http://backend-staging:8000`
- health checks pass and the task finishes successfully

Then open:
- `http://localhost:8501` for the Streamlit UI
- `http://localhost:8001/docs` for the FastAPI API docs

### 5. Deploy production locally with Ansible

This is the same playbook, but it uses the production target and different ports.

The production environment maps to these local host ports:
- UI → **8502**
- API → **8002**

Run:

```bash
./scripts/deploy.sh local production
```

Expected result:
- backend container named `backend-production` starts on port **8002**
- frontend container named `frontend-production` starts on port **8502**
- the production UI calls `http://backend-production:8000`
- the deployment succeeds without changing the staging deployment

Then open:
- `http://localhost:8502`
- `http://localhost:8002/docs`

### 6. Build and push images to Docker Hub

If you want the full cloud-style flow, push the images to Docker Hub.

```bash
./scripts/build_and_push.sh <your-dockerhub-username>
```

Expected result:
- `yourname/student-backend:latest` is pushed
- `yourname/student-frontend:latest` is pushed

If you use Docker Hub images, deploy with:

```bash
./scripts/deploy.sh <your-dockerhub-username> staging
./scripts/deploy.sh <your-dockerhub-username> production
```

### 7. Use Jenkins to automate build and push

The `Jenkinsfile` builds and pushes both images automatically on every commit.

To use Jenkins:
1. Create a Jenkins pipeline job.
2. Point it at this repository.
3. Add Docker Hub credentials.
4. Run the pipeline.

Expected result:
- backend and frontend images are built automatically
- tests are run
- images are pushed to Docker Hub

---

## What is happening in each environment

### Local manual run

`docker compose up --build` runs both services on your local machine in a single Docker Compose network.

- `frontend` uses `localhost:8000` as the API URL by default
- both containers share the same host Docker engine

### Local smoke test

`./scripts/test_local.sh` builds two temporary image tags and runs them together in an isolated Docker network.

- the backend is `test-backend`
- the frontend is `test-frontend`
- the frontend uses `http://test-backend:8000`

This proves the images work before deployment.

### Local Ansible staging/production

`./scripts/deploy.sh local staging` and `./scripts/deploy.sh local production` run the same Ansible playbook against two different targets.

- staging and production are separate deployments on the same machine
- they use unique container names and unique host ports
- the front-end is wired to the backend by Docker network name

This is the closest student-friendly version of a real multi-environment deployment.

---

## Commands reference

| Task | Command | Expected ports |
|------|---------|----------------|
| Local app run | `docker compose up --build` | 8501 UI, 8000 API |
| Local smoke test | `./scripts/test_local.sh` | 8501 UI, 8000 API |
| Build local images | `docker build -t student-backend:latest backend` <br> `docker build -t student-frontend:latest frontend` | none |
| Deploy staging | `./scripts/deploy.sh local staging` | 8501 UI, 8001 API |
| Deploy production | `./scripts/deploy.sh local production` | 8502 UI, 8002 API |
| Push to Docker Hub | `./scripts/build_and_push.sh <yourname>` | none |

---

## Troubleshooting

- If `docker compose up` fails, fix the app before deploying.
- If the UI does not load, make sure the correct port is open in the PORTS tab.
- If `deploy.sh local staging` fails with port already allocated, stop or remove the old container.
- If Docker Hub push fails, verify your Docker Hub token and username.

For deeper troubleshooting, see:
- `docs/JENKINS_PIPELINE.md`
- `docs/ANSIBLE_DEPLOY.md`
