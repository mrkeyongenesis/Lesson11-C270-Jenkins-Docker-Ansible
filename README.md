# CI/CD + Ansible Teaching Lab

A fork-and-run lab for learning the full deployment lifecycle: **build → test locally → containerize → push to Docker Hub → automate with Jenkins → deploy across environments with Ansible.**

Everything runs inside a **GitHub Codespace** — no local setup. Fork this repo, open it in a Codespace, and run the scripts.

---

## 🎯 Goal of this lab

By the end, you will have taken a real two-tier web app (a **FastAPI** back-end + a **Streamlit** front-end) all the way from source code to a running, multi-environment deployment — the same path software takes in industry:

1. **Run & test the app locally** to confirm it works before doing anything else.
2. **Package each tier into its own Docker image** so it runs identically anywhere.
3. **Publish both images to Docker Hub** (a container registry).
4. **Automate that build-test-push with Jenkins** so it happens on every code change (Continuous Integration).
5. **Deploy and wire the two tiers together with Ansible**, promoting from **staging → production** (Continuous Deployment).

The big idea: **build once, deploy anywhere, automate everything.** You'll see why each tool exists and how they fit together, rather than just running commands.

### What we cover

| Area | Tool | You'll learn |
|------|------|--------------|
| The app | FastAPI + Streamlit | a front-end that calls a back-end API over HTTP |
| Local testing | Docker / Compose | run and verify the stack before building/publishing |
| Packaging | Docker | turning each app into a versioned image |
| Registry | Docker Hub | storing & sharing images so any machine can pull them |
| CI/CD automation | Jenkins | auto build → test → push both images on every commit |
| Deployment | Ansible | deploying the stack to staging & production, idempotently |

---

## What's in this repo

```
.
├── backend/                 FastAPI "Student API" (the back-end)
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/                Streamlit UI that calls the API (the front-end)
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── docker-compose.yml       Run the whole app locally with one command
│
├── ansible/                 Multi-environment deployment with Ansible
│   ├── target-image/Dockerfile   the "server" image (SSH + Docker)
│   ├── ansible.cfg
│   ├── hosts                      inventory: staging + production
│   ├── setup_basics_playbook.yaml a tiny first playbook (demo)
│   └── deploy_stack_playbook.yaml deploys back-end + front-end together
│
├── jenkins-app/             Simple Flask app (used by the older Jenkins walkthrough)
├── Jenkinsfile              CI/CD pipeline: auto build + push BOTH images
│
├── scripts/                 One-command helpers (see Quick Start)
│   ├── test_local.sh             build + run + smoke-test the app locally
│   ├── install_ansible.sh
│   ├── build_and_push.sh
│   ├── setup_environments.sh
│   └── deploy.sh
│
└── docs/                    Full step-by-step guides
    ├── JENKINS_PIPELINE.md       build a CI/CD pipeline with Jenkins
    └── ANSIBLE_DEPLOY.md         deploy the two-tier app with Ansible
```

---

## Prerequisites

- A **GitHub account** (to fork and open a Codespace).
- A free **Docker Hub account** + an **access token** (Read & Write). Create the token at hub.docker.com → Account settings → Personal access tokens.

---

## Quick Start

### 0. Fork & open in a Codespace
Click **Fork** (top-right of the GitHub page), then on your fork click **Code → Codespaces → Create codespace on main**. Wait for it to build — the devcontainer enables Docker automatically.

### 1. Test the app locally FIRST (always verify before building/publishing)
```bash
docker compose up --build
```
Open the **PORTS** tab → port **8501** for the Streamlit UI, port **8000** (add `/docs`) for the FastAPI docs. Click through the UI to confirm the front-end talks to the back-end. Stop with `Ctrl+C`.

Or run the automated smoke test (builds both images, runs them, curls the API, cleans up):
```bash
chmod 766 scripts/*
./scripts/test_local.sh
```
**Only move on once the app works locally.** This is the golden rule: never build/push/deploy something you haven't run.

### 2. Push your images to Docker Hub (manual)
```bash
./scripts/build_and_push.sh <your-dockerhub-username>
```
Builds `student-backend` and `student-frontend` and pushes both. Paste your Docker Hub **access token** when asked for a password.

> **Or automate this with Jenkins** (recommended) — see step 4. The included **`Jenkinsfile`** builds, tests, and pushes *both* images automatically on every commit, so you don't run this by hand.

### 3. Deploy across environments with Ansible
This lab uses Ansible because deployment is more than just running a container locally. Ansible lets us define:
- which hosts are in **staging** and **production**,
- how to connect to them over SSH,
- which containers to run and when to update them,
- and how to keep deployments repeatable and idempotent.

The `ansible/hosts` file points at two local target containers: `deploy-target-stag` and `prod`. They behave like separate servers, so you can practice real environment promotion without needing remote machines.

The setup script now mounts the Docker socket into each target, which means Ansible can manage Docker from inside that target just like it would on a real server.

