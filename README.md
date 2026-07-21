# 🎓 Student App — End-to-End CI/CD Guide

A complete, hands-on guide to building, testing, scanning, deploying, and monitoring a **two-tier web application** (FastAPI + Streamlit) with a **fully automated pipeline** — Jenkins configures **itself** (plugins, credentials/PATs, and the pipeline job are imported automatically from a `.env` file).

**Every tool in this project is free and open source.**

```
┌───────────────────────────────────────────────────────────────────────────┐
│                          WHAT YOU'LL BUILD                                │
│                                                                           │
│   ┌──────────┐   ┌──────────┐    ┌──────────────┐    ┌──────────────┐     │
│   │  FastAPI │   │ Streamlit│    │   Staging    │    │  Production  │     │
│   │  Backend │◄──│ Frontend │───▶│ localhost:   │───▶│  localhost:  │     │
│   │  :8000   │   │  :8501   │    │ 8501 / 8001  │    │ 8502 / 8002  │     │
│   └──────────┘   └──────────┘    └──────────────┘    └──────────────┘     │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │  FULLY AUTOMATED CI/CD PIPELINE (Jenkins, auto-created via JCasC)  │   │
│  │                                                                    │   │
│  │  Code → Lint → Unit Test → Build → API Test → Security Scan →      │   │
│  │  SonarQube → Quality Gate → Push (Docker Hub + Nexus) →            │   │
│  │  Ansible Deploy (Staging → Production) → Monitor (Grafana)         │   │
│  └────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Table of Contents

- [🏗 Architecture Overview](#-architecture-overview)
- [✅ Prerequisites](#-prerequisites)
- [📁 Project Structure](#-project-structure)
- [🔑 Step 0 — Clone & Create Your `.env` (do this first!)](#-step-0--clone--create-your-env-do-this-first)
- [🚀 Step 1 — Run the App with Docker Compose (30 seconds)](#-step-1--run-the-app-with-docker-compose-30-seconds)
- [🔧 Step 2 — Run Manually (Understand Every Piece)](#-step-2--run-manually-understand-every-piece)
- [🌐 Step 3 — Explore the Backend API](#-step-3--explore-the-backend-api)
- [🧪 Step 4 — Lint & Unit Tests](#-step-4--lint--unit-tests)
- [🔍 Step 5 — Security Scanning & SonarQube](#-step-5--security-scanning--sonarqube)
- [📦 Step 6 — Docker Hub (Public Registry)](#-step-6--docker-hub-public-registry)
- [🗄 Step 7 — Nexus (Private Registry)](#-step-7--nexus-private-registry)
- [🔄 Step 8 — Jenkins: The Fully Automated Pipeline](#-step-8--jenkins-the-fully-automated-pipeline)
- [🧫 Step 9 — API Testing with Newman](#-step-9--api-testing-with-newman)
- [📈 Step 10 — Monitoring with Prometheus & Grafana](#-step-10--monitoring-with-prometheus--grafana)
- [🤖 Step 11 — Deploy with Ansible (Staging → Production)](#-step-11--deploy-with-ansible-staging--production)
- [✅ Step 12 — The Complete End-to-End Run](#-step-12--the-complete-end-to-end-run)
- [🧰 Toolchain (All Open Source, with Links)](#-toolchain-all-open-source-with-links)
- [🔧 Troubleshooting](#-troubleshooting)
- [📚 Learn More](#-learn-more)

---

## 🏗 Architecture Overview

### The Application

A **two-tier web application** — a backend API and a frontend UI that talks to it:

| Tier | Technology | What It Does | Port |
|------|-----------|-------------|------|
| **Backend** | FastAPI (Python) | REST API — manage student records (CRUD) + `/metrics` for Prometheus | `:8000` |
| **Frontend** | Streamlit (Python) | Web UI that calls the backend API | `:8501` |
| **Database** | In-memory (Python list) | Stores student data (resets on restart) | — |

### How the Tiers Connect

```
  You (Browser)
       │
       ▼  http://localhost:8501
  ┌──────────────────────┐
  │  Streamlit Frontend  │  (app.py)
  └─────────┬────────────┘
            │  HTTP GET/POST http://backend:8000
            ▼
  ┌──────────────────────┐
  │  FastAPI Backend     │  (main.py) — also exposes /metrics
  └─────────┬────────────┘
            ▼
  ┌──────────────────────┐
  │  In-memory Database  │  5 students (Alice, Bob, Charlie, ...)
  └──────────────────────┘
```

### The Three Environments

| Environment | UI Port | API Port | What It's For |
|-------------|---------|----------|--------------|
| **Local dev** | `:8501` | `:8000` | Quick testing on your machine |
| **Staging** | `:8501` | `:8001` | Pre-production validation (deployed by Ansible) |
| **Production** | `:8502` | `:8002` | Live app, simulated locally (deployed by Ansible) |

### The Full Automated Pipeline

```
  Git Push ──▶ Jenkins (auto-created pipeline: student-app-pipeline)
                 │
                 ├─ 1. Checkout          git clone via your GitHub PAT
                 ├─ 2. Lint (parallel)   Hadolint · Ruff · mypy · Bandit
                 ├─ 3. Unit Tests        pytest (FastAPI TestClient)
                 ├─ 4. Build Images      docker build backend + frontend
                 ├─ 5. API Tests         smoke curl + Newman (Postman CLI)
                 ├─ 6. Security Scans    Trivy (fs + images) · OWASP DC
                 ├─ 7. SonarQube         static code-quality analysis
                 ├─ 8. Quality Gate      fail if too many HIGH/CRITICAL CVEs
                 ├─ 9. Push              Docker Hub  (+ Nexus, optional)
                 ├─ 10. Smoke Deploy     run the freshly built stack
                 └─ 11. Ansible Deploy   ──▶ Staging ──verify──▶ Production
                                                    │
                              Prometheus + Grafana ─┘  (monitor everything)
