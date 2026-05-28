# Deploy with Ansible: Build, Push & Deploy a Two-Tier App (Staging → Production)

A standalone, self-contained guide to containerizing a real two-tier web app — a **FastAPI back-end** (the API) and a **Streamlit front-end** (the UI that calls the API) — pushing **both** images to Docker Hub, then using **Ansible** to deploy and wire them together across two environments (**staging → production**), all runnable in a **blank GitHub Codespace**. (Adding a third environment such as `developer` is a one-line change, shown in Step 2.)

This is the deployment companion to the Jenkins CI/CD guide (`README.md`). Where that guide builds and publishes a single image, here we have a real **front-end + back-end** pair: the Streamlit UI sends HTTP requests to the FastAPI service, so Ansible's job is to deploy both and make sure the front-end can reach the back-end.

The Ansible patterns (inventory, `ansible.cfg`, `ping` checks, playbooks, modules, idempotency) follow the Cisco DEVASC Ansible labs, adapted for containers instead of VMs/routers.

---

## What you'll build

```
                ┌──────────────────────────────────────────────────────────┐
  Browser ─▶    │  STAGING environment (target container "staging")        │
  :8501 (UI)    │                                                          │
  :8001 (API)   │   ┌─ frontend (Streamlit :8501) ──HTTP──▶ backend (:8000)│
                │   └──────────── private network "appnet" ────────────────│
                └──────────────────────────────────────────────────────────┘
                ┌──────────────────────────────────────────────────────────┐
  Browser ─▶    │  PRODUCTION environment (target container "prod")        │
  :8502 (UI)    │                                                          │
  :8002 (API)   │   ┌─ frontend (Streamlit :8502) ──HTTP──▶ backend (:8000)│
                │   └──────────── private network "appnet" ────────────────│
                └──────────────────────────────────────────────────────────┘
```

Each environment is its own target machine (simulated by a container built from a Dockerfile). Inside each, Ansible deploys **two containers on a private network `appnet`**: the **FastAPI back-end** and the **Streamlit front-end**. The front-end reaches the back-end by container name (`http://backend:8000`) over that private network — not `localhost`. You open the UI in your browser on a per-environment port.

| Environment | UI (Streamlit) | API (FastAPI) | SSH |
|-------------|----------------|---------------|-----|
| staging | localhost:8501 | localhost:8001 | localhost:2211 |
| production | localhost:8502 | localhost:8002 | localhost:2212 |

> **Why expose the API too?** In production you'd usually keep the back-end private and expose only the UI. We publish the API here as well so students can open the FastAPI docs (`/docs`) directly and *see* both tiers — a teaching convenience. Step 8 shows how to make the back-end private for real production.

> **Why separate targets?** So you can *see* promotion: deploy to staging, verify, then run the same playbook against production. The playbook never changes — only which inventory group you target. (Adding a `developer` env is shown in Step 2.)

---

## Prerequisites