```bash
./scripts/install_ansible.sh                       # one-time
./scripts/setup_environments.sh                    # spin up staging + production targets
cd ansible && ansible all -m ping && cd ..         # confirm connectivity
```

Before you deploy, inspect the empty staging target and see that the app is not yet running:
```bash
docker exec -it deploy-target-stag bash -lc 'ls / && echo "No app deployed until Ansible runs"'
```

Then deploy to staging, refresh the UI/API ports, and watch the app appear in the staging environment.

```bash
./scripts/deploy.sh <your-dockerhub-username> staging      # deploy to staging
./scripts/deploy.sh <your-dockerhub-username> production   # promote to production
```

Open the **PORTS** tab:
- **8501** staging UI · **8001/docs** staging API
- **8502** production UI · **8002/docs** production API

### 4. Automate build + push with Jenkins (CI/CD)
The **`Jenkinsfile`** in the repo root defines a pipeline that **auto-builds and pushes both the backend and frontend images to Docker Hub** on every code change. To use it:

1. Run Jenkins (see **[docs/JENKINS_PIPELINE.md](docs/JENKINS_PIPELINE.md)** for the full Docker setup).
2. In Jenkins add a `dockerhub` credential (username + access token), and a `github-cred` credential if your repo is private.
3. Create a **Pipeline** job → **Pipeline script from SCM** → point it at your fork. Jenkins picks up the `Jenkinsfile` automatically.
4. Edit `DOCKER_USER` at the top of the `Jenkinsfile` to your Docker Hub username, commit, and run.

Now every push triggers: **build backend → build frontend → test → push both to Docker Hub.** Combine with step 3 and Ansible redeploys the new images.

---

## A deeper hands-on path for students
If you want to truly understand why each step exists, follow this sequence and compare the behavior at each stage.

1. **Run the full stack locally and inspect it**
   - `docker compose up --build`
   - Open `localhost:8501` for the Streamlit UI and `localhost:8000/docs` for FastAPI.
   - Confirm the UI calls the API and inspect the logs with `docker compose logs -f`.
   - Stop it with `Ctrl+C`.

2. **Use the smoke test script to verify the same flow automatically**
   - `chmod 766 scripts/*`
   - `./scripts/test_local.sh`
   - Notice how this script builds both images, starts the services, runs a curl test, then cleans up.

3. **Build and push the images manually**
   - `./scripts/build_and_push.sh <your-dockerhub-username>`
   - After pushing, run `docker images` and `docker ps -a` to see the new image tags.
   - If you want, simulate a fresh environment by removing local containers and images, then `docker pull <your-dockerhub-username>/student-backend:latest`.

4. **Deploy the stack with Ansible and compare environments**
   - `./scripts/install_ansible.sh`
   - `./scripts/setup_environments.sh`
   - `cd ansible && ansible all -m ping && cd ..`
   - `./scripts/deploy.sh <your-dockerhub-username> staging`
   - Open the staging URLs and verify the app is running in a separate environment.
   - `./scripts/deploy.sh <your-dockerhub-username> production`
   - Compare staging and production port mappings and confirm the promotion path.

5. **Inspect the pipeline and validate automation**
   - Open `Jenkinsfile` and read the stages: build backend, build frontend, test, push.
   - Make a small app change, commit, and push.
   - Watch Jenkins run the pipeline and see the same steps happen automatically.
   - Then redeploy the updated images with Ansible to complete the end-to-end flow.

This deeper path helps you appreciate:
- why local verification is the first and most important step,
- why Docker images are the portable unit shared between CI and deployment,
- why Jenkins is useful for repeatable automation,
- and why Ansible is needed to deploy and promote a multi-tier stack across environments.

---

## Learn the concepts

- **[docs/JENKINS_PIPELINE.md](docs/JENKINS_PIPELINE.md)** — what CI/CD is, building a Jenkins pipeline that builds, tests, tags, and pushes an image to Docker Hub automatically on every code change.
- **[docs/ANSIBLE_DEPLOY.md](docs/ANSIBLE_DEPLOY.md)** — what Ansible is, why it's used over plain Docker for deployment, and how it deploys the FastAPI + Streamlit stack to staging and production.

---

## Common issues

| Problem | Fix |
|---------|-----|
| `docker` command not found / `docker ps` fails | The Codespace didn't pick up the devcontainer. **Codespaces → Rebuild Container**. |
| `build_and_push.sh` login fails | Use a Docker Hub **access token** as the password, not your account password. |
| `ansible all -m ping` fails | Run `./scripts/setup_environments.sh` first; wait a few seconds for the targets to boot. |
| A port isn't reachable | Add it manually in the **PORTS** tab. |
| Deploy says `pull access denied` | Make sure step 2 pushed successfully and you passed the same Docker Hub username to `deploy.sh`. |

More detail in the troubleshooting sections of each guide in `docs/`.