```

---

## ✅ Prerequisites

| Tool | Why You Need It | Check Installed | Install If Missing |
|------|----------------|----------------|-------------------|
| **Docker** (with Compose) | Runs everything | `docker version && docker compose version` | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| **Git** | Clone repo & trigger builds | `git --version` | [git-scm.com](https://git-scm.com/) |
| **Python 3.11+** | Run tests & linters locally | `python3 --version` | [python.org](https://www.python.org/downloads/) |
| **curl** | Test API endpoints | `curl --version` | Built into macOS / `sudo apt install curl` |

Accounts you'll create along the way (both free):

- **GitHub** — hosts your fork of this repo → https://github.com
- **Docker Hub** — hosts your built images → https://hub.docker.com

> 💻 **Resources:** running the *entire* stack (app + Jenkins + SonarQube + Nexus + monitoring) needs ~8 GB of RAM for Docker. Start only what each step needs — the compose file uses *profiles* so heavy services stay off until you ask for them.

**First step — verify Docker is ready:**

```bash
docker version
docker ps
```

> Both must complete without errors. If `docker ps` fails, open Docker Desktop and wait for **"Running"**.

---

## 📁 Project Structure

```
Lesson11-C270-Jenkins-Docker-Ansible/
│
├── 📄 Jenkinsfile                 # 🔄 CI/CD pipeline (12 stages)
├── 📄 docker-compose.yml          # 🐳 One-command lab (app + CI + monitoring)
├── 📄 .env.example                # 🔑 Copy to .env — feeds ALL credentials
├── 📄 pyproject.toml              # 🐍 Python tool config (Ruff, mypy)
├── 📄 sonar-project.properties    # 📊 SonarQube config
├── 📄 .hadolint.yaml              # 🐳 Dockerfile linter config
├── 📄 .trivyignore                # 🛡️ Vulnerability ignore rules
│
├── 📁 backend/                    # 🖥️ FASTAPI BACKEND
│   ├── main.py                    #    REST endpoints + /metrics (Prometheus)
│   ├── test_main.py               #    🧪 pytest unit tests
│   ├── requirements.txt           #    runtime deps
│   ├── requirements-dev.txt       #    test-only deps (pytest, httpx)
│   └── Dockerfile
│
├── 📁 frontend/                   # 🎨 STREAMLIT FRONTEND
│   ├── app.py                     #    interactive API explorer
│   ├── requirements.txt
│   └── Dockerfile
│
├── 📁 jenkins/                    # 🤖 JENKINS AUTOMATED SETUP
│   ├── Dockerfile                 #    Jenkins + Docker CLI + Ansible baked in
│   ├── plugins.txt                #    plugins pre-installed (no clicking!)
│   └── casc/jenkins.yaml          #    JCasC: imports credentials/PATs from
│                                  #    .env + auto-creates the pipeline job
│
├── 📁 ansible/                    # 🤖 ANSIBLE DEPLOYMENT
│   ├── ansible.cfg
│   ├── hosts                      #    inventory (staging + production)
│   ├── setup_basics_playbook.yaml
│   └── deploy_stack_playbook.yaml #    deploy both containers + health checks
│
├── 📁 monitoring/                 # 📈 MONITORING
│   ├── prometheus.yml             #    scrapes backend /metrics + cAdvisor
│   └── grafana/provisioning/      #    Prometheus datasource auto-configured
│
├── 📁 tests/postman/              # 🧫 API TESTS
│   └── student-api.postman_collection.json   # run by Newman in the pipeline
│
├── 📁 scripts/                    # 🛠️ HELPER SCRIPTS
│   ├── scan.sh                    #    run ALL security & lint checks
│   ├── test_local.sh              #    build + run + test locally
│   ├── build_and_push.sh          #    build & push to Docker Hub
│   ├── deploy.sh                  #    deploy with Ansible (one command)
│   ├── check_staging.sh           #    inspect the staging deployment
│   ├── setup_environments.sh      #    clean up before deploying
│   └── install_ansible.sh         #    install Ansible on any OS
│
└── 📁 docs/                       # 📖 Deep-dive reference guides
    ├── JENKINS_PIPELINE.md
    └── ANSIBLE_DEPLOY.md
```

---

## 🔑 Step 0 — Clone & Create Your `.env` (do this first!)

Everything downstream — Jenkins credentials, the auto-created pipeline, registry pushes — is driven by **one file**: `.env`.

### 0a. Fork & Clone

1. **Fork** this repo on GitHub (you need your own copy so Jenkins can build *your* pushes).
2. Clone your fork:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/Lesson11-C270-Jenkins-Docker-Ansible.git
cd Lesson11-C270-Jenkins-Docker-Ansible
```

### 0b. Create `.env`

```bash
cp .env.example .env
```