- A **Docker Hub account** and an **access token** (Read & Write) — the same kind the Jenkins guide's Step 7a walks through. You'll push two images.
- The two app files from class: `backend/main.py` (FastAPI) and `frontend/app.py` (Streamlit).
- A blank Codespace with Docker (same as the main guide's Step 0).

---

## What is Ansible?

Ansible automates configuration of remote machines by running **playbooks** — YAML files that describe the *desired end state* rather than step-by-step commands. Core concepts (mirroring the Cisco labs):

- **Inventory (`hosts`)** — the machines Ansible manages and how to reach each (address, port, user, credentials), organized into **groups** like `[staging]` and `[production]`.
- **`ansible.cfg`** — points Ansible at your inventory and sets defaults (e.g. disable SSH host-key prompts).
- **Modules** — units of work. The Cisco web-server lab uses `apt`, `apache2_module`, `service`, and `lineinfile`. Here we mainly use `community.docker.docker_container`, `docker_image`, and `docker_network`.
- **Handlers & `notify`** — tasks that run only when something changed (e.g. restart Apache after editing its config), exactly as in the Cisco Apache lab.
- **Idempotency** — re-running a playbook only changes what isn't already correct; a second run shows `changed=0`.

Ansible answers the question *"put this published build onto these machines and keep the whole stack running"* — the deployment half of CI/CD.

---

## Why Ansible — why not just push with Docker?

A fair question: if Docker already packages the app and Docker Hub already stores it, why not just `ssh` into the server and `docker run`? You *can* — for **one** machine. Here's why that stops working as you grow, and what each tool is actually for.

**They solve different problems:**

| Tool | Answers the question | Scope |
|------|----------------------|-------|
| **Docker** | "How do I package this app so it runs identically anywhere?" | one app → one image |
| **Docker Hub** | "Where do I store that image so any machine can pull it?" | a registry |
| **Ansible** | "How do I prepare N servers, deploy the right version, wire front-end to back-end, restart only what changed — the same way every time?" | orchestration across an environment |

**Where "just Docker" breaks down:**

1. **Manual SSH on every server.** Two environments with a few servers each means a lot of hand-typed `docker pull` / `stop` / `rm` / `run`. Easy to make a mistake, easy to let staging drift from production. Ansible runs the *same playbook* against a whole group — 1 server or 50, one command.
2. **No "desired state," only fire-and-forget.** `docker run` doesn't know if the app is already running, already the right version, or half-broken. Ansible is **idempotent**: it checks current state and changes only what's wrong, so re-running is safe (the `changed=0` you see on a second run).
3. **A real deploy is more than `docker run`.** Production hosts need Docker installed, ports opened, a reverse proxy (Apache/Nginx) configured, volumes mounted, services restarted. Docker only runs containers — it does none of that. Ansible's modules (`apt`, `service`, `lineinfile`, `copy`, `docker_container`) configure the *whole machine*, exactly like the Cisco Apache lab (install Apache → enable a module → edit `ports.conf` → restart).
4. **Multi-container wiring and ordering.** The front-end must reach the back-end by name on a private network; the back-end must be up before the proxy forwards to it; restart the proxy only if its config changed. Ansible expresses that coordination declaratively; bare Docker leaves you scripting it in bash.
5. **Promotion across environments.** Staging → production should be the *identical* process with only the target changing: `-e target=staging` vs `-e target=production` against the same playbook. With raw Docker you'd maintain separate per-environment scripts and pray they stay in sync.

**Side-by-side.** Deploying to 2 servers with raw Docker:

```bash
ssh staging "docker pull app:latest && docker stop app; docker rm app; docker run -d --name app -p 80:5050 app:latest"
ssh prod    "docker pull app:latest && docker stop app; docker rm app; docker run -d --name app -p 80:5050 app:latest"
# ...and you still haven't configured the proxy, the firewall, or handled "what if it's already running"
```

The same outcome in Ansible — one command per environment, idempotent, proxy and health check included:

```bash
ansible-playbook deploy_stack_playbook.yaml -e target=production
```

**The honest counterpoint.** Ansible isn't the only or always-best answer. At larger scale **Kubernetes** (with Helm/ArgoCD) does container orchestration, self-healing, and rollouts more powerfully — and Ansible is often used just to *prepare the hosts* that then run Kubernetes. **Docker Compose** is simpler for a single host; **Docker Swarm** schedules containers across hosts natively. The accurate takeaway: *Ansible is excellent for agentless, repeatable configuration and deployment across conventional servers* — a very common real-world case — not a claim that it beats every alternative. The industry pattern is **Docker + a registry + an orchestrator together**, which is exactly what this lab models: Jenkins/Docker build and publish the artifact, Ansible delivers and wires it across environments.

---

## Step 0: Containerize and push BOTH apps to Docker Hub

Before Ansible can deploy anything, the two apps need to be Docker images on Docker Hub. We'll build them separately — one image per tier — and push both.

### 0a. Get the app code and lay out the folders

```bash
mkdir -p ~/studentapp/backend ~/studentapp/frontend && cd ~/studentapp
```

Put the class code in place: `backend/main.py` (the FastAPI app) and `frontend/app.py` (the Streamlit app). Final layout:

```
studentapp/
├── backend/
│   ├── main.py            <-- FastAPI app (from class)
│   ├── requirements.txt
│   └── Dockerfile
└── frontend/
    ├── app.py             <-- Streamlit app (from class)
    ├── requirements.txt
    └── Dockerfile
```

### 0b. One required code change in the front-end

The Streamlit app hard-codes `API_URL = "http://localhost:8000"`. That works when both run on your laptop, but **once they're in separate containers, `localhost` inside the front-end container points at itself — not the back-end.** Make the URL configurable via an environment variable so Ansible can wire it.

In `frontend/app.py`, change this line:

```python
API_URL = "http://localhost:8000"
```

to:

```python
import os
API_URL = os.getenv("API_URL", "http://localhost:8000")
```

Now the front-end uses whatever `API_URL` we pass it at deploy time (e.g. `http://backend:8000`), and still defaults to localhost for running it bare on your machine.

### 0c. Back-end image (FastAPI)

`backend/requirements.txt`:

```
fastapi
uvicorn[standard]
pydantic
```

`backend/Dockerfile`:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 0d. Front-end image (Streamlit)

`frontend/requirements.txt`:

```
streamlit
requests
pandas
```

`frontend/Dockerfile`:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8501
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

### 0e. Build, log in, and push both images

Set your Docker Hub username once, then build and push each image. Replace the token prompt with your Docker Hub access token.

```bash
export DH=your-dockerhub-username      # <-- CHANGE

# Log in (paste your Docker Hub access token as the password)
docker login -u "$DH"

# Build the back-end and front-end images
docker build -t "$DH/student-backend:latest"  ~/studentapp/backend
docker build -t "$DH/student-frontend:latest" ~/studentapp/frontend

# Push both to Docker Hub
docker push "$DH/student-backend:latest"
docker push "$DH/student-frontend:latest"
```

Verify on **hub.docker.com → Repositories** — you should see two repos: `student-backend` and `student-frontend`. These are the images Ansible will pull and deploy.

> **Tip:** test locally before deploying with Ansible if you like:
> ```bash
> docker network create appnet
> docker run -d --name backend  --network appnet -p 8000:8000 "$DH/student-backend:latest"
> docker run -d --name frontend --network appnet -e API_URL=http://backend:8000 -p 8501:8501 "$DH/student-frontend:latest"
> ```
> Open port 8501 → the Streamlit UI; port 8000/docs → the FastAPI docs. Then clean up: `docker rm -f backend frontend && docker network rm appnet`.

---

## Step 1: Install Ansible and the Docker collection

A blank Codespace has neither. Install them:

```bash
sudo apt-get update
sudo apt-get install -y ansible sshpass
ansible-galaxy collection install community.docker
pip install docker
ansible --version
```

- `sshpass` — lets Ansible authenticate over SSH with a password (the same utility the Cisco web-server lab installs).
- `community.docker` — provides the `docker_container`, `docker_image`, and `docker_network` modules.
- `docker` (pip) — the Python SDK Ansible uses to talk to the Docker daemon.

---

## Step 2: Build a target image with a Dockerfile, then spin up 2 environments

Instead of starting a bare image and installing tools afterward with a script, we'll **bake everything into a custom image using a Dockerfile**. This is cleaner and more realistic: the target image is itself version-controlled and reproducible. We'll then launch **two environments** from it — **staging** and **production**.

> We use two environments here to keep it focused; adding a third (e.g. `developer`) is just one more `docker run` plus one more inventory group — shown at the end of this step.

### 2a. Create the target Dockerfile

This image is the "machine" Ansible deploys to: Ubuntu with an SSH server, Docker, and Python pre-installed and ready.

```bash
mkdir -p ~/ansible-multienv/target-image && cd ~/ansible-multienv/target-image
```

Create `Dockerfile`:

```dockerfile
FROM ubuntu:22.04

# Install SSH server, Docker, and Python (what Ansible needs on a target)
RUN apt-get update && \
    apt-get install -y openssh-server docker.io python3 python3-pip sudo && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH: allow root login with a password (lab only)
RUN mkdir -p /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22 80

# Start Docker daemon and the SSH server when the container runs
CMD service docker start && /usr/sbin/sshd -D
```

### 2b. Build the target image

```bash
cd ~/ansible-multienv/target-image
docker build -t deploy-target:latest .
```

You'll see the build steps run and finish with `Successfully tagged deploy-target:latest`.

### 2c. Spin up the 2 environments

Launch one container per environment from that image. Each gets a unique SSH port plus two app ports — one for the Streamlit **UI** and one for the FastAPI **API**. Inside every target the app containers always use 8501 (UI) and 8000 (API); the target maps those out to per-environment Codespace ports.

```bash
# STAGING — SSH 2211, UI 8501→8501, API 8001→8000
docker run -d --rm --name staging --privileged \
  -p 2211:22 -p 8501:8501 -p 8001:8000 \
  deploy-target:latest

# PRODUCTION — SSH 2212, UI 8502→8501, API 8002→8000
docker run -d --rm --name prod --privileged \
  -p 2212:22 -p 8502:8501 -p 8002:8000 \
  deploy-target:latest
```

- `--privileged` lets each target run Docker inside it (needed to launch the app containers).
- `-p 2211:22` / `-p 2212:22` — SSH access for Ansible at `localhost:2211` and `localhost:2212`.
- `-p 8501:8501` / `-p 8502:8501` — the Streamlit **UI** of staging / production, viewable in the PORTS tab.
- `-p 8001:8000` / `-p 8002:8000` — the FastAPI **API** of staging / production (open `/docs` to explore it).

> **The double hop:** browser → target's published port → app container inside the target. That's why the target maps, say, `8501:8501` (Codespace→target) while the playbook later publishes `8501:8501` again (target→app container). The inner ports are always 8501/8000; only the outer Codespace port changes per environment.

Give the Docker daemon inside each a couple of seconds to start, then confirm both are up:

```bash
sleep 5
docker ps --filter name=staging --filter name=prod
```

The login for each target is user `root`, password `root` (baked into the Dockerfile).

> **Adding a third environment (developer):** build once, run once more, add one inventory group.
> ```bash
> docker run -d --rm --name dev --privileged -p 2210:22 -p 8500:8501 -p 8000:8000 deploy-target:latest
> ```
> Then add a `[developer]` group to `hosts` (Step 3) with `ansible_port=2210`, `ui_port=8500`, `api_port=8000`.

> **Why a container as a "server"?** A blank Codespace has no separate machines. These containers behave like remote servers for Ansible — same SSH, same modules. To deploy to *real* staging/production servers later, you change only the inventory (Step 3) to point at their real addresses and credentials. The playbook and target image concept stay identical.

---

## Step 3: Create the Ansible project

```bash
mkdir -p ~/ansible-multienv && cd ~/ansible-multienv
```

You'll create these files (the `target-image/Dockerfile` from Step 2 lives here too):

```
ansible-multienv/
├── target-image/
│   └── Dockerfile              <-- the target "server" image (Step 2)
├── ansible.cfg                 <-- Ansible defaults
├── hosts                       <-- inventory: staging / production groups
├── setup_basics_playbook.yaml  <-- simple first playbook (Step 4b)
└── deploy_stack_playbook.yaml  <-- deploys back-end + front-end together
```

### `ansible.cfg`

Modeled on the Cisco lab's config:

```ini
[defaults]
inventory=./hosts
host_key_checking = False
retry_files_enabled = False
deprecation_warnings = False
```

### `hosts`

Two groups, one per environment. Both targets are `localhost` on different SSH ports in this lab; in production you'd swap in real addresses and SSH keys. The `ui_port` and `api_port` vars tell the playbook which Codespace ports map to each environment's front-end and back-end.

```ini
[staging]
staging ansible_host=localhost ansible_port=2211 ansible_user=root ansible_ssh_pass=root

[production]
prod ansible_host=localhost ansible_port=2212 ansible_user=root ansible_ssh_pass=root

# Per-environment published ports (UI = Streamlit, API = FastAPI)
[staging:vars]
ui_port=8501
api_port=8001

[production:vars]
ui_port=8502
api_port=8002

# Variables applied to every target
[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### `deploy_stack_playbook.yaml`

This is the heart of it. For whichever environment you target, it: creates a private network, pulls and runs your **FastAPI back-end**, then pulls and runs your **Streamlit front-end** with `API_URL` pointed at the back-end by its container name. Finally it health-checks both tiers. **Change the two image names** to your Docker Hub username.

```yaml
---
- name: DEPLOY FASTAPI BACK-END + STREAMLIT FRONT-END STACK
  hosts: "{{ target | default('staging') }}"
  gather_facts: false

  vars:
    backend_image:  your-dockerhub-username/student-backend:latest    # <-- CHANGE
    frontend_image: your-dockerhub-username/student-frontend:latest   # <-- CHANGE

  tasks:
    - name: CREATE A PRIVATE NETWORK FOR THE STACK
      community.docker.docker_network:
        name: appnet
        state: present

    # ---------- BACK-END (FastAPI) ----------
    - name: PULL THE BACK-END IMAGE FROM DOCKER HUB
      community.docker.docker_image:
        name: "{{ backend_image }}"
        source: pull
        force_source: true        # always grab the newest :latest

    - name: RUN THE FASTAPI BACK-END CONTAINER
      community.docker.docker_container:
        name: backend
        image: "{{ backend_image }}"
        state: started
        recreate: true
        networks:
          - name: appnet
        published_ports:
          - "8000:8000"   # fixed inside the target; the target maps it out to api_port

    # ---------- FRONT-END (Streamlit) ----------
    - name: PULL THE FRONT-END IMAGE FROM DOCKER HUB
      community.docker.docker_image:
        name: "{{ frontend_image }}"
        source: pull
        force_source: true

    - name: RUN THE STREAMLIT FRONT-END CONTAINER
      community.docker.docker_container:
        name: frontend
        image: "{{ frontend_image }}"
        state: started
        recreate: true
        networks:
          - name: appnet
        published_ports:
          - "8501:8501"   # fixed inside the target; the target maps it out to ui_port
        env:
          # The front-end reaches the back-end by container name over appnet.
          API_URL: "http://backend:8000"

    # ---------- HEALTH CHECKS (run from the Codespace) ----------
    - name: WAIT FOR THE BACK-END API TO RESPOND
      ansible.builtin.uri:
        url: "http://localhost:{{ api_port }}/"
        return_content: yes
      register: api_result
      retries: 8
      delay: 3
      until: api_result.status == 200
      delegate_to: localhost

    - name: WAIT FOR THE FRONT-END UI TO RESPOND
      ansible.builtin.uri:
        url: "http://localhost:{{ ui_port }}/"
        status_code: 200
      register: ui_result
      retries: 8
      delay: 3
      until: ui_result.status == 200
      delegate_to: localhost

    - name: SHOW WHAT THE API RETURNED
      ansible.builtin.debug:
        msg: "API says: {{ api_result.content }}"
      delegate_to: localhost
```

**Why no Apache here?** Streamlit *is* the front-end web app — it serves its own UI on 8501 and talks to FastAPI over the private network. There's no separate proxy tier to configure, so the playbook is simpler than a proxy-based stack: pull two images, run two containers, wire them with one env var.

---

## Step 4: Verify Ansible can reach the targets

Just like the Cisco lab's `ping` module check, confirm connectivity to all environments:

```bash
cd ~/ansible-multienv
ansible all -m ping
```

Each target should return `"ping": "pong"`. If you get SSH errors, recheck the ports (2211/2212), that the containers are running, and user/pass `root`/`root`.

---

## Step 4b: A simple first playbook — see the power in a few lines

Before the full stack deployment, run a tiny playbook that shows what makes Ansible powerful: **one short file configures every machine at once, idempotently.** This mirrors the Cisco Apache lab's `apt` + `service` pattern.

Create `setup_basics_playbook.yaml` in `~/ansible-multienv`:

```yaml
---
- name: PREPARE EVERY ENVIRONMENT WITH COMMON TOOLS
  hosts: all                # <-- runs on staging AND production together
  gather_facts: true        # collect facts (OS, IP, memory) from each target

  tasks:
    - name: INSTALL COMMON DEPENDENCIES
      ansible.builtin.apt:
        name:
          - curl
          - vim
          - htop
          - git
        state: present
        update_cache: yes

    - name: MAKE SURE THE SSH SERVICE IS RUNNING
      ansible.builtin.service:
        name: ssh
        state: started

    - name: CREATE A DEPLOY USER ON EVERY MACHINE
      ansible.builtin.user:
        name: deployer
        shell: /bin/bash
        groups: sudo
        append: yes

    - name: DROP A SERVER INFO FILE ONTO EACH TARGET
      ansible.builtin.copy:
        dest: /etc/server-info.txt
        content: |
          Managed by Ansible
          Hostname:   {{ inventory_hostname }}
          OS:         {{ ansible_distribution }} {{ ansible_distribution_version }}
          IP address: {{ ansible_default_ipv4.address | default('n/a') }}

    - name: SHOW EACH MACHINE'S OS AND IP
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} is running {{ ansible_distribution }} {{ ansible_distribution_version }}"
```

Run it against **both** environments at once:

```bash
cd ~/ansible-multienv
ansible-playbook setup_basics_playbook.yaml
```

**What just happened — and why it's powerful:**

- **`hosts: all`** — one command configured *both* staging and production. Add 50 servers to the inventory and the exact same command configures all 50. No SSH-ing into each one.
- **`apt` with a list** — installed four packages (`curl`, `vim`, `htop`, `git`) on every machine in a single task. The Cisco lab installed Apache the same way; Ansible's module library covers packages, services, users, files, and far more.
- **`gather_facts` + variables** — Ansible auto-discovered each machine's OS, version, and IP (`ansible_distribution`, `ansible_default_ipv4`) and used them to write a customized `/etc/server-info.txt` per host. The same playbook adapts to each machine.
- **Idempotency** — run it a second time:
  ```bash
  ansible-playbook setup_basics_playbook.yaml
  ```
  The PLAY RECAP now shows mostly `ok` instead of `changed` — Ansible saw the packages and user already exist and did nothing. Re-running is always safe.

Verify it worked on a target:

```bash
docker exec staging cat /etc/server-info.txt
docker exec staging su - deployer -c "whoami && which curl htop git"
```

> **The takeaway:** that ~25-line file is the whole point of Ansible — declare the desired state once, apply it to any number of machines, repeatably. The big deployment playbook in the next steps is just this idea scaled up to running your app's containers.

---

## Step 5: Deploy to STAGING first

Deploy the stack to the staging environment only:

```bash
ansible-playbook deploy_stack_playbook.yaml -e target=staging
```

Task by task:

1. **CREATE A PRIVATE NETWORK** — an internal `appnet` so the front-end and back-end containers can find each other by name.
2. **PULL + RUN THE FASTAPI BACK-END** — pulls `student-backend:latest` from Docker Hub and starts it as `backend`, listening on 8000 inside the target.
3. **PULL + RUN THE STREAMLIT FRONT-END** — pulls `student-frontend:latest`, starts it as `frontend` on 8501, and sets `API_URL=http://backend:8000` so the UI calls the API over the private network (this is the wiring that makes `localhost` unnecessary).
4. **HEALTH CHECK API** — from the Codespace, polls `localhost:8001` until FastAPI returns 200.
5. **HEALTH CHECK UI** — polls `localhost:8501` until Streamlit returns 200.
6. **SHOW API RESPONSE** — prints the FastAPI health-check JSON (`🎓 Student API is running!`).

