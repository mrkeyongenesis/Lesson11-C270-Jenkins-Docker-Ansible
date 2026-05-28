# Two-Tier Docker & Ansible Demo

A clean step-by-step guide for this two-tier app:
- `backend/` — FastAPI backend
- `frontend/` — Streamlit frontend
- `ansible/` — staging and production deployment playbooks
- `scripts/` — helper build and deploy scripts

This README is focused on:
- testing the app locally
- building Docker images and infrastructure
- installing Ansible on the control node
- connecting staging and production targets
- deploying with Ansible

## Prerequisites
- Docker is installed and running on your machine
- Python 3.6+ is available
- You have basic familiarity with the terminal
- Git is installed (to clone this repo)

To verify Docker is available:

```bash
docker version
docker ps
```

Both commands should run without errors.

## 1) Repo structure at a glance
- `backend/Dockerfile` — backend build instructions
- `frontend/Dockerfile` — frontend build instructions
- `docker-compose.yml` — optional local compose workflow (now includes Jenkins for CI/CD)
- `ansible/hosts` — inventory for staging and production
- `ansible/setup_basics_playbook.yaml` — prepare target hosts
- `ansible/deploy_stack_playbook.yaml` — deploy the app stack
- `scripts/build_and_push.sh` — build/push images to Docker Hub
- `scripts/setup_environments.sh` — environment setup helper
- `scripts/deploy.sh` — deployment helper
- `Jenkinsfile` — CI/CD pipeline definition (checkout → build → test → push)

## 2) Set up the local environment (first time setup)
Before building and deploying, clean up any old containers and networks from previous runs.

This is **safe** — it only removes old demo containers and networks, not production data.

```bash
./scripts/setup_environments.sh
```

What this does:
- Checks that Docker is available
- Removes old staging containers (if any exist)
- Removes old production containers (if any exist)
- Removes old Docker networks used by this demo
- Prints the port mappings for reference

**Students new to Docker:** This step is optional on first run. It becomes important when you redeploy and want to clean up before a fresh start.

## 3) Test the application locally first
This is the quickest way to confirm the app works before adding Ansible.

Build both images:

```bash
docker build -t student-backend:latest backend
docker build -t student-frontend:latest frontend
```

Run the staging containers:

```bash
docker network create appnet-staging || true

docker rm -f backend-staging >/dev/null 2>&1 || true
docker run -d --name backend-staging --network appnet-staging -p 8001:8000 student-backend:latest

docker rm -f frontend-staging >/dev/null 2>&1 || true
docker run -d --name frontend-staging --network appnet-staging -e API_URL=http://backend-staging:8000 -p 8501:8501 student-frontend:latest
```

Verify the staging environment:

```bash
curl -sS http://localhost:8001/ || echo "backend did not respond"
curl -sS http://localhost:8501/ | head -n 10
```

Open the browser:

```text
http://localhost:8501
```

If the backend responds and the UI loads, the app is working.

### 3a) Optional: Bind staging to a specific IP address (not localhost)

By default, Docker binds to `localhost` (127.0.0.1). To access the staging containers from other machines on your network, bind them to your host's IP address.

**Step 1: Find your host's IP address**

On macOS or Linux:

```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

Or on Linux specifically:

```bash
hostname -I
```

You should see an IP like `192.168.1.100` or `10.0.0.5`.

**Step 2: Run containers with IP binding**

Replace `YOUR_HOST_IP` with the actual IP address from Step 1. For example, if your IP is `192.168.1.100`:

```bash
docker network create appnet-staging || true

docker rm -f backend-staging >/dev/null 2>&1 || true
docker run -d --name backend-staging --network appnet-staging -p 192.168.1.100:8001:8000 student-backend:latest

docker rm -f frontend-staging >/dev/null 2>&1 || true
docker run -d --name frontend-staging --network appnet-staging -e API_URL=http://backend-staging:8000 -p 192.168.1.100:8501:8501 student-frontend:latest
```

**Step 3: Access from your IP address**

Now you can access the app from any machine on your network:

```bash
# From this machine:
curl -sS http://192.168.1.100:8001/

