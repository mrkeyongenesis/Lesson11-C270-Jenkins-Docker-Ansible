# 🎓 Student App — End-to-End CI/CD Guide

A complete, hands-on guide to building, testing, scanning, deploying, and automating a **two-tier web application** (FastAPI + Streamlit) using **Docker**, **Ansible**, **Jenkins**, and **open-source security tools**.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        WHAT YOU'LL BUILD                                │
│                                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  FastAPI  │    │ Streamlit│    │   Staging    │    │  Production   │  │
│  │  Backend  │◄───│ Frontend │───▶│ localhost:   │    │  localhost:   │  │
│  │  :8000    │    │  :8501   │    │ 8501 / 8001  │    │ 8502 / 8002   │  │
│  └──────────┘    └──────────┘    └──────────────┘    └──────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  CI/CD PIPELINE (Jenkins)                                        │   │
│  │  Code → Lint → Build → Test → Security Scan → Push → Deploy     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Table of Contents

- [🏗 Architecture Overview](#-architecture-overview)
- [✅ Prerequisites](#-prerequisites)
- [📁 Project Structure](#-project-structure)
- [🚀 Step 1 — Run with Docker Compose (30 seconds)](#-step-1--run-with-docker-compose-30-seconds)
- [🔧 Step 2 — Run Manually (Understand Every Piece)](#-step-2--run-manually-understand-every-piece)
- [🌐 Step 3 — Explore the Backend API](#-step-3--explore-the-backend-api)
- [🔍 Step 4 — Code Quality & Security Scanning](#-step-4--code-quality--security-scanning)
- [📦 Step 5 — Build & Push to Docker Hub](#-step-5--build--push-to-docker-hub)
- [🤖 Step 6 — Deploy with Ansible (Staging → Production)](#-step-6--deploy-with-ansible-staging--production)
- [🔄 Step 7 — CI/CD with Jenkins (Full Automation)](#-step-7--cicd-with-jenkins-full-automation)
- [✅ Step 8 — Verify & Monitor Everything](#-step-8--verify--monitor-everything)
- [🧩 How Everything Fits Together](#-how-everything-fits-together)
- [🔧 Troubleshooting](#-troubleshooting)

---

## 🏗 Architecture Overview

### The Application

This is a **two-tier web application** — a backend API and a frontend UI that talks to it:

| Tier | Technology | What It Does | Port |
|------|-----------|-------------|------|
| **Backend** | FastAPI (Python) | REST API — manage student records (CRUD) | `:8000` |
| **Frontend** | Streamlit (Python) | Web UI that calls the backend API | `:8501` |
| **Database** | In-memory (Python list) | Stores student data (resets on restart) | — |

### How the Tiers Connect

```
  You (Browser)
       │
       ▼  http://localhost:8501
  ┌──────────────────────┐
  │  Streamlit Frontend  │  (app.py)
  │  Port :8501           │
  └─────────┬────────────┘
       │  HTTP GET /students
       │  HTTP POST /students
       ▼  http://backend:8000
  ┌──────────────────────┐
  │  FastAPI Backend     │  (main.py)
  │  Port :8000           │
  └─────────┬────────────┘
       │
       ▼  In-memory Python list
  ┌──────────────────────┐
  │  Student Database     │
  │  5 students (Alice,   │
  │  Bob, Charlie, ...)   │
  └──────────────────────┘
```

### The Three Environments

| Environment | UI Port | API Port | What It's For |
|-------------|---------|----------|--------------|
| **Local dev** | `:8501` | `:8000` | Quick testing on your machine |
| **Staging** | `:8501` | `:8001` | Pre-production validation |
| **Production** | `:8502` | `:8002` | Live app (simulated locally) |

### The CI/CD Pipeline (Full Flow)

```
                    ┌──────────────────────┐
   Git Push ───────▶│   JENKINS PIPELINE    │
                    └──────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
   ┌──────────┐      ┌──────────┐      ┌──────────┐
   │   CODE   │      │   BUILD  │      │   TEST   │
   │ Quality  │      │  Images  │      │ Backend  │
   │ & Lint   │      │ (Docker) │      │   API    │
   │ ──────── │      └──────────┘      └──────────┘
   │ Hadolint │            │                  │
   │ Ruff     │            ▼                  │
   │ mypy     │      ┌──────────┐             │
   │ Bandit   │      │ Security │◄────────────┘
   └──────────┘      │  Scan    │
        │            │ ──────── │
        ▼            │ Trivy    │
   ┌──────────┐      │ OWASP DC │
   │ SonarQube│      └──────────┘
   │ Analysis │            │
   └──────────┘            ▼
        │            ┌──────────┐
        ▼            │ Quality  │
   ┌──────────┐      │  Gate    │
   │  PUSH to │◄─────┤ (pass/   │
   │Docker Hub│      │  fail)   │
   └──────────┘      └──────────┘
        │
        ▼
   ┌──────────┐      ┌────────────┐
   │  Deploy  │─────▶│  Staging   │
   │ (Ansible)│      └────────────┘
   └──────────┘            │
                           ▼
                    ┌────────────┐
                    │ Production │
                    └────────────┘
```

---

## ✅ Prerequisites

| Tool | Why You Need It | Check Installed | Install If Missing |
|------|----------------|----------------|-------------------|
| **Docker** | Run containers locally | `docker version && docker ps` | [Docker Desktop](https://docs.docker.com/get-docker/) |
| **Git** | Clone repo & version control | `git --version` | `brew install git` or [git-scm.com](https://git-scm.com/) |
| **Python 3** | Run linting tools locally | `python3 --version` | `brew install python3` |
| **Curl** | Test API endpoints | `curl --version` | Built into macOS / `sudo apt install curl` |

**First step — verify Docker is ready:**

```bash
docker version
docker ps
```

> Both commands must complete without errors. If `docker ps` fails, open Docker Desktop and wait for it to show **"Running"**.

---

## 📁 Project Structure

After cloning, here's everything you get:

```
Lesson11-C270-Jenkins-Docker-Ansible/
│
├── 📄 Jenkinsfile                 # 🔄 CI/CD pipeline (10 stages)
├── 📄 docker-compose.yml          # 🐳 One-command local setup
├── 📄 pyproject.toml              # 🐍 Python tool config (Ruff, mypy)
├── 📄 sonar-project.properties    # 📊 SonarQube config
├── 📄 .hadolint.yaml              # 🐳 Dockerfile linter config
├── 📄 .trivyignore                # 🛡️ Vulnerability ignore rules
├── 📄 .env.example                # 🔑 Environment variable template
│
├── 📁 backend/                    # 🖥️ FASTAPI BACKEND
│   ├── main.py                    #    6 REST endpoints (CRUD + search + stats)
│   ├── requirements.txt           #    fastapi, uvicorn, pydantic
│   └── Dockerfile                 #    python:3.11-slim image
│
├── 📁 frontend/                   # 🎨 STREAMLIT FRONTEND
│   ├── app.py                     #    8 interactive pages
│   ├── requirements.txt           #    streamlit, requests, pandas
│   └── Dockerfile                 #    python:3.11-slim image
│
├── 📁 ansible/                    # 🤖 ANSIBLE AUTOMATION
│   ├── ansible.cfg                #    Config (disable host key checking)
│   ├── hosts                      #    Inventory (staging + production groups)
│   ├── setup_basics_playbook.yaml #    Prepare target hosts
│   ├── deploy_stack_playbook.yaml #    Deploy both containers with networking
│   └── target-image/              #    Simulated remote server (SSH + Docker)
│       └── Dockerfile
│
├── 📁 scripts/                    # 🛠️ HELPER SCRIPTS
│   ├── scan.sh                    #    🔍 Run ALL security & lint checks
│   ├── test_local.sh              #    🧪 Build + run + test locally
│   ├── build_and_push.sh          #    📦 Build & push to Docker Hub
│   ├── deploy.sh                  #    🚀 Deploy with Ansible (one command)
│   ├── check_staging.sh           #    🔎 Inspect staging deployment
│   ├── setup_environments.sh      #    🧹 Clean up before deploying
│   └── install_ansible.sh         #    📥 Install Ansible on any OS
│
├── 📁 jenkins-app/                # 📚 Simple Flask app (for learning Jenkins basics)
│
└── 📁 docs/                       # 📖 Detailed reference guides
    ├── JENKINS_PIPELINE.md
    └── ANSIBLE_DEPLOY.md
```

---

## 🚀 Step 1 — Run with Docker Compose (30 seconds)

This is the fastest way to see the app working. Docker Compose starts **everything** with one command.

```bash
docker compose up --build
```

### What Starts

| Service | What It Is | URL |
|---------|-----------|-----|
| `backend` | FastAPI (students API) | http://localhost:8000/docs |
| `frontend` | Streamlit (web UI) | http://localhost:8501 |
| `jenkins` | CI/CD automation server | http://localhost:8080 |
| `sonarqube` | Code quality analysis | http://localhost:9000 |

### Your First Interaction

1. **Open** http://localhost:8501 — you should see the **Student API Explorer**
2. **Click** `"🏠 Home — Health Check"` → Click **"🚀 Send Request"**
   - You should see: `{"message": "🎓 Student API is running!", "status": "OK"}`
3. **Click** `"📋 GET — All Students"` → Click **"🚀 Send Request"**
   - You should see 5 students: Alice, Bob, Charlie, Diana, Eve
4. **Click** `"📊 GET — Stats"` → Click **"🚀 Send Request"**
   - You should see: average grade 79.8, highest 95, lowest 61
5. **Open** http://localhost:8000/docs — FastAPI's auto-generated documentation
   - Click any endpoint → **"Try it out"** → **"Execute"**

### Screenshot of What You Should See

```
┌─────────────────────────────────────────────────────────────────┐
│  🎓 Student API Explorer                                        │
│  ───────────────────────────────────────────────                │
│                                                                 │
│  ┌─────────────┐   ┌────────────────────────────────────────┐  │
│  │ 🏠 Home     │   │  📋 All Students                       │  │
│  │ 📋 All Std. │   │  ──────────────────────────             │  │
│  │ 🔍 One Std. │   │  GET /students                          │  │
│  │ 🔎 Search   │   │                                        │  │
│  │ 📊 Stats    │   │  [🚀 Send Request]                      │  │
│  │ ➕ POST     │   │                                        │  │
│  │ ✏️ PUT      │   │  Response: Status 200                   │  │
│  │ 🗑️ DELETE   │   │  {"total":5,"students":[               │  │
│  └─────────────┘   │    {"id":1,"name":"Alice",...},         │  │
│                    │    {"id":2,"name":"Bob",...},            │  │
│                    │    ...                                   │  │
│                    │  ]}                                      │  │
│                    └────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### When You're Done

```bash
# Stop everything (preserves data)
docker compose down

# Stop AND delete volumes (completely fresh start next time)
docker compose down -v
```

---

## 🔧 Step 2 — Run Manually (Understand Every Piece)

Running manually teaches you **exactly** what each Docker command does — no magic.

### 2a. Clean Up

```bash
./scripts/setup_environments.sh
```

This removes old containers and networks so you start clean.

### 2b. Build the Docker Images

```bash
# Build backend image
docker build -t student-backend:latest ./backend

# Build frontend image
docker build -t student-frontend:latest ./frontend
```

**What the Dockerfile does (step by step):**

```dockerfile
FROM python:3.11-slim          # 1. Start with minimal Python
WORKDIR /app                    # 2. Set working directory
COPY requirements.txt .         # 3. Copy dependency list
RUN pip install -r requirements.txt  # 4. Install packages
COPY main.py .                  # 5. Copy app code
EXPOSE 8000                     # 6. Document the port
CMD ["uvicorn", "main:app", ...] # 7. Set startup command
```

### 2c. Create a Network

Containers need a private network to talk to each other:

```bash
docker network create appnet
```

### 2d. Start the Backend

```bash
docker run -d \
  --name backend \
  --network appnet \
  -p 8000:8000 \
  student-backend:latest
```

**Flag by flag:**
| Flag | Meaning | Why |
|------|---------|-----|
| `-d` | Detached (background) | So your terminal is free |
| `--name backend` | Give it a name | Frontend finds it by name |
| `--network appnet` | Attach to network | Can talk to frontend |
| `-p 8000:8000` | Port mapping | host:container |

### 2e. Verify the Backend

```bash
# Health check
curl http://localhost:8000/
# → {"message":"🎓 Student API is running!","status":"OK"}

# List students
curl http://localhost:8000/students
# → {"total":5,"students":[{"id":1,"name":"Alice",...}, ...]}

# Get statistics
curl http://localhost:8000/stats
# → {"total_students":5,"average_grade":79.8,"highest_grade":95,"lowest_grade":61}
```

### 2f. Start the Frontend

```bash
docker run -d \
  --name frontend \
  --network appnet \
  -e API_URL=http://backend:8000 \
  -p 8501:8501 \
  student-frontend:latest
```

**Critical detail:** The `API_URL=http://backend:8000` tells the frontend where to find the backend. Since both are on `appnet`, they communicate by **container name** (`backend`), not `localhost`. This is called **container networking**.

### 2g. Open the App

Open **http://localhost:8501** in your browser. You should see the full Student API Explorer.

### 2h. Clean Up

```bash
docker rm -f backend frontend
docker network rm appnet
```

---

## 🌐 Step 3 — Explore the Backend API

The backend has **6 REST endpoints** covering all CRUD operations plus search and stats.

### All Endpoints

| Method | Endpoint | What It Does | Try This Command |
|--------|----------|-------------|-----------------|
| `GET` | `/` | Health check | `curl localhost:8000/` |
| `GET` | `/students` | List all students | `curl localhost:8000/students` |
| `GET` | `/students/{id}` | Get one student | `curl localhost:8000/students/1` |
| `POST` | `/students` | Add a student | *(see below)* |
| `PUT` | `/students/{id}` | Update a student | *(see below)* |
| `DELETE` | `/students/{id}` | Delete a student | *(see below)* |
| `GET` | `/search?subject=Math` | Filter by subject | `curl "localhost:8000/search?subject=Math"` |
| `GET` | `/stats` | Class statistics | `curl localhost:8000/stats` |

### Hands-On Exercises

**1. Add a new student (POST):**

```bash
curl -X POST http://localhost:8000/students \
  -H "Content-Type: application/json" \
  -d '{"name":"Grace","grade":91,"subject":"Math"}'
# → {"message":"Student created!","student":{"id":6,"name":"Grace",...}}
```

**2. Update a student's grade (PUT):**

```bash
curl -X PUT http://localhost:8000/students/1 \
  -H "Content-Type: application/json" \
  -d '{"grade":97}'
# → {"message":"Student updated!","student":{"id":1,"name":"Alice","grade":97,...}}
```

**3. Delete a student (DELETE):**

```bash
curl -X DELETE http://localhost:8000/students/3
# → {"message":"Student 'Charlie' deleted!"}
```

**4. Search by subject:**

```bash
curl "http://localhost:8000/search?subject=Science"
# → {"subject":"Science","count":2,"students":[...]}
```

**5. Check updated stats:**

```bash
curl http://localhost:8000/stats
```

> **Pro tip:** Open http://localhost:8000/docs for an interactive UI where you can click to try every endpoint.

### HTTP Methods Cheat Sheet

| Method | Purpose | Example |
|--------|---------|---------|
| `GET` | Read data (safe) | `GET /students` — list all |
| `POST` | Create new data | `POST /students` — add a student |
| `PUT` | Update existing data | `PUT /students/1` — change grade |
| `DELETE` | Remove data | `DELETE /students/3` — remove Charlie |

---

## 🔍 Step 4 — Code Quality & Security Scanning

Before shipping code, run automated checks to catch bugs, security issues, and style problems.

### 4a. Install Scanner Tools

```bash
# macOS
brew install hadolint trivy
pip3 install ruff mypy bandit

# Linux (Ubuntu/Debian)
sudo apt update
pip3 install ruff mypy bandit
# Trivy: https://trivy.dev/latest/getting-started/installation/
# Hadolint: https://github.com/hadolint/hadolint/releases
```

### 4b. Run ALL Checks (One Command)

```bash
./scripts/scan.sh
```

This runs **9 checks** automatically:

| # | Tool | Type | What It Catches |
|---|------|------|----------------|
| 1 | **Hadolint** | Dockerfile lint | Unsafe Docker patterns, missing labels |
| 2 | **Bandit** | Python security | Hardcoded passwords, SQL injection, eval() |
| 3 | **Ruff** (lint) | Python lint | Syntax errors, unused imports, naming violations |
| 4 | **Ruff** (format) | Python style | Inconsistent formatting (Black-compatible) |
| 5 | **mypy** | Type check | Wrong argument types, missing returns |
| 6 | **Trivy** (filesystem) | Vulnerability | CVEs in Python deps and source code |
| 7 | **Trivy** (images) | Vulnerability | CVEs in Docker images (requires built images) |
| 8 | **OWASP DC** | Dependency check | Known vulnerabilities in requirements.txt |
| 9 | **SonarQube** | Code quality | Code smells, bugs, duplications (requires server) |

### 4c. Interpret the Results

**What a passing check looks like:**
```
✅ ruff lint: no issues
✅ mypy: no type errors
```

**What a failing check looks like:**
```
❌ ruff lint: issues found (run 'ruff check --fix' to auto-fix)

backend/main.py:78:80: E501 Line too long (82 > 79 characters)
```

### 4d. Run Specific Checks

```bash
# Just Python linting
./scripts/scan.sh ruff-lint ruff-format mypy bandit

# Just Docker
./scripts/scan.sh hadolint

# Quick scan (skip image scanning)
./scripts/scan.sh --quick

# List everything
./scripts/scan.sh --list
```

### 4e. Auto-Fix Issues

```bash
# Ruff can auto-fix most problems
ruff check --fix backend/ frontend/
ruff format backend/ frontend/
```

### 4f. Run SonarQube (Full Static Analysis)

```bash
# 1. Start SonarQube
docker compose up -d sonarqube

# 2. Open http://localhost:9000 (login: admin / admin)

# 3. Generate a token: User → My Account → Security → Generate Token

# 4. Run the scan
SONAR_TOKEN=your_token_here ./scripts/scan.sh sonar
```

---

## 📦 Step 5 — Build & Push to Docker Hub

So far you've only run images locally. To deploy with Ansible or Jenkins, push them to Docker Hub.

### 5a. Create a Docker Hub Account

1. Go to https://hub.docker.com
2. Sign up (free)
3. Go to **Account Settings → Security → New Access Token**
4. Create a token with **Read & Write** permissions
5. **Copy the token** (Docker Hub won't show it again)

### 5b. Log In and Push

```bash
# Using the helper script (recommended)
./scripts/build_and_push.sh YOUR_DOCKERHUB_USERNAME
# It will prompt for your access token (paste it)

# Or manually:
docker login -u YOUR_DOCKERHUB_USERNAME
# (paste your access token)

docker build -t YOUR_DOCKERHUB_USERNAME/student-backend:latest ./backend
docker build -t YOUR_DOCKERHUB_USERNAME/student-frontend:latest ./frontend

docker push YOUR_DOCKERHUB_USERNAME/student-backend:latest
docker push YOUR_DOCKERHUB_USERNAME/student-frontend:latest
```

### 5c. Verify

Open https://hub.docker.com/u/YOUR_DOCKERHUB_USERNAME — you should see:

```
Repositories (2)
├── YOUR_DOCKERHUB_USERNAME/student-backend   ✅ Pushed
└── YOUR_DOCKERHUB_USERNAME/student-frontend  ✅ Pushed
```

### Copy Your Docker Hub Username

You'll need it for the next steps. Save it somewhere:

```
DOCKER_HUB_USERNAME=___________
```

---

## 🤖 Step 6 — Deploy with Ansible (Staging → Production)

Ansible automates deployments so they're **repeatable** and **identical** every time.

### What is Ansible Doing?

When you run the deploy command, Ansible connects to the target machine and:

```
1. REMOVE old containers        → clean slate
2. CREATE private network       → appnet-staging
3. PULL backend image           → from Docker Hub (or use local)
4. RUN backend container        → port 8000 → 8001 (staging)
5. PULL frontend image          → from Docker Hub (or use local)
6. RUN frontend container       → port 8501, with API_URL set
7. VERIFY internal IPs          → inspect with docker inspect
```

Everything is **idempotent** — run it twice and the second time says `changed=0` (nothing to change).

### 6a. Install Ansible

```bash
# macOS
brew install ansible

# Ubuntu/Debian
sudo apt update && sudo apt install -y ansible

# Verify
ansible --version

# Install Docker modules
ansible-galaxy collection install community.docker
pip3 install docker
```

Or use the included script:

```bash
./scripts/install_ansible.sh
```

### 6b. Understand the Inventory

The file `ansible/hosts` defines your target machines:

```ini
[staging]
localhost ansible_connection=local

[production]
localhost ansible_connection=local

[staging:vars]
ui_port=8501
api_port=8001

[production:vars]
ui_port=8502
api_port=8002
```

> Both environments point to `localhost` for this demo. In a real setup, these would be IPs of remote servers. Ansible's playbooks work the same either way.

### 6c. Deploy to Staging (Local Images)

```bash
./scripts/deploy.sh local staging
```

This one command:
1. Cleans up old containers
2. Builds images if they don't exist
3. Runs the Ansible playbook targeting `staging`
4. Creates `appnet-staging` network
5. Starts `backend-staging` (port 8001) and `frontend-staging` (port 8501)

### 6d. Deploy to Production (Docker Hub Images)

```bash
./scripts/deploy.sh YOUR_DOCKERHUB_USERNAME production
```

### 6e. Verify the Deployment

```bash
# Check containers are running
docker ps --filter name=staging
docker ps --filter name=production

# Test staging API
curl http://localhost:8001/

# Test production API
curl http://localhost:8002/

# Check logs
docker logs backend-staging --tail 20
docker logs frontend-staging --tail 20
```

### 6f. Open in Your Browser

| Environment | UI | API Docs |
|-------------|-----|---------|
| **Staging** | http://localhost:8501 | http://localhost:8001/docs |
| **Production** | http://localhost:8502 | http://localhost:8002/docs |

### 6g. Promote from Staging to Production

This is the CI/CD concept of **promotion** — the exact same images flow through environments:

```bash
# Step 1: Deploy to staging
./scripts/deploy.sh YOUR_USERNAME staging

# Step 2: Test staging (curl, browser, etc.)
curl http://localhost:8001/stats

# Step 3: Deploy SAME images to production
./scripts/deploy.sh YOUR_USERNAME production

# Step 4: Verify production
curl http://localhost:8002/stats
```

No copy-paste. No environment-specific scripts. The same playbook, same images, different target.

### 6h. Run the Complete Check Script

```bash
./scripts/check_staging.sh
```

This runs: container status → process list → logs → host checks → network checks → HTTP responses.

---

## 🔄 Step 7 — CI/CD with Jenkins (Full Automation)

Now automate the **entire pipeline**: every code change triggers build → test → scan → push → deploy automatically.

### 7a. Start Jenkins

```bash
docker compose up -d jenkins
```

Open **http://localhost:8080** and unlock:

```bash
docker logs jenkins | grep -i "password"
# → Please use the following password to proceed to installation: a1b2c3d4e5...
```

1. Paste the password → **Install suggested plugins** (wait 2-3 minutes)
2. Create admin user (e.g., `admin` / `admin`)

### 7b. Configure Jenkins (One-Time)

**1. Install Docker Pipeline plugin:**
- Manage Jenkins → Plugins → Available plugins
- Search **"Docker Pipeline"** → Install

**2. Add Docker Hub credentials:**
- Manage Jenkins → Credentials → System → Global → Add Credentials
- Kind: **Username with password**
- ID: `dockerhub` (must match what the Jenkinsfile expects)
- Username: your Docker Hub username
- Password: your Docker Hub **access token** (not your login password)

**3. Add SonarQube token (optional):**
- Same process, ID: `sonar-token`, Kind: **Secret text**

### 7c. Create the Pipeline Job

1. Click **New Item**
2. Name: `student-app-pipeline`
3. Select **Pipeline**
4. Scroll to **Pipeline** section
5. Definition: **Pipeline script from SCM**
6. SCM: **Git**
7. Repository URL: your repo URL
8. Script Path: `Jenkinsfile`
9. Click **Save**

### 7d. Run the Pipeline

1. Click **Build with Parameters**
2. Set these values:

| Parameter | Your Value |
|-----------|-----------|
| `DOCKER_USER` | Your Docker Hub username |
| `DEPLOY_TARGET` | `staging` (or `none` to skip deploy) |
| `SKIP_SONAR` | ✅ checked (unless SonarQube is running) |
| `SKIP_SECURITY_SCAN` | ⬜ unchecked |

3. Click **Build**

### 7e. Watch the Pipeline Execute

Each stage shows a colored status:

```
 ✅ Checkout           → Pulls latest code from GitHub
 ✅ Code Quality       → Hadolint, Ruff, mypy, Bandit run in parallel
 ✅ Build Images       → Backend + Frontend build in parallel
 ✅ Test Backend       → Smoke tests the API
 ✅ Security Scan      → Trivy + OWASP scan source + images
 ⏭️ SonarQube          → Skipped (SKIP_SONAR was checked)
 ✅ Quality Gate       → Checks vulnerability thresholds
 ✅ Push to Docker Hub → Pushes :latest and :build-number tags
 ✅ Deploy (smoke)     → Local docker run test
 ✅ Deploy via Ansible → Deploys to staging/production
```

### 7f. Configure Automatic Triggers

The Jenkinsfile already polls GitHub every 2 minutes (`pollSCM('H/2 * * * *')`). Any new commit automatically starts a build.

**For instant triggers (recommended):**

1. GitHub repo → **Settings** → **Webhooks** → **Add webhook**
2. Payload URL: `http://YOUR_IP:8080/github-webhook/`
3. Content type: `application/json`
4. Events: **Just the push event**
5. In Jenkins job → **Configure** → **Build Triggers** → Check **"GitHub hook trigger for GITScm polling"**

### 7g. Pipeline Parameters Reference

| Parameter | Options | Default | When To Change |
|-----------|---------|---------|---------------|
| `DOCKER_USER` | Your Docker Hub username | (placeholder) | Every build — set to your username |
| `DEPLOY_TARGET` | `none`, `staging`, `production` | `none` | Set `staging` when ready to deploy |
| `SKIP_SONAR` | `true`, `false` | `false` | Check if SonarQube not running |
| `SKIP_SECURITY_SCAN` | `true`, `false` | `false` | Check for quick dev builds |

### 7h. What Happens When You Change Code

```
1. You edit backend/main.py (add a new endpoint)
2. git add . && git commit -m "Add new endpoint"
3. git push origin main
4. Jenkins detects the change (≤2 min via poll, instantly via webhook)
5. Pipeline runs: lint → build → test → scan → quality gate → push → deploy
6. Your new endpoint is live on staging in ~3-5 minutes
7. After verification, trigger a production deploy
```

---

## ✅ Step 8 — Verify & Monitor Everything

### 8a. Quick Health Check

```bash
# Are all containers running?
docker ps

# You should see:
# CONTAINER ID   NAMES                PORTS
# abc123         backend-staging      0.0.0.0:8001->8000/tcp
# def456         frontend-staging     0.0.0.0:8501->8501/tcp
# ghi789         backend-production   0.0.0.0:8002->8000/tcp
# jkl012         frontend-production  0.0.0.0:8502->8501/tcp
```

### 8b. Test All Endpoints

```bash
# Staging
curl -s http://localhost:8001/ | python3 -m json.tool
curl -s http://localhost:8001/students | python3 -m json.tool

# Production
curl -s http://localhost:8002/ | python3 -m json.tool
curl -s http://localhost:8002/stats | python3 -m json.tool
```

### 8c. Check Logs

```bash
# See recent logs
docker logs backend-staging --tail 50
docker logs frontend-staging --tail 50

# Follow logs in real-time (Ctrl+C to stop)
docker logs -f backend-production
```

### 8d. Inspect a Running Container

```bash
# Enter the container (like SSH)
docker exec -it backend-staging /bin/bash

# Inside you can:
ls -la /app              # See the app files
env | grep -i api        # Check environment variables
cat /app/main.py         # Read the source code
exit                     # Leave the container
```

### 8e. Port Mapping Reference

```
┌─────────────────┬────────────┬────────────┬──────────────────────────────┐
│  Service        │  Container │  Host      │  URL                         │
├─────────────────┼────────────┼────────────┼──────────────────────────────┤
│ Backend (dev)   │  :8000     │  :8000     │  http://localhost:8000/docs   │
│ Frontend (dev)  │  :8501     │  :8501     │  http://localhost:8501        │
│ Jenkins         │  :8080     │  :8080     │  http://localhost:8080        │
│ SonarQube       │  :9000     │  :9000     │  http://localhost:9000        │
│ Staging API     │  :8000     │  :8001     │  http://localhost:8001/docs   │
│ Staging UI      │  :8501     │  :8501     │  http://localhost:8501        │
│ Production API  │  :8000     │  :8002     │  http://localhost:8002/docs   │
│ Production UI   │  :8501     │  :8502     │  http://localhost:8502        │
└─────────────────┴────────────┴────────────┴──────────────────────────────┘
```

### 8f. Run the Health Check Script

```bash
./scripts/check_staging.sh
```

This comprehensive script checks: container status → process health → recent logs → network connectivity → HTTP responses.

---

## 🧩 How Everything Fits Together

### The Full Software Lifecycle

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                    THE FULL LIFECYCLE (8 Steps)                         │
 └─────────────────────────────────────────────────────────────────────────┘

 1. CODE          You write Python in backend/main.py or frontend/app.py
    │
    ▼
 2. LINT & SCAN   ./scripts/scan.sh
    │              Ruff checks syntax. mypy checks types. Bandit checks
    │              security. Hadolint checks Dockerfiles. Fix any issues.
    ▼
 3. BUILD         docker build -t student-backend:latest ./backend
    │              docker build -t student-frontend:latest ./frontend
    ▼
 4. TEST          curl http://localhost:8000/   (smoke test)
    │              curl http://localhost:8000/students
    ▼
 5. SHIP          ./scripts/build_and_push.sh YOUR_USERNAME
    │              Push images to Docker Hub
    ▼
 6. DEPLOY        ./scripts/deploy.sh YOUR_USERNAME staging
    │              Ansible pulls images and starts containers
    ▼
 7. VERIFY        curl http://localhost:8501/   (open browser)
    │              docker logs backend-staging
    ▼
 8. PROMOTE       ./scripts/deploy.sh YOUR_USERNAME production
                  Same images, same playbook, different target
```

### With Jenkins Automation

Steps 2-8 happen **automatically** on every code change:

```
Git Push → Jenkins detects → runs pipeline → deploys to staging
                                                           │
                                    You verify staging ───┘
                                                           │
                                    Trigger production ────┘
```

### Key Concepts Summary

| Concept | Meaning | Real-World Example |
|---------|---------|-------------------|
| **Containerization** | Package app + dependencies into a portable image | "It works on my machine" → it works everywhere |
| **Two-Tier Architecture** | Separate backend (API) from frontend (UI) | Update UI without changing API, or vice versa |
| **CI/CD** | Automatically build, test, and deploy on every code change | Catch bugs in staging before they reach production |
| **Shift Left** | Run security scans early in the pipeline | Fix a vulnerability at commit time, not after deploy |
| **Quality Gate** | Automated pass/fail check before deployment | Pipeline stops if Trivy finds critical CVEs |
| **Idempotency** | Running the same script repeatedly gives the same result | Re-run Ansible safely — `changed=0` on second run |
| **Promotion** | Same artifacts flow through dev → staging → production | What you tested in staging is exactly what runs in prod |
| **Infrastructure as Code** | Environments defined in YAML/playbooks | `ansible/hosts` + `deploy_stack_playbook.yaml` |

### Tools Used in This Project

```
┌──────────────────────────────────────────────────────────────────────┐
│                          TOOLCHAIN SUMMARY                           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  🐳 Docker          ─  Container runtime + image building             │
│  🐳 Docker Compose  ─  One-command local environment                  │
│  🐳 Docker Hub      ─  Container image registry                      │
│                                                                      │
│  🤖 Ansible         ─  Automation: deploy containers to environments  │
│                                                                      │
│  🔄 Jenkins         ─  CI/CD: automate the entire pipeline           │
│                                                                      │
│  🔍 SonarQube       ─  Code quality analysis (LGPL v3)               │
│  🛡️ Trivy           ─  Vulnerability scanner (Apache 2.0)            │
│  🐳 Hadolint        ─  Dockerfile linter (GPL v3)                    │
│  🐍 Ruff            ─  Python linter + formatter (MIT)               │
│  🐍 mypy            ─  Python type checker (MIT)                     │
│  🐍 Bandit          ─  Python security linter (Apache 2.0)           │
│  📦 OWASP DC        ─  Dependency vulnerability checker (Apache 2.0) │
│                                                                      │
│  🐍 FastAPI         ─  Python web framework (backend)                │
│  🎨 Streamlit       ─  Python web framework (frontend)               │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Troubleshooting

### Docker Won't Start

| Symptom | Cause | Fix |
|---------|-------|-----|
| `docker: command not found` | Docker not installed | Install [Docker Desktop](https://docs.docker.com/get-docker/) |
| `Cannot connect to the Docker daemon` | Docker not running | Start Docker Desktop |
| `docker: 'compose' is not a docker command` | Old Docker version | Upgrade Docker or use `docker-compose` (with hyphen) |

### Port Already in Use

```bash
Error: driver failed programming external connectivity on endpoint
       (port is already allocated)
```

**Fix:** Find and stop whatever is using the port:

```bash
lsof -i :8501        # Find process on port 8501
kill -9 <PID>        # Kill it
# Or use a different port by editing docker-compose.yml
```

### Frontend Shows "Could Not Reach the API"

```
❌ Could not reach the API. Is the backend running?
```

**Most common causes:**
1. Backend container not running → `docker ps` — restart it
2. Wrong `API_URL` → Check the environment variable: `docker inspect frontend`
3. Containers on different networks → Both must be on the same `appnet`

**Debug step by step:**
```bash
# 1. Is the backend running?
docker ps | grep backend

# 2. Can the frontend reach the backend?
docker exec frontend curl -s http://backend:8000/ 2>/dev/null || echo "Cannot reach backend"

# 3. What network are they on?
docker inspect backend --format '{{json .NetworkSettings.Networks}}'
docker inspect frontend --format '{{json .NetworkSettings.Networks}}'
```

### Container Exits Immediately

```bash
docker logs backend-staging
# → uvicorn error: [Errno 98] Address already in use
```

**Fix:** Another process is using port 8000. Stop it or use a different port.

### Ansible Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `community.docker` not found | Collection not installed | `ansible-galaxy collection install community.docker` |
| `Failed to import docker` | Python SDK missing | `pip3 install docker` |
| `container already in use` | Old container exists | `docker rm -f <name>` or `./scripts/setup_environments.sh` |

### Jenkins Pipeline Failures

| Stage Fails | Likely Cause | Fix |
|-------------|-------------|-----|
| **Push to Docker Hub** | No credentials in Jenkins | Add `dockerhub` credential (Username with password) |
| **SonarQube** | Server not running | Start SonarQube or check `SKIP_SONAR` parameter |
| **Quality Gate** | Too many vulnerabilities | Check Trivy reports, fix HIGH/CRITICAL issues |
| **Deploy via Ansible** | Ansible not installed | Install Ansible on the Jenkins agent |

### Clean Up Everything

```bash
# Remove demo containers and networks
./scripts/setup_environments.sh

# Remove ALL containers (use with caution)
docker rm -f $(docker ps -aq) 2>/dev/null || true

# Remove compose services + volumes
docker compose down -v

# Clean up unused Docker resources
docker system prune -f
```

---

## 📚 Learn More

| Resource | What It Covers |
|----------|---------------|
| 📄 **`docs/JENKINS_PIPELINE.md`** | Step-by-step Jenkins setup from scratch |
| 📄 **`docs/ANSIBLE_DEPLOY.md`** | Deep dive into Ansible concepts and patterns |
| 🛠️ **`scripts/scan.sh --list`** | All available scanning checks |
| 📄 **`Jenkinsfile`** | The complete pipeline definition |
| 📄 **`pyproject.toml`** | Python linting configuration |

---

> 💡 **Pro tip:** Start with **Step 1** (Docker Compose) to see the app working in 30 seconds. Then go through **Steps 2-3** (Manual + API) to understand the pieces. Once you're comfortable, work through **Steps 4-7** for the full CI/CD experience.

### See Jenkins in action

Once you've set up the credentials and updated the Jenkinsfile:

1. Go back to Jenkins at `http://localhost:8080`
2. Click on your pipeline job
3. Click **Build Now** (manual trigger to test)
4. Watch the pipeline execute:
   - **Checkout:** pulls your code
   - **Build Backend:** `docker build` backend image
   - **Build Frontend:** `docker build` frontend image
   - **Push to Hub:** both images pushed as `YOURNAME/student-backend:BUILD_NUMBER` and `YOURNAME/student-frontend:BUILD_NUMBER`
5. Check the console output: click on the build → **Console Output**

### Automatic triggering on code changes

Now the magic happens. Every time you:

1. Make a code change in `backend/` or `frontend/`
2. Commit the change
3. Push to GitHub

Jenkins automatically:
- Detects the change (polls every 2 minutes)
- Runs the full pipeline
- Builds and pushes new images to Docker Hub

**Try it:**

```bash
# Edit the backend
echo "# Updated backend" >> backend/main.py

# Commit and push
git add backend/main.py
git commit -m "Update backend"
git push origin main
```

Then refresh Jenkins — within 2 minutes, you'll see a new build start automatically!

### Deploy the built images with Ansible

Once Jenkins pushes images to Docker Hub, use Ansible to deploy them:

```bash
# Deploy to staging with the latest built image
ansible-playbook -i ansible/hosts ansible/deploy_stack_playbook.yaml -e target=staging -e dh_user=YOURNAME

# Or production
ansible-playbook -i ansible/hosts ansible/deploy_stack_playbook.yaml -e target=production -e dh_user=YOURNAME
```

**The full workflow:**
1. You code → push to GitHub
2. Jenkins detects → builds → tests → pushes to Docker Hub
3. Ansible pulls from Docker Hub → deploys to staging/production

## 12) Cleanup commands

## 12) Cleanup commands

```bash
docker rm -f backend-staging frontend-staging || true
docker network rm appnet-staging || true

docker rm -f backend-production frontend-production || true
docker network rm appnet-production || true
```

## 13) Troubleshooting
- `docker ps` — see running containers
- `docker logs backend-staging` — inspect backend logs
- `docker logs frontend-staging` — inspect frontend logs
- `ansible-playbook ... -vv` — increase Ansible verbosity
- if ports are in use, stop the conflicting service or container

## 14) Docker fundamentals: `docker run` vs `docker exec`

**For students new to Docker — this is important to understand:**

- **`docker run -it IMAGE /bin/bash`** — creates and starts a NEW container from an image, then enters it. Use this when you want to test a fresh container.
  - Example: `docker run -it student-backend:latest /bin/bash`
  - This works only if the image exists locally or is available on a registry.

- **`docker exec -it CONTAINER /bin/bash`** — enters an already-running container. Use this to inspect a live deployment.
  - Example: `docker exec -it backend-staging /bin/bash`
  - The container must be running (check with `docker ps`).

**Common student mistake:**
- Trying `docker run -it backend-staging /bin/bash` treats `backend-staging` as an image name, but it's actually a container name. This fails with "pull access denied."
- **Solution:** Use `docker exec -it backend-staging /bin/bash` instead.

## 15) Key files to review
- `backend/Dockerfile`
- `frontend/Dockerfile`
- `docker-compose.yml`
- `ansible/hosts`
- `ansible/setup_basics_playbook.yaml`
- `ansible/deploy_stack_playbook.yaml`
- `scripts/build_and_push.sh`
- `scripts/setup_environments.sh`
- `scripts/deploy.sh`
- `Jenkinsfile`

## 16) Quick reference: Recommended workflow for students new to CI/CD

1. **Start everything:** `docker compose up -d` (backend + frontend + Jenkins)
2. **Verify app works:** `http://localhost:8501`
3. **Set up Jenkins:** `http://localhost:8080` (unlock, install plugins, configure credentials)
4. **Create Jenkins job:** Pipeline from SCM pointing to this repo and Jenkinsfile
5. **Update Jenkinsfile:** Set `DOCKER_USER` to your Docker Hub username
6. **Test Jenkins:** Click **Build Now** to trigger the pipeline manually
7. **Make a code change:** Edit `backend/main.py` or `frontend/app.py`
8. **Commit and push:** `git commit -am "change" && git push`
9. **Watch Jenkins build:** Within 2 minutes, Jenkins auto-detects and builds
10. **Deploy with Ansible:** `ansible-playbook -i ansible/hosts ansible/deploy_stack_playbook.yaml -e target=staging -e dh_user=YOURNAME`
11. **Verify deployment:** `curl http://localhost:8501/` and `docker ps`
12. **Celebrate:** You've completed end-to-end CI/CD!