Open these in the **PORTS** tab:
- **8501** — the Streamlit UI. Click through the sidebar (Get All Students, Stats, Add Student…) and watch it call the back-end.
- **8001/docs** — the FastAPI interactive docs, to hit the API directly.

The **PLAY RECAP** should show `failed=0`.

---

## Step 6: Promote to PRODUCTION

This is the payoff — the **same playbook**, different target group. Only after staging looks good:

```bash
ansible-playbook deploy_stack_playbook.yaml -e target=production
```

Open **8502** (production UI) and **8002/docs** (production API) to see it running independently of staging. Both environments now run the same two published images, wired identically — repeatable, environment-agnostic deployment.

> **Deploy to both at once** (less common, but possible): `ansible-playbook deploy_stack_playbook.yaml -e target=all`.

---

## Step 7: Redeploy a new version (the update loop)

When Jenkins pushes a new `:latest` to Docker Hub, redeploy by re-running the playbook for an environment. Because of `recreate: true` and `source: pull`, Ansible pulls the new image and replaces the running back-end:

```bash
ansible-playbook deploy_stack_playbook.yaml -e target=staging
```

Promote to production once verified:

```bash
ansible-playbook deploy_stack_playbook.yaml -e target=production
```

This models a real release: a new build is validated in staging for QA, then released to production — each step a single, identical command.