# From another machine on the network:
# Open browser: http://192.168.1.100:8501
```

**Why bind to an IP?**
- Access the staging app from another machine on your network (e.g., a colleague's laptop, a mobile device, or a CI/CD runner).
- Test the app from different clients.
- Simulate a remote deployment scenario locally.

**Note:** If you bind to a specific IP, the container will NOT be accessible via `localhost:8501` from your local machine — it will only be accessible via the IP address.

## 4) Build infrastructure for staging and production
The Dockerfiles are the build infrastructure. Use them to create local images and registry tags.

### Build for staging

```bash
docker build -t student-backend:latest backend
docker build -t student-frontend:latest frontend
```

### Build and tag for production

```bash
docker build -t student-backend:latest -t YOURNAME/student-backend:latest backend
docker build -t student-frontend:latest -t YOURNAME/student-frontend:latest frontend
```

### Push production images to Docker Hub

```bash
docker login -u YOUR_DOCKERHUB_USERNAME
docker push YOURNAME/student-backend:latest
docker push YOURNAME/student-frontend:latest
```

Or use the helper:

```bash
./scripts/build_and_push.sh your-dockerhub-username
```

## 5) Install Ansible on the control node
The control node is where you run Ansible commands.

### Linux

```bash
python3 -m pip install --user ansible
```

Or on Ubuntu:

```bash
sudo apt update
sudo apt install -y ansible
```

### macOS

```bash
brew install ansible
```

Verify:

```bash
ansible --version
```

## 6) Configure staging and production targets
The inventory file `ansible/hosts` includes both groups.

### Default demo inventory
- `[staging]` → `localhost`
- `[production]` → `localhost`

### Real target example
Replace with actual hostnames or IPs:

```ini
[staging]
staging.example.com ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[production]
production.example.com ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

## 7) Prepare environments with Ansible
Run this first to prepare the target hosts:

```bash
ansible-playbook -i ansible/hosts ansible/setup_basics_playbook.yaml
```

What it does:
- installs common packages on Debian/Ubuntu hosts
- ensures SSH is running on supported systems
- creates a `deployer` user on Linux hosts
- writes a simple server info file

## 8) Deploy staging with Ansible

### Before deployment: verify the current state
Check what containers exist before you deploy. This ensures you understand what will be replaced.

```bash
docker ps -a --filter name=staging
```

You should see running staging containers, or see old ones that will be replaced.

Optionally, if you want to inspect a running staging container before redeploying:

```bash
docker ps -a --filter name=backend-staging
docker exec -it backend-staging /bin/bash
# Inside the container, you can inspect files and processes
# Type 'exit' to leave the container
```