Open `.env` and fill in what you have **now** (you'll add tokens as you create them in later steps):

| Variable | What It Is | Created In |
|----------|-----------|-----------|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | Docker Hub login + access token (PAT) | [Step 6](#-step-6--docker-hub-public-registry) |
| `GITHUB_USER` / `GITHUB_PAT` | GitHub username + Personal Access Token | [Step 8](#-step-8--jenkins-the-fully-automated-pipeline) |
| `GIT_REPO_URL` | **Your fork's** URL — the pipeline builds this | now |
| `SONAR_TOKEN` | SonarQube analysis token | [Step 5](#-step-5--security-scanning--sonarqube) |
| `NEXUS_USER` / `NEXUS_PASSWORD` | Nexus admin login | [Step 7](#-step-7--nexus-private-registry) |
| `JENKINS_ADMIN_USER` / `JENKINS_ADMIN_PASSWORD` | Your Jenkins login (created for you) | defaults fine |

> 🔒 `.env` is in `.gitignore` — it must **never** be committed. This is how real teams keep secrets out of Git while still automating everything.

---

## 🚀 Step 1 — Run the App with Docker Compose (30 seconds)

Get the application up and running first — CI/CD comes after you have something to deliver.

```bash
docker compose up -d --build backend frontend
```

### Verify It's Alive

| Service | URL | You Should See |
|---------|-----|---------------|
| Frontend UI | http://localhost:8501 | 🎓 **Student API Explorer** |
| Backend API docs | http://localhost:8000/docs | FastAPI interactive docs |
| Backend health | http://localhost:8000/ | `{"message":"🎓 Student API is running!","status":"OK"}` |
| Backend metrics | http://localhost:8000/metrics | Prometheus metrics text |

### Your First Interaction

1. **Open** http://localhost:8501
2. **Click** `"🏠 Home — Health Check"` → **"🚀 Send Request"** → status `OK`
3. **Click** `"📋 GET — All Students"` → you should see 5 students: Alice, Bob, Charlie, Diana, Eve
4. **Click** `"📊 GET — Stats"` → average grade 79.8, highest 95, lowest 61

### When You're Done

```bash
docker compose down        # stop (keeps volumes)
docker compose down -v     # stop AND wipe volumes (fresh start)
```

---

## 🔧 Step 2 — Run Manually (Understand Every Piece)

Running manually teaches you **exactly** what Docker Compose (and later Ansible) does for you.

### 2a. Clean Up

```bash
./scripts/setup_environments.sh
```

### 2b. Build the Images

```bash
docker build -t student-backend:latest ./backend
docker build -t student-frontend:latest ./frontend
```

**What the Dockerfile does:**

```dockerfile
FROM python:3.11-slim                # 1. Start with minimal Python
WORKDIR /app                         # 2. Set working directory
COPY requirements.txt .              # 3. Copy dependency list
RUN pip install -r requirements.txt  # 4. Install packages
COPY main.py .                       # 5. Copy app code
EXPOSE 8000                          # 6. Document the port
CMD ["uvicorn", "main:app", ...]     # 7. Startup command
```

### 2c. Create a Network & Start Both Tiers

```bash
docker network create appnet

docker run -d --name backend  --network appnet -p 8000:8000 student-backend:latest

docker run -d --name frontend --network appnet \
  -e API_URL=http://backend:8000 -p 8501:8501 student-frontend:latest
```

| Flag | Meaning |
|------|---------|
| `-d` | Detached (background) |
| `--name backend` | Frontend finds it **by name** on the shared network |
| `--network appnet` | Both containers join the same private network |
| `-p 8000:8000` | host:container port mapping |
| `-e API_URL=...` | Container-to-container URL — **not** `localhost`! |

### 2d. Verify, Then Clean Up

```bash
curl http://localhost:8000/            # health
curl http://localhost:8000/students    # data
open http://localhost:8501             # UI (macOS)

docker rm -f backend frontend && docker network rm appnet
```

> **`docker run` vs `docker exec`** — a classic student mix-up:
> - `docker run -it IMAGE /bin/bash` creates a **NEW** container from an *image*.
> - `docker exec -it CONTAINER /bin/bash` enters an **already-running** *container*.
> - `docker run -it backend-staging /bin/bash` fails with "pull access denied" because `backend-staging` is a container name, not an image. Use `docker exec` there.

---

## 🌐 Step 3 — Explore the Backend API

| Method | Endpoint | What It Does | Try It |
|--------|----------|-------------|--------|
| `GET` | `/` | Health check | `curl localhost:8000/` |
| `GET` | `/students` | List all students | `curl localhost:8000/students` |
| `GET` | `/students/{id}` | Get one student | `curl localhost:8000/students/1` |
| `POST` | `/students` | Add a student | *(below)* |
| `PUT` | `/students/{id}` | Update a student | *(below)* |
| `DELETE` | `/students/{id}` | Delete a student | *(below)* |
| `GET` | `/search?subject=Math` | Filter by subject | `curl "localhost:8000/search?subject=Math"` |
| `GET` | `/stats` | Class statistics | `curl localhost:8000/stats` |
| `GET` | `/metrics` | Prometheus metrics | `curl localhost:8000/metrics` |

**Hands-on exercises:**

```bash
# 1. CREATE (POST)
curl -X POST http://localhost:8000/students \
  -H "Content-Type: application/json" \
  -d '{"name":"Grace","grade":91,"subject":"Math"}'

# 2. UPDATE (PUT)
curl -X PUT http://localhost:8000/students/1 \
  -H "Content-Type: application/json" -d '{"grade":97}'

# 3. DELETE
curl -X DELETE http://localhost:8000/students/3

# 4. SEARCH + STATS
curl "http://localhost:8000/search?subject=Science"
curl http://localhost:8000/stats
```

> **Pro tip:** http://localhost:8000/docs gives you a clickable UI for every endpoint.

---

## 🧪 Step 4 — Lint & Unit Tests

"Shift left": catch problems on your laptop **before** the pipeline ever runs.

### 4a. Unit Tests (pytest)

The backend has a real test suite in [backend/test_main.py](backend/test_main.py) using FastAPI's `TestClient` — no server or Docker needed:

```bash
pip3 install -r backend/requirements.txt -r backend/requirements-dev.txt
pytest backend/ -v
```

You should see all tests pass:

```
backend/test_main.py::test_health_check PASSED
backend/test_main.py::test_list_all_students PASSED
backend/test_main.py::test_create_student PASSED
backend/test_main.py::test_create_student_rejects_bad_payload PASSED
backend/test_main.py::test_delete_student PASSED
backend/test_main.py::test_stats PASSED
...
```

> The same tests run automatically in the pipeline's **Unit Tests (pytest)** stage, and Jenkins publishes the JUnit report on every build.

### 4b. Lint Everything (One Command)

```bash
# macOS install
brew install hadolint trivy
pip3 install ruff mypy bandit

./scripts/scan.sh
```

| # | Tool | Type | What It Catches |
|---|------|------|----------------|
| 1 | **Hadolint** | Dockerfile lint | Unsafe Docker patterns |
| 2 | **Bandit** | Python security | Hardcoded passwords, `eval()`, injection |
| 3 | **Ruff** (lint) | Python lint | Syntax errors, unused imports |
| 4 | **Ruff** (format) | Python style | Inconsistent formatting |
| 5 | **mypy** | Type check | Wrong argument types, missing returns |

### 4c. Auto-Fix

```bash
ruff check --fix backend/ frontend/
ruff format backend/ frontend/
```

---

## 🔍 Step 5 — Security Scanning & SonarQube

### 5a. Vulnerability Scans (Trivy + OWASP)

```bash
./scripts/scan.sh trivy-fs trivy-image owasp
```

| Tool | Scans | For |
|------|-------|-----|
| **Trivy** (fs) | Source + requirements | Known CVEs, leaked secrets, misconfig |
| **Trivy** (image) | Built Docker images | CVEs in OS packages + Python deps |
| **OWASP Dependency-Check** | `requirements.txt` | Dependencies with published vulnerabilities |

### 5b. Start SonarQube & Generate Your Token

```bash
docker compose up -d sonarqube        # needs ~2 GB RAM; wait 1-2 min
```

1. Open http://localhost:9000 → login `admin` / `admin` (you'll be asked to change it)
2. **My Account → Security → Generate Token** (type: *User token*)
3. Copy the token into `.env`:

```bash
SONAR_TOKEN=squ_xxxxxxxxxxxxxxxx
```

### 5c. Run a Scan

```bash
SONAR_TOKEN=squ_xxx ./scripts/scan.sh sonar
```

Open http://localhost:9000 → project **student-app** → explore *bugs, code smells, duplications, security hotspots*.

> The pipeline's **SonarQube Analysis** stage does the same automatically — using the `sonar-token` credential Jenkins imported from your `.env`.

---

## 📦 Step 6 — Docker Hub (Public Registry)

The pipeline needs somewhere to publish images so Ansible can pull them anywhere.

### 6a. Create an Account + Access Token (PAT)

1. Sign up at https://hub.docker.com (free)
2. **Account Settings → Security → New Access Token** → permissions: **Read & Write**
3. Copy the token — Docker Hub only shows it **once**

### 6b. Save It in `.env`

```bash
DOCKERHUB_USERNAME=yourname
DOCKERHUB_TOKEN=dckr_pat_xxxxxxxxxxxx
```

### 6c. Test a Manual Push (Optional but Recommended)

```bash
./scripts/build_and_push.sh YOUR_DOCKERHUB_USERNAME
```

Then check https://hub.docker.com/u/YOUR_DOCKERHUB_USERNAME — you should see `student-backend` and `student-frontend` repositories.

> In the pipeline, the **Push to Docker Hub** stage logs in with the `dockerhub` credential (imported from `.env`) and pushes `:latest`, `:<build-number>`, and `:<branch>-<build-number>` tags.

---

## 🗄 Step 7 — Nexus (Private Registry)

Real companies rarely push straight to a public registry — they use a **private artifact repository**. [Sonatype Nexus Repository OSS](https://www.sonatype.com/products/sonatype-nexus-oss) is the open-source standard.

### 7a. Start Nexus

```bash
docker compose --profile nexus up -d
# Nexus takes 1-2 minutes to boot. Watch it:
docker logs -f nexus        # Ctrl+C when you see "Started Sonatype Nexus"
```

### 7b. First Login

```bash
# Get the generated admin password:
docker exec nexus cat /nexus-data/admin.password
```

1. Open http://localhost:8081 → **Sign in** → user `admin` + that password
2. Follow the wizard → set a new password → **Enable anonymous access: No**
3. Save the new password in `.env`:

```bash
NEXUS_USER=admin
NEXUS_PASSWORD=your-new-password
```

### 7c. Create a Docker (hosted) Repository

1. ⚙️ **Server administration** → **Repositories** → **Create repository**
2. Choose **docker (hosted)**
3. Name: `docker-hosted` — check **HTTP** and enter port **8082**
4. Check **Allow anonymous docker pull** (optional) → **Create repository**
5. Also go to **Security → Realms** and add **Docker Bearer Token Realm** to the active list → Save

### 7d. Push an Image to Your Private Registry

```bash
docker login localhost:8082 -u admin        # paste your Nexus password
docker tag student-backend:latest localhost:8082/student-backend:manual
docker push localhost:8082/student-backend:manual
```

Browse it: http://localhost:8081 → **Browse** → `docker-hosted`. 🎉 You now run your own registry.

> In the pipeline, tick the **`PUSH_TO_NEXUS`** parameter and the **Push to Nexus** stage pushes both images using the `nexus` credential imported from `.env`. (Docker allows plain-HTTP for `localhost` registries by default — no daemon config needed.)

---

## 🔄 Step 8 — Jenkins: The Fully Automated Pipeline

This is the headline act: Jenkins **configures itself**. No setup wizard, no clicking through plugin pages, no manually typing credentials, no manually creating jobs.

### What the Automation Does

When the Jenkins container boots, three files do all the work:

| File | What It Automates |
|------|------------------|
| [jenkins/Dockerfile](jenkins/Dockerfile) | Bakes in the Docker CLI + Ansible + all plugins — and **disables the setup wizard** |
| [jenkins/plugins.txt](jenkins/plugins.txt) | Pre-installs every plugin the pipeline needs (Docker Pipeline, Git, JCasC, Job DSL, JUnit, ...) |
| [jenkins/casc/jenkins.yaml](jenkins/casc/jenkins.yaml) | **Jenkins Configuration as Code**: creates your admin user, **imports 4 credentials from `.env`** (Docker Hub PAT, GitHub PAT, SonarQube token, Nexus login), and **auto-creates the `student-app-pipeline` job** pointing at your fork's `Jenkinsfile` |

```
        .env                    docker-compose.yml              Jenkins
  ┌──────────────────┐      ┌─────────────────────────┐   ┌─────────────────────┐
  │ DOCKERHUB_TOKEN  │      │ injects env vars into   │   │ JCasC reads them:   │
  │ GITHUB_PAT       │ ───▶ │ the jenkins container   │──▶│ • credentials store │
  │ SONAR_TOKEN      │      │                         │   │ • admin user        │
  │ NEXUS_PASSWORD   │      │                         │   │ • pipeline job      │
  │ GIT_REPO_URL     │      └─────────────────────────┘   └─────────────────────┘
  └──────────────────┘        secrets never touch Git!
```

### 8a. Create Your GitHub PAT

1. GitHub → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**
2. Repository access: **your fork only** — Permissions: **Contents: Read-only**
3. Save it in `.env`:

```bash
GITHUB_USER=your-github-username
GITHUB_PAT=github_pat_xxxxxxxxxxxx
GIT_REPO_URL=https://github.com/your-github-username/Lesson11-C270-Jenkins-Docker-Ansible.git
```

### 8b. Boot the Self-Configuring Jenkins

Make sure `.env` now has: `DOCKERHUB_*` (Step 6), `GITHUB_*` + `GIT_REPO_URL` (above), `SONAR_TOKEN` (Step 5), `NEXUS_*` (Step 7). Then:

```bash
docker compose up -d --build jenkins
docker logs -f jenkins        # Ctrl+C once you see "Jenkins is fully up and running"
```

### 8c. Verify the Automation Worked

Open http://localhost:8080 and log in with `JENKINS_ADMIN_USER` / `JENKINS_ADMIN_PASSWORD` from your `.env` (default `admin`/`admin`). You should find, **with zero manual setup**:

- ✅ The system message: *"configured automatically with Configuration as Code"*
- ✅ **Manage Jenkins → Credentials** → 4 entries: `dockerhub`, `github-cred`, `sonar-token`, `nexus`
- ✅ On the dashboard: the **`student-app-pipeline`** job, already pointing at your fork's `Jenkinsfile`

> Changed something in `.env`? Re-apply with:
> `docker compose up -d --force-recreate jenkins`

### 8d. Run the Pipeline

1. Click **student-app-pipeline** → **Build with Parameters**

| Parameter | Set To | Notes |
|-----------|--------|-------|
| `DOCKER_USER` | your Docker Hub username | required for the push stage |
| `DEPLOY_TARGET` | `staging` | or `none` to skip deploy |
| `SKIP_SONAR` | ⬜ unchecked | SonarQube is running from Step 5 |
| `SKIP_SECURITY_SCAN` | ⬜ unchecked | check it for faster dev builds |
| `PUSH_TO_NEXUS` | ✅ checked | if you completed Step 7 |
| `NEXUS_REGISTRY` | `localhost:8082` | default |

2. Click **Build** and watch the stages light up:

```
 ✅ Checkout                 → clones your fork (github-cred PAT)
 ✅ Code Quality & Lint      → Hadolint · Ruff · mypy · Bandit (parallel)
 ✅ Unit Tests (pytest)      → 11 backend tests, JUnit report published
 ✅ Build Images             → backend + frontend (parallel)
 ✅ API Tests (smoke+Newman) → curl smoke checks + 8-request Postman suite
 ✅ Security Scan            → Trivy fs + images · OWASP DC (parallel)
 ✅ SonarQube Analysis       → results appear at localhost:9000
 ✅ Quality Gate             → fails build if too many HIGH/CRITICAL CVEs
 ✅ Push to Docker Hub       → :latest, :N and :branch-N tags
 ✅ Push to Nexus            → private registry copy
 ✅ Deploy (local smoke run) → boots the freshly built stack, curls it
 ✅ Deploy via Ansible       → staging containers on :8001/:8501
```

3. Click any stage → **Logs** to see exactly what ran. Test results appear under **Test Result**; scan reports under **Artifacts**.

### 8e. Make It Trigger Automatically

The job already polls your repo every 2 minutes (`H/2 * * * *`). Prove the automation end-to-end:

```bash
echo "# pipeline test $(date)" >> backend/main.py
git commit -am "Trigger pipeline" && git push
```

Within ~2 minutes a new build starts by itself. For **instant** builds, add a webhook (needs Jenkins reachable from GitHub — e.g. via [ngrok](https://ngrok.com) on a laptop):

1. GitHub fork → **Settings → Webhooks → Add webhook**
2. Payload URL: `http://YOUR_PUBLIC_IP:8080/github-webhook/` — content type `application/json` — just the push event

---

## 🧫 Step 9 — API Testing with Newman

Unit tests check functions; **API tests check the running service over real HTTP** — status codes, JSON shapes, response times, and full CRUD round-trips.

The suite lives in [tests/postman/student-api.postman_collection.json](tests/postman/student-api.postman_collection.json) and runs with [Newman](https://github.com/postmanlabs/newman), the open-source Postman CLI. It executes 8 chained requests:

```
1. Health check          → expects status OK, < 1s response
2. List students         → expects ≥ 5 students with correct fields
3. POST a new student    → expects 201, saves the new id
4. GET that student back → proves the write persisted
5. PUT update the grade  → expects grade == 100
6. Search by subject     → finds the new student
7. DELETE (cleanup)      → expects deletion confirmed
8. Stats                 → schema still consistent
```

### Run It Yourself (against the dev app from Step 1)

```bash
docker run --rm --network cicd-net \
  -v "$PWD/tests/postman:/etc/newman" \
  postman/newman:alpine run student-api.postman_collection.json \
  --env-var baseUrl=http://backend:8000
```

You'll get a table of assertions — all should pass. To test **staging** after Step 11, use `--env-var baseUrl=http://host.docker.internal:8001`.

> In the pipeline this runs in the **API Tests (smoke + Newman)** stage against a throwaway container built from the *exact image about to be shipped* — and publishes a JUnit report to Jenkins.

---

## 📈 Step 10 — Monitoring with Prometheus & Grafana

Deploying is not the end — you need to **see** the app behaving in staging/production.

| Tool | Role | URL |
|------|------|-----|
| **Prometheus** | Scrapes & stores metrics every 15s | http://localhost:9090 |
| **cAdvisor** | Per-container CPU/RAM/network metrics | http://localhost:8085 |
| **Grafana** | Dashboards over Prometheus data | http://localhost:3000 |
| **Backend `/metrics`** | App-level metrics (requests, latency, errors) | http://localhost:8000/metrics |

### 10a. Start the Monitoring Stack

```bash
docker compose --profile monitoring up -d
```

### 10b. Check Prometheus Targets

Open http://localhost:9090 → **Status → Targets**. You should see:

- `student-backend-dev` — **UP** (the compose backend)
- `cadvisor` — **UP**
- `student-backend-staging` / `-production` — DOWN *until* you deploy with Ansible in Step 11 (then they turn green — great feedback loop!)

Try a query in **Graph**: `http_requests_total` — click around the frontend at :8501 and watch the counters climb.

### 10c. Grafana Dashboards

1. Open http://localhost:3000 → login `admin` / `admin` (from `.env`)
2. The Prometheus datasource is **already provisioned** (no clicking — [monitoring/grafana/provisioning](monitoring/grafana/provisioning/datasources/prometheus.yml) did it)
3. **Dashboards → New → Import** and use these community dashboard IDs:
   - **`193`** — Docker containers overview (cAdvisor)
   - **`14282`** — cAdvisor per-container details
4. Build your own panel: **New dashboard → Add visualization** → query:

```promql
rate(http_requests_total{handler="/students"}[1m])
```

Generate traffic (click around the UI, or loop `curl localhost:8000/students`) and watch the graph move.

---

## 🤖 Step 11 — Deploy with Ansible (Staging → Production)

Ansible makes deployments **repeatable, idempotent, and identical** across environments. The pipeline's last stage runs exactly this — here you'll run it by hand to understand it.

### What the Playbook Does

```
1. REMOVE old containers        → clean slate
2. CREATE private network       → appnet-staging / appnet-production
3. PULL images                  → from Docker Hub (or use local ones)
4. RUN backend container        → 8000 → 8001 (staging) / 8002 (production)
5. RUN frontend container       → 8501 (staging) / 8502 (production), API_URL wired
6. HEALTH-CHECK both tiers      → retries until HTTP 200 or timeout
```

**Idempotent** = run it twice, the second run reports `changed=0`.

### 11a. Install Ansible

```bash
./scripts/install_ansible.sh
# or manually:
brew install ansible                                  # macOS
sudo apt update && sudo apt install -y ansible        # Ubuntu/Debian
ansible-galaxy collection install community.docker
pip3 install docker
```

### 11b. The Inventory

[ansible/hosts](ansible/hosts) defines the targets:

```ini
[staging]
localhost ansible_connection=local

[production]
localhost ansible_connection=local
```

> Both point at `localhost` for this lesson. On real infrastructure you'd list server IPs — **the playbooks don't change at all**. That's the point of inventory.

### 11c. Deploy to Staging

```bash
./scripts/deploy.sh YOUR_DOCKERHUB_USERNAME staging
# or with locally built images (no Docker Hub needed):
./scripts/deploy.sh local staging
```

Verify:

```bash
docker ps --filter name=staging
curl http://localhost:8001/            # staging API
open http://localhost:8501             # staging UI
./scripts/check_staging.sh             # full health report
```

Also check http://localhost:9090/targets — `student-backend-staging` should now be **UP**. Your monitoring sees the new deployment.

### 11d. Promote to Production

The CI/CD concept of **promotion**: the *exact same images* that passed staging go to production.

```bash
# 1. Test staging
curl http://localhost:8001/stats

# 2. Promote — same playbook, same images, different target
./scripts/deploy.sh YOUR_DOCKERHUB_USERNAME production

# 3. Verify production
curl http://localhost:8002/stats
open http://localhost:8502
```

### 11e. From Jenkins

This is what the **Deploy via Ansible** stage does when you set `DEPLOY_TARGET=staging` (or `production`) — the Jenkins image already has Ansible + `community.docker` baked in:

```bash
ansible-playbook deploy_stack_playbook.yaml -e target=staging -e dh_user=YOURNAME
```

---

## ✅ Step 12 — The Complete End-to-End Run

You've now built every piece. Here's the whole loop, hands-off:

```
 1. CODE      edit backend/main.py — add an endpoint, tweak a message
 2. TEST      pytest backend/ -v                        (seconds, local)
 3. PUSH      git commit -am "feature" && git push
 4. CI        Jenkins auto-detects (≤2 min) and runs all 12 stages:
              lint → unit test → build → API test → scan → sonar →
              gate → push (Hub + Nexus) → smoke → ansible → STAGING
 5. VERIFY    curl localhost:8001 · Grafana dashboards · Sonar report
 6. PROMOTE   re-run with DEPLOY_TARGET=production      → PRODUCTION
 7. MONITOR   Prometheus scrapes staging + production every 15s
```

**Final check — everything running:**

```bash
docker ps
# backend, frontend                        → dev        :8000 / :8501
# jenkins                                  → CI         :8080
# sonarqube                                → quality    :9000
# nexus                                    → registry   :8081 / :8082
# prometheus, grafana, cadvisor            → monitoring :9090 / :3000 / :8085
# backend-staging, frontend-staging        → staging    :8001 / :8501
# backend-production, frontend-production  → production :8002 / :8502
```

### Key Concepts You Just Practiced

| Concept | Meaning | Where You Did It |
|---------|---------|------------------|
| **Containerization** | App + deps packaged into a portable image | Steps 1–2 |
| **Shift Left** | Test & scan at commit time, not after deploy | Steps 4–5 |
| **Configuration as Code** | Jenkins itself defined in versioned YAML | Step 8 (JCasC) |
| **Secrets Management** | Tokens live in `.env`, never in Git | Step 0 + 8 |
| **Pipeline as Code** | The whole workflow in one `Jenkinsfile` | Step 8 |
| **Artifact Repository** | Private registry you control (Nexus) | Step 7 |
| **Quality Gate** | Automated pass/fail before shipping | Step 8 |
| **API Testing** | Contract-level tests over real HTTP | Step 9 |
| **Observability** | Metrics, dashboards, targets | Step 10 |
| **Infrastructure as Code** | Environments in inventory + playbooks | Step 11 |
| **Idempotency** | Re-run safely → `changed=0` | Step 11 |
| **Promotion** | Same images flow staging → production | Step 11 |

---

## 🧰 Toolchain (All Open Source, with Links)

| Tool | Role | License | Link |
|------|------|---------|------|
| **FastAPI** | Backend web framework | MIT | https://fastapi.tiangolo.com |
| **Streamlit** | Frontend web framework | Apache 2.0 | https://streamlit.io |
| **Docker Engine / Compose** | Containers & local orchestration | Apache 2.0 | https://docs.docker.com |
| **Jenkins** | CI/CD automation server | MIT | https://www.jenkins.io |
| **Jenkins Configuration as Code** | Auto-configure Jenkins from YAML | MIT | https://plugins.jenkins.io/configuration-as-code/ |
| **Job DSL** | Auto-create Jenkins jobs from code | Apache 2.0 | https://plugins.jenkins.io/job-dsl/ |
| **Ansible** | Deployment automation (IaC) | GPL v3 | https://www.ansible.com |
| **SonarQube Community** | Code quality & static analysis | LGPL v3 | https://www.sonarsource.com/open-source-editions/sonarqube-community-edition/ |
| **Nexus Repository OSS** | Private artifact/Docker registry | EPL | https://www.sonatype.com/products/sonatype-nexus-oss |
| **Trivy** | Vulnerability & secret scanner | Apache 2.0 | https://trivy.dev |
| **OWASP Dependency-Check** | Dependency CVE scanner | Apache 2.0 | https://owasp.org/www-project-dependency-check/ |
| **Hadolint** | Dockerfile linter | GPL v3 | https://github.com/hadolint/hadolint |
| **Ruff** | Python linter + formatter | MIT | https://docs.astral.sh/ruff/ |
| **mypy** | Python type checker | MIT | https://mypy-lang.org |
| **Bandit** | Python security linter | Apache 2.0 | https://bandit.readthedocs.io |
| **pytest** | Unit test framework | MIT | https://pytest.org |
| **Newman** | Postman CLI for API tests | Apache 2.0 | https://github.com/postmanlabs/newman |
| **Prometheus** | Metrics collection & storage | Apache 2.0 | https://prometheus.io |
| **Grafana OSS** | Dashboards & visualization | AGPL v3 | https://grafana.com/oss/grafana/ |
| **cAdvisor** | Container resource metrics | Apache 2.0 | https://github.com/google/cadvisor |

### Port Map Reference

```
┌─────────────────────┬────────────┬──────────────────────────────┐
│  Service            │  Host Port │  URL                         │
├─────────────────────┼────────────┼──────────────────────────────┤
│ Backend (dev)       │  :8000     │  http://localhost:8000/docs  │
│ Frontend (dev)      │  :8501     │  http://localhost:8501       │
│ Jenkins             │  :8080     │  http://localhost:8080       │
│ SonarQube           │  :9000     │  http://localhost:9000       │
│ Nexus UI            │  :8081     │  http://localhost:8081       │
│ Nexus Docker reg.   │  :8082     │  docker login localhost:8082 │
│ Prometheus          │  :9090     │  http://localhost:9090       │
│ Grafana             │  :3000     │  http://localhost:3000       │
│ cAdvisor            │  :8085     │  http://localhost:8085       │
│ Staging API / UI    │  :8001/8501│  http://localhost:8001/docs  │
│ Production API / UI │  :8002/8502│  http://localhost:8002/docs  │
└─────────────────────┴────────────┴──────────────────────────────┘
```

---

## 🔧 Troubleshooting

### Docker Basics

| Symptom | Cause | Fix |
|---------|-------|-----|
| `docker: command not found` | Docker not installed | [Docker Desktop](https://docs.docker.com/get-docker/) |
| `Cannot connect to the Docker daemon` | Docker not running | Start Docker Desktop |
| `port is already allocated` | Something else on the port | `lsof -i :8501` → `kill -9 <PID>`, or change the port |

### Jenkins / JCasC

| Symptom | Cause | Fix |
|---------|-------|-----|
| Credentials missing in Jenkins | `.env` not filled in before boot | Fill `.env`, then `docker compose up -d --force-recreate jenkins` |
| `student-app-pipeline` job missing | `GIT_REPO_URL` empty / JCasC error | Set it in `.env`, recreate; check `docker logs jenkins` for `CasC` errors |
| Checkout stage fails (auth) | Bad/expired GitHub PAT | Regenerate PAT (repo **Contents: Read**), update `.env`, recreate Jenkins |
| Push stage fails (denied) | Docker Hub token lacks Write | Regenerate with **Read & Write** |
| `docker: not found` in a stage | Using stock Jenkins image | Use `docker compose up -d --build jenkins` (builds jenkins/Dockerfile) |
| SonarQube stage can't connect | scanner not on `cicd-net`, or server down | `docker compose up -d sonarqube`; network fix is already in the Jenkinsfile |

### Frontend Shows "Could Not Reach the API"

1. Backend running? → `docker ps | grep backend`
2. Same network? → `docker inspect frontend --format '{{json .NetworkSettings.Networks}}'`
3. Reachability test → `docker exec frontend curl -s http://backend:8000/`
4. `API_URL` must use the **container name** (`http://backend:8000`), never `localhost`

### Nexus

| Symptom | Fix |
|---------|-----|
| UI never loads | It's slow to boot — wait 2 min, `docker logs -f nexus` |
| `docker login localhost:8082` → 401 | Enable **Docker Bearer Token Realm** (Security → Realms) |
| Push → `connection refused` | The docker (hosted) repo's HTTP connector must be on port **8082** |

### Monitoring

| Symptom | Fix |
|---------|-----|
| Staging target DOWN in Prometheus | Expected until you deploy staging (Step 11) |
| cAdvisor shows little data on macOS | Docker Desktop runs in a VM — container-level metrics still work; host metrics are limited |
| Grafana has no datasource | Start via compose (provisioning is mounted): `docker compose --profile monitoring up -d` |

### Ansible

| Error | Fix |
|-------|-----|
| `community.docker` not found | `ansible-galaxy collection install community.docker` |
| `Failed to import docker` | `pip3 install docker` |
| `container already in use` | `./scripts/setup_environments.sh` |
| Anything unclear | add `-vv` to the `ansible-playbook` command |

### Clean Up Everything

```bash
./scripts/setup_environments.sh                    # demo containers + networks
docker compose --profile nexus --profile monitoring down -v   # whole lab + volumes
docker system prune -f                             # dangling images etc.
```

---

## 📚 Learn More

| Resource | What It Covers |
|----------|---------------|
| 📄 [docs/JENKINS_PIPELINE.md](docs/JENKINS_PIPELINE.md) | Manual Jenkins setup from scratch (what JCasC automated for you) |
| 📄 [docs/ANSIBLE_DEPLOY.md](docs/ANSIBLE_DEPLOY.md) | Deep dive into Ansible concepts and patterns |
| 📄 [Jenkinsfile](Jenkinsfile) | The complete 12-stage pipeline definition |
| 📄 [jenkins/casc/jenkins.yaml](jenkins/casc/jenkins.yaml) | How JCasC imports credentials & creates the job |
| 🛠️ `./scripts/scan.sh --list` | All available scanning checks |
| 📄 [pyproject.toml](pyproject.toml) | Python linting configuration |

---

> 💡 **Suggested path:** Step 0 → 1 to see the app running in a minute. Steps 2–4 to understand containers and tests. Steps 5–7 to set up quality gates and registries. Step 8 for the fully automated pipeline. Steps 9–11 for API tests, monitoring, and deployment. Step 12 to run the whole loop end to end — then celebrate 🎉