---

## Step 8: From this lab to real servers

To deploy to genuine machines, change **only** the inventory. Nothing in the playbook changes:

```ini
[production]
prod1 ansible_host=203.0.113.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[production:vars]
ui_port=80         # serve the UI on the standard web port
api_port=8000
ansible_python_interpreter=/usr/bin/python3
```

Now `ansible-playbook deploy_stack_playbook.yaml -e target=production` deploys the same FastAPI + Streamlit stack to a real production server using an SSH key (the production norm). Because both images come from Docker Hub, any machine with Docker and network access runs the identical app.

> **Make the back-end private in real production.** In this lab we publish the API port so students can poke `/docs`. In production you'd usually remove the back-end's `published_ports` entirely — the front-end still reaches it over `appnet` by name, but the outside world can't. Only the UI is exposed. That's a one-line change in the playbook's back-end task.

**Wiring it into Jenkins (optional):** add a deploy stage to your pipeline so a successful build auto-deploys to staging:

```groovy
stage('Deploy to Staging with Ansible') {
    steps {
        sh 'cd ~/ansible-multienv && ansible-playbook deploy_stack_playbook.yaml -e target=staging'
    }
}
```

Full chain: **push code → Jenkins builds & pushes both images to Docker Hub → Ansible deploys the FastAPI + Streamlit stack to staging → you verify, then promote to production.**

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| `ansible all -m ping` fails (SSH/permission) | Wrong port (2211 staging / 2212 prod), target container not running (`docker ps`), or user/pass not `root`/`root`. |
| `Failed to import the required Python library (Docker SDK)` | Run `pip install docker` and `ansible-galaxy collection install community.docker`; ensure `ansible_python_interpreter=/usr/bin/python3` is set in `[all:vars]`. |
| Health check times out, but containers are up | The app needs longer to start (Streamlit/uvicorn boot), or the target's outer port mapping is wrong. Increase `retries`/`delay`, and confirm Step 2c maps `8501`/`8000` out to the env's `ui_port`/`api_port`. |
| UI loads but every API call shows "❌ Could not reach the API" | The front-end's `API_URL` isn't pointing at the back-end. Confirm `API_URL: "http://backend:8000"` in the playbook and that both containers are on `appnet` (`docker exec <env> docker network inspect appnet`). |
| `Could not reach the API. Is the backend running?` even with `localhost` | You skipped the Step 0b code change — the front-end is still hard-coded to `localhost:8000`. Apply the `os.getenv("API_URL", ...)` edit and rebuild/push the front-end image. |
| Back-end container exits immediately | Check its logs: `docker exec <env> docker logs backend`. Usually a missing dependency — confirm `backend/requirements.txt` and rebuild/push. |
| `docker: command not found` inside a target | The target image didn't build correctly — rebuild `deploy-target:latest` (Step 2b) and recreate the containers. |
| `Cannot connect to the Docker daemon` inside a target | The daemon hadn't started yet. The image starts it via `service docker start` in its CMD; give it a few seconds (`sleep 5`) after `docker run`, or restart the target container. |
| Port 8501/8001/8502/8002 not forwarding | Add it manually in the **PORTS** tab. |
| `pull access denied` for an image | The image name is wrong or the repo is private. Use your real public `your-username/student-backend:latest` / `student-frontend:latest`, or `docker login` on the target first. |

---

*Companion to the Jenkins CI/CD guide. Ansible patterns adapted from the Cisco DEVASC "Use Ansible to Automate Installing a Web Server" and "Use Ansible to Back Up and Configure a Device" labs, for the GitHub Codespaces environment.*