**Note:** `docker exec -it` enters an existing running container. `docker run -it` would try to create a NEW container from an image (which doesn't exist locally).

If you have old containers running, the Ansible playbook will remove them automatically.

### Deploy using locally built images

```bash
ansible-playbook -i ansible/hosts ansible/deploy_stack_playbook.yaml -e target=staging
```

### Deploy staging from Docker Hub

```bash
ansible-playbook -i ansible/hosts ansible/deploy_stack_playbook.yaml -e target=staging -e dh_user=YOURNAME
```

### Deploy staging with a specific IP address (optional)

To bind the staging containers to a specific IP address instead of localhost, edit `ansible/deploy_stack_playbook.yaml` and modify the `published_ports` section.

**Before (default — uses localhost):**
```yaml
published_ports:
  - "{{ api_port }}:8000"
```

**After (bind to a specific IP):**
```yaml
published_ports:
  - "192.168.1.100:{{ api_port }}:8000"
  - "192.168.1.100:{{ ui_port }}:8501"
```

Replace `192.168.1.100` with your host's actual IP address (find it with `ifconfig` or `hostname -I`).

Then deploy as usual:

```bash
ansible-playbook -i ansible/hosts ansible/deploy_stack_playbook.yaml -e target=staging
```

### After deployment: verify the deployment

1. Check that new staging containers are running:

```bash
docker ps -a --filter name=staging
```

You should see:
- `backend-staging` — running, with port `8001:8000` mapped
- `frontend-staging` — running, with port `8501:8501` mapped

2. Inspect the backend container to verify it started correctly:

```bash
docker logs backend-staging
```

Look for messages like "Application startup complete" or "listening on 0.0.0.0:8000".

3. Inspect the frontend container:

```bash
docker logs frontend-staging
```

Look for Streamlit startup messages.

4. Verify backend responds:

```bash
curl -sS http://localhost:8001/ || echo "backend did not respond"
```

5. Verify the frontend UI responds:

```bash
curl -sS http://localhost:8501/ | head -n 10
```

6. Open the app in your browser:

```text
http://localhost:8501
```

7. Enter the running backend container and verify the environment and files:

```bash
docker exec -it backend-staging /bin/bash
# Inside the container, you can run commands:
env | grep -E 'PATH|PYTHONPATH|API'
ls -la /app
exit
```

If the frontend loads, both endpoints respond, and you see the expected logs and files, staging deployment is successful.

## 9) Deploy production with Ansible
Deploy production with its separate ports and container names.

### Before deployment: verify the current state

Check for any existing production containers:

```bash
docker ps -a --filter name=production
```

If old production containers are running, the playbook will remove them.

### Deploy production using Ansible

```bash
ansible-playbook -i ansible/hosts ansible/deploy_stack_playbook.yaml -e target=production -e dh_user=YOURNAME
```

Production ports:
- backend-production → `8002`
- frontend-production → `8502`

### After deployment: verify production is running

1. Check containers are up:

```bash
docker ps -a --filter name=production
```

You should see:
- `backend-production` — running, port `8002:8000` mapped
- `frontend-production` — running, port `8502:8501` mapped

2. Inspect backend logs:

```bash
docker logs backend-production
```

3. Inspect frontend logs:

```bash
docker logs frontend-production
```

4. Verify backend responds:

```bash
curl -sS http://localhost:8002/ || echo "production backend did not respond"
```

5. Verify frontend responds:

```bash
curl -sS http://localhost:8502/ | head -n 10
```

6. Open the app in your browser:

```text
http://localhost:8502
```

7. Inspect running container files:

```bash
docker exec -it backend-production env
docker exec -it backend-production ls -la /app
```

If the UI loads, endpoints respond, and logs show no errors, production is deployed successfully.

## 10) More Ansible deployment details
The deploy playbook:
- removes existing target containers
- creates `appnet-<target>` Docker network
- runs backend and frontend containers with correct networking
- sets `API_URL` inside frontend
- performs health checks on the internal network and public ports

Use `-e dh_user=YOURNAME` when you want Ansible to pull registry images instead of using local ones.

## 11) End-to-end CI/CD workflow with Jenkins

This is where the full automation comes together. Every time you commit and push code, Jenkins automatically:
1. **Detects the change** (via GitHub polling)
2. **Checks out the code**
3. **Builds both Docker images** (backend + frontend)
4. **Tests the images**
5. **Pushes to Docker Hub**
6. **Ansible can then deploy** the published images to staging/production

### Start Jenkins with docker compose

Jenkins is included in `docker-compose.yml`. Start it with:

```bash
docker compose up -d
```

This starts:
- Your backend on `localhost:8000`
- Your frontend on `localhost:8501`
- **Jenkins on `localhost:8080`** ← the CI/CD server

### Access Jenkins for the first time

1. Open `http://localhost:8080` in your browser
2. Get the admin password:

```bash
docker logs jenkins | grep -i "password"
```

You'll see something like:
```
Please use the following password to proceed to installation: a1b2c3d4e5f6g7h8i9j0k1l2
```

3. Copy the password, paste it into the unlock form
4. Click **Install suggested plugins** (wait a few minutes)
5. Create your first admin user

### Set up Jenkins for this repo

After unlock and plugin installation:

1. Click **Create a job**
2. Enter job name: `student-app-pipeline`
3. Select **Pipeline**
4. Click **OK**
5. Under **Pipeline**, select **Pipeline script from SCM**
6. Select **Git** as SCM
7. Enter your repo URL:
   - If public: `https://github.com/YOUR_USERNAME/Lesson11-C270-Jenkins-Docker-Ansible`
   - If private: Use GitHub personal access token (PAT) in credentials
8. Set **Script Path** to `Jenkinsfile` (default)
9. Under **Build Triggers**, check **Poll SCM**
10. Set schedule to `H/2 * * * *` (polls every ~2 minutes for changes)
11. Click **Save**

### Configure Docker Hub credentials in Jenkins

The Jenkinsfile needs your Docker Hub username and password to push images.

1. In Jenkins, go to **Manage Jenkins** → **Manage Credentials**
2. Click **System** → **Global credentials**
3. Click **Add Credentials**
4. Select **Username with password**
5. Fill in:
   - **Username:** your Docker Hub username
   - **Password:** your Docker Hub access token (or password)
   - **ID:** `dockerhub` ← must match the Jenkinsfile
6. Click **Create**

### Update the Jenkinsfile for your Docker Hub username

Edit the `Jenkinsfile` in the repo root:

```groovy
environment {
    DOCKER_USER    = 'your-dockerhub-username'          // <-- CHANGE TO YOUR USERNAME
    BACKEND_IMAGE  = "${DOCKER_USER}/student-backend"
    FRONTEND_IMAGE = "${DOCKER_USER}/student-frontend"
    TAG            = "${BUILD_NUMBER}"
}
```

Replace `your-dockerhub-username` with your actual Docker Hub username.

Commit and push this change:

```bash
git add Jenkinsfile
git commit -m "Update Jenkins with Docker Hub username"
git push origin main
```

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
