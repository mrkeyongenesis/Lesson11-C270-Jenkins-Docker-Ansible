# Build a CI/CD Pipeline with Jenkins in GitHub Codespaces

A complete, self-contained guide to building a sample Flask web app and running it through a full Jenkins CI/CD pipeline — **checkout → build → test → package & tag → push to Docker Hub → deploy** — that runs automatically whenever you change the code, then using **Ansible** to deploy the published image to a separate workstation, entirely inside a GitHub Codespace.

This adapts the Cisco DEVASC "Build a CI/CD Pipeline Using Jenkins" lab to Codespaces and extends it with container packaging, registry deployment, and Ansible-driven delivery (drawing on the Cisco Ansible labs). The key differences from the VM version are called out as **Codespaces notes** throughout.

> **Two ways to use this guide:**
> - **Learn the concepts step by step** with the simple Flask app in `jenkins-app/` (Parts 1–8 below). Best for understanding what a pipeline *is*.
> - **Use the real pipeline** for this repo's actual two-tier app: the repo root contains a ready-made **`Jenkinsfile`** that auto-builds and pushes *both* the FastAPI backend and Streamlit frontend images to Docker Hub on every commit. Once you understand the basics here, point a Jenkins **Pipeline → "Pipeline script from SCM"** job at your fork and it uses that `Jenkinsfile` directly — no copy-pasting. See "Using the repo Jenkinsfile" at the end of this guide.

---

## Prerequisites

- A GitHub Codespace with Docker available (see Step 0).
- The `gh` CLI (preinstalled in Codespaces).
- A GitHub **Personal Access Token (PAT)** with at least `repo` scope, used both for pushing over HTTPS and for Jenkins credentials. **Step 2 walks you through generating one.**
- A free **Docker Hub** account (hub.docker.com) for the pipeline's package/deploy stages. **Step 7 walks you through the access token.**

---

## Step 0: Confirm Docker Works

In your Codespace terminal:

```bash
docker --version && docker ps
```

> **Codespaces note:** If `docker ps` errors, your Codespace lacks Docker-in-Docker. Add the feature below to `.devcontainer/devcontainer.json`, then rebuild the container (Command Palette → **Rebuild Container**):
>
> ```json
> {
>   "features": {
>     "ghcr.io/devcontainers/features/docker-in-docker:2": {}
>   }
> }
> ```

---

## Step 1: Create the Sample Web App Files

You will create **5 files** inside a folder called `sample-app-lesson-10`. When you're done, the folder should look exactly like this:

```
sample-app-lesson-10/        <-- your project folder (in your home directory)
├── sample_app.py            <-- the Flask app
├── sample-app.sh            <-- the local build/run script
├── Dockerfile               <-- how to package the app into an image
├── templates/
│   └── index.html           <-- the web page
└── static/
    └── style.css            <-- the page styling
```

First, create the folder and the two subfolders, then move into the folder:

```bash
mkdir -p ~/sample-app-lesson-10/templates ~/sample-app-lesson-10/static
cd ~/sample-app-lesson-10
```

> **Tip:** After `cd ~/sample-app-lesson-10`, every file below is created **inside this folder**. Stay here for the rest of Step 1. You can create each file in the VS Code file explorer (right-click → New File) or with the terminal — just make sure each one lands at the path shown in the tree above.

### `sample_app.py`

A tiny Flask app on **port 5050** (Jenkins uses 8080, so the app must use a different port):

```python
from flask import Flask
from flask import request
from flask import render_template

sample = Flask(__name__)

@sample.route("/")
def main():
    return render_template("index.html")

if __name__ == "__main__":
    sample.run(host="0.0.0.0", port=5050)
```

### `templates/index.html`

```html
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body>
    <h1>You are calling me from {{ request.remote_addr }}</h1>
</body>
</html>
```

### `static/style.css`

```css
body {
    background-color: lightsteelblue;
    font-family: sans-serif;
    text-align: center;
}
```

### `sample-app.sh`

Builds and runs the app in Docker on port 5050:

```bash
#!/bin/bash
rm -rf tempdir
mkdir tempdir
mkdir tempdir/templates
mkdir tempdir/static
cp sample_app.py tempdir/.
cp -r templates/* tempdir/templates/.
cp -r static/* tempdir/static/.
echo "FROM python" >> tempdir/Dockerfile
echo "RUN pip install flask" >> tempdir/Dockerfile
echo "COPY ./static /home/myapp/static/" >> tempdir/Dockerfile
echo "COPY ./templates /home/myapp/templates/" >> tempdir/Dockerfile
echo "COPY sample_app.py /home/myapp/" >> tempdir/Dockerfile
echo "EXPOSE 5050" >> tempdir/Dockerfile
echo "CMD python3 /home/myapp/sample_app.py" >> tempdir/Dockerfile
cd tempdir
docker build -t sampleapp .
docker run -t -d -p 5050:5050 --name samplerunning sampleapp
docker ps -a
```

> **Note:** The `rm -rf tempdir` at the top (not in the original lab) lets the script run repeatedly without failing on an existing folder — important because Jenkins runs it on every build.

### `Dockerfile`

A real Dockerfile committed to the repo (the Jenkins pipeline in Step 7 builds from this directly, instead of generating one on the fly). Create it at the **root** of `sample-app-lesson-10`:

```dockerfile
FROM python
RUN pip install flask
COPY ./static /home/myapp/static/
COPY ./templates /home/myapp/templates/
COPY sample_app.py /home/myapp/
EXPOSE 5050
CMD python3 /home/myapp/sample_app.py
```

> This is the same recipe the `sample-app.sh` script writes into `tempdir/`, but kept as a permanent file so the pipeline (and anyone reading your repo) can see exactly how the app is packaged.

### Test it locally before bringing Jenkins in

```bash
bash ./sample-app.sh
```

Add port `5050` in the **PORTS** tab and open it. You should see the light-blue "You are calling me from..." page. Then clean up:

```bash
docker stop samplerunning && docker rm samplerunning
```

---

## Step 2: Push the App to GitHub

Jenkins downloads your code from GitHub, so your 4 files need to live in a GitHub repository. In this step you'll **create a new repo** and **upload your files** to it.

Make sure you're in your project folder first:

```bash
cd ~/sample-app-lesson-10
```

Now run these commands **one at a time** and read what each one does:

**1. Turn this folder into a Git repository:**

```bash
git init
```

**2. Create a new private repo on GitHub named `sample-app-lesson-10`.**

> **📌 Recommended for students:** Because the Codespaces built-in token often blocks `gh repo create` (see the error below), the most reliable approach is to **first create a Personal Access Token (PAT)**, then create the repo on the website and push using that token. This is the same token you'll reuse for Jenkins in Step 5, so create it now.

#### Step 2a — Generate a classic Personal Access Token (PAT)

1. Go to **github.com** and sign in.
2. Click your **profile photo** (top-right corner) → **Settings**.
3. In the left sidebar, scroll all the way down and click **Developer settings**.
4. Click **Personal access tokens** → **Tokens (classic)**.
5. Click **Generate new token** → **Generate new token (classic)**.
6. Fill in the form:
   - **Note:** a name you'll recognize, e.g. `jenkins-lab-token`
   - **Expiration:** choose a length that covers your lab (e.g. 30 days)
   - **Select scopes:** check the **`repo`** box (this auto-checks all sub-boxes under it). This is the only scope you need.
7. Scroll to the bottom and click **Generate token**.
8. **Copy the token immediately** and paste it somewhere safe. GitHub shows it **only once** — once you leave the page you cannot see it again, only regenerate it. The token starts with `ghp_...` — treat it like a password.

#### Step 2b — Create the empty repo on the website

1. Go to **github.com** → click the **+** (top-right corner) → **New repository**.
2. **Repository name:** `sample-app-lesson-10`
3. Set it to **Private**.
4. Do **NOT** check "Add a README," ".gitignore," or "license" — the repo must be **empty**, or your push will be rejected.
5. Click **Create repository**.

#### Step 2c — Link your local folder to the new repo

Back in your Codespace terminal (replace `<your-username>` with your case-sensitive GitHub username):

```bash
git remote add origin https://github.com/<your-username>/sample-app-lesson-10.git
```

Now continue with sub-step 3 below. When you reach the `git push` (sub-step 5), you'll enter your **username** and the **PAT** you just made as the password.

> **⚠️ Alternative — using `gh repo create` (only if your token has permission):**
> You can try the one-line CLI command instead of steps 2b–2c:
> ```bash
> gh repo create sample-app-lesson-10 --private --source=. --remote=origin
> ```
> If you get this error:
> ```
> GraphQL: <your-username> does not have the correct permissions to execute `CreateRepository` (createRepository)
> ```
> it means Codespaces' built-in token is scoped **only to the repo the Codespace was created from** and can't create new repos. Either use the website method above (steps 2a–2c), **or** clear the built-in token and log in fresh:
> ```bash
> unset GITHUB_TOKEN
> unset GH_TOKEN
> gh auth login --scopes repo
> gh auth setup-git
> gh repo create sample-app-lesson-10 --private --source=. --remote=origin --push
> ```
> During login pick **GitHub.com → HTTPS → Yes → Login with a web browser** and paste the one-time code. The `--push` flag uploads your files immediately, so you can then skip to "Verify it worked."

**3. Stage all your files** (the `.` means "everything in this folder" — all 4 files plus the `templates/` and `static/` folders):

```bash
git add .
```

Check what will be uploaded (optional but recommended):

```bash
git status
```

You should see your files listed in green under "Changes to be committed":

```
new file:   Dockerfile
new file:   sample-app.sh
new file:   sample_app.py
new file:   static/style.css
new file:   templates/index.html
```

**4. Save a snapshot of your files with a message:**

```bash
git commit -m "Initial sample app on port 5050"
```

**5. Upload (push) your files to GitHub:**

```bash
git push -u origin main
```

### If you are asked for a username and password

When your push prompts you for a username and password (this happens when pushing over HTTPS), **do NOT type your GitHub account password** — GitHub no longer accepts it. Use the **Personal Access Token (PAT)** you created in **Step 2a** as the password.

> If you skipped it, jump back to **Step 2a** and generate a classic PAT with the `repo` scope first.

#### Use the token when Git asks

When the push prompts you:

```
Username for 'https://github.com': <type your GitHub username>
Password for 'https://<username>@github.com': <paste your token here>
```

- **Username** = your GitHub username (case-sensitive)
- **Password** = paste the **token** (`ghp_...`), **not** your account password

> **Note:** When you paste the token, the terminal will **not** show any characters — that's normal for password fields. Just paste and press **Enter**.

If everything is correct, your files upload successfully.

### Verify it worked

Open your repo in the browser to confirm the files are there:

```bash
gh repo view --web
```

You should see all 4 files and your "Initial sample app on port 5050" commit message.

> **Codespaces note:** The `gh` CLI is preinstalled and already signed in, so this push needs **no Personal Access Token**. Also note your default branch is **main** (not `master`) — you'll need this name later when you set up the Jenkins build job.
>
> **Heads up:** Do **not** commit the `tempdir/` folder (the build script creates it). If it appeared from your local test, remove it first with `rm -rf tempdir` before `git add .`, or it'll get uploaded too.

---

## Step 3: Pull and Run Jenkins

Pull the image:

```bash
docker pull jenkins/jenkins:lts
```

Run it (single line):

```bash
docker run --rm -u root -p 8080:8080 \
  -v jenkins-data:/var/jenkins_home \
  -v /usr/bin/docker:/usr/bin/docker \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HOME":/home \
  --name jenkins_server jenkins/jenkins:lts
```

**Option breakdown:**

| Option | Purpose |
|--------|---------|
| `--rm` | Removes the container when stopped |
| `-u root` | Runs as root so Docker commands inside Jenkins are permitted |
| `-p 8080:8080` | Exposes Jenkins on port 8080 |
| `-v jenkins-data:/var/jenkins_home` | Persists Jenkins data |
| `-v /usr/bin/docker:/usr/bin/docker` | Gives Jenkins the Docker binary |
| `-v /var/run/docker.sock:/var/run/docker.sock` | Lets Jenkins talk to Docker |
| `-v "$HOME":/home` | Mounts your home directory |

> **Codespaces note:** The `-v /usr/bin/docker:/usr/bin/docker` mount assumes Docker's binary lives at that path. Confirm with `which docker` first and substitute if it differs, or Docker commands inside Jenkins will fail.

Get the admin password from a **second terminal**:

```bash
docker exec -it jenkins_server cat /var/jenkins_home/secrets/initialAdminPassword
```

In the **PORTS** tab, open the forwarded URL for port `8080`. Paste the password → **Install suggested plugins** → **Skip and continue as admin** → **Save and Finish** → **Start using Jenkins**.

---

## Step 4: Find Your Gateway IP

The test job curls the app over the Docker bridge. Find the real gateway:

```bash
docker network inspect bridge | grep Gateway
```

Use that value wherever this guide writes `<GATEWAY-IP>` below. It may be `172.17.0.1`, but **don't assume** — a wrong IP is the #1 cause of test failures.

---

## Step 5: BuildAppJob (the Build)

> **Optional warm-up.** Steps 5 and 6 build the freestyle Build and Test jobs from the original lab — useful for understanding the basics. If you want to go straight to the full automated pipeline, you can skip to **Step 7**, which does build, test, package, push, and deploy all in one job.

1. **New Item** → name `BuildAppJob` → **Freestyle project** → **OK**.
2. **General**: add a description like "Builds the sample app."
3. **Source Code Management → Git**, Repository URL:
   ```
   https://github.com/<your-username>/sample-app-lesson-10.git
   ```
4. **Credentials → Add → Jenkins**: enter your GitHub **username** and **Personal Access Token** as the password, click **Add**, then select it from the dropdown. (The red connection error clears once selected.)

   > **Note:** Jenkins can't reuse the Codespaces `gh` session, so it needs the PAT here. Use the **same `ghp_...` token you generated in Step 2** (or generate a new one the same way if it expired).
5. **Branch Specifier**: set to `*/main`.
6. **Build Steps → Add build step → Execute shell**:
   ```bash
   bash ./sample-app.sh
   ```
7. **Save** → **Build Now**.
8. Open the build number under **Build History → Console Output**. Look for `Successfully tagged sampleapp:latest` and `Finished: SUCCESS`.

To verify the app, add port `5050` in the **PORTS** tab and open it.

---

## Step 6: TestAppJob (the Test)

First clean up the running container:

```bash
docker stop samplerunning && docker rm samplerunning
```

1. **New Item** → name `TestAppJob` → **Freestyle project** → **OK**.
2. Add a description like "Tests the sample app build."
3. **Source Code Management**: leave as **None** (this job doesn't need the repo).
4. **Build Triggers**: check **Build after other projects are built**; in **Projects to watch**, enter `BuildAppJob`. This chains the test to run after every successful build.
5. **Build Steps → Add build step → Execute shell** (the `if ...; then` must be on one line):
   ```bash
   if curl http://<GATEWAY-IP>:5050/ | grep "You are calling me from"; then
     exit 0
   else
     exit 1
   fi
   ```
   > **Note:** The grep is trimmed to "You are calling me from" (without a specific IP) so it matches regardless of your gateway. Exit code `0` = pass, `1` = fail.
6. **Save**.
7. Trigger `BuildAppJob` again (clock/play icon). Both jobs' **Last Success** timestamps should update.
8. Open `TestAppJob` → **Permalinks → Last build → Console Output**. Success shows the `<h1>You are calling me from...</h1>` line, then `+ exit 0` and `Finished: SUCCESS`.

---

## Step 7: SamplePipeline (the full CI/CD Pipeline)

So far `BuildAppJob` and `TestAppJob` are separate freestyle jobs. Now you'll combine everything into **one declarative pipeline** that, on every code change, automatically:

```
Checkout → Build image → Test → Push to Docker Hub (tagged) → Deploy
```

### Step 7a — Generate a Docker Hub access token

Docker Hub is a public registry where your built images are stored so they can be pulled and run anywhere. The pipeline needs to log in to push images there. Logging in with your account password from a script is insecure, so Docker Hub gives you **access tokens** — revocable, scoped passwords meant exactly for this.

**First, make sure you have a Docker Hub account and remember your username:**

1. Go to **https://hub.docker.com** and sign in (or **Sign up** if you don't have an account — it's free).
2. Note your **Docker Hub username** (shown top-right). Every image you push is named `your-username/imagename`, so you'll need this exact username below.

**Now generate the access token:**

1. Click your **avatar** (top-right corner) → **Account settings**.
2. In the left menu, click **Personal access tokens**.
3. Click **Generate new token**.
4. Fill in the form:
   - **Access token description:** something you'll recognize, e.g. `jenkins-lesson-10`
   - **Expiration date:** pick a range that covers your lab (e.g. 30 days)
   - **Access permissions:** choose **Read & Write** (the pipeline needs to push, which requires write)
5. Click **Generate**.
6. **Copy the token immediately** and save it somewhere safe — Docker Hub shows it **only once**. It looks like `dckr_pat_xxxxxxxx`. Treat it like a password.

> Keep this token handy. You'll use it twice: once to practice a manual push in Step 7a-2, and again when you store it in Jenkins in Step 7b.

### Step 7a-2 (optional but recommended) — Practice a manual push first

Before letting Jenkins do it automatically, do one push by hand so you understand what the pipeline's "Push to Docker Hub" stage actually does. Run these in your Codespace terminal, replacing `<your-dockerhub-username>` each time.

**1. Log in to Docker Hub** (paste the `dckr_pat_...` token when asked for a password):

```bash
docker login -u <your-dockerhub-username>
```

You should see `Login Succeeded`.

**2. Build an image from your lesson-10 app** (run this from inside `~/sample-app-lesson-10`, which now contains the `Dockerfile`):

```bash
cd ~/sample-app-lesson-10
docker build -t <your-dockerhub-username>/sampleapp:manual .
```

> The `.` at the end means "build using the Dockerfile in the current folder." Since you committed a `Dockerfile` in Step 1, this just works.

**3. Tag explained:** the part after the colon (`:manual`) is the **tag** — a label for a specific version of the image. You can re-tag an existing image any time:

```bash
docker tag <your-dockerhub-username>/sampleapp:manual <your-dockerhub-username>/sampleapp:v1
```

**4. Push it to Docker Hub:**

```bash
docker push <your-dockerhub-username>/sampleapp:manual
```

**5. Verify:** refresh **hub.docker.com → Repositories**. You'll see a `sampleapp` repository with the `manual` tag. That's your image, now stored in the cloud — exactly what the pipeline will do automatically on every code change. You can clean up the local login with `docker logout`.

### Step 7b — Store your credentials in Jenkins

The pipeline can't type passwords interactively, so we save logins in Jenkins' encrypted credential store and reference each by an **ID**. You need **two** credentials: one for Docker Hub (to push images) and one for GitHub (to clone your **private** repo).

**Credential 1 — Docker Hub:**

1. In Jenkins, go to **Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**.
2. **Kind:** Username with password.
   - **Username:** your Docker Hub username
   - **Password:** the Docker Hub access token from Step 7a (the `dckr_pat_...` value)
   - **ID:** `dockerhub` (use **exactly** this — the pipeline references it by this ID)
   - **Description:** e.g. `Docker Hub login for lesson 10`
3. Click **Create**.

**Credential 2 — GitHub (for cloning the private repo):**

1. Click **Add Credentials** again.
2. **Kind:** Username with password.
   - **Username:** your GitHub username (case-sensitive, e.g. `mrkeyongenesis`)
   - **Password:** your GitHub **Personal Access Token** (`ghp_...`) — the classic token with `repo` scope from **Step 2a**. If it has expired, generate a fresh one the same way.
   - **ID:** `github-cred` (use **exactly** this — the pipeline references it by this ID)
   - **Description:** e.g. `GitHub login for lesson 10`
3. Click **Create**.

> **⚠️ This is the most common pipeline failure.** If the Checkout stage fails with:
> ```
> remote: Invalid username or token. Password authentication is not supported for Git operations.
> fatal: Authentication failed for 'https://github.com/.../sample-app-lesson-10.git/'
> ```
> it means either (a) the pipeline's `git` step is missing the `credentialsId: 'github-cred'` line (so Jenkins clones anonymously and your private repo refuses), or (b) the GitHub credential holds your account **password** instead of a **PAT**, or (c) the PAT expired. Fix the credential here, and make sure the `git` step in the script below includes `credentialsId: 'github-cred'`.

### Step 7c — Create the pipeline job

1. **New Item** → name `SamplePipeline` → **Pipeline** → **OK**.
2. Under **Build Triggers**, check **Poll SCM** and enter this schedule (checks GitHub every 2 minutes):
   ```
   H/2 * * * *
   ```
   > This is what makes it CI: whenever you push new code to GitHub, the next poll picks up the change and runs the whole pipeline automatically. (In production you'd use a GitHub **webhook** for instant triggering, but polling needs no public URL and works reliably in Codespaces.)
3. In the **Pipeline** section, set **Definition** to **Pipeline script** and paste the script below. **Edit the three lines marked `<-- CHANGE`** to use your Docker Hub username and your GitHub username:
   ```groovy
   pipeline {
       agent any

       environment {
           DOCKER_USER = 'your-dockerhub-username'                  // <-- CHANGE to your Docker Hub username
           IMAGE_NAME  = "${DOCKER_USER}/sampleapp"                 // image will be <user>/sampleapp
           IMAGE_TAG   = "${BUILD_NUMBER}"                          // unique tag per build (1, 2, 3, ...)
       }

       triggers {
           pollSCM('H/2 * * * *')
       }

       stages {
           stage('Checkout') {
               steps {
                   git branch: 'main',
                       url: 'https://github.com/your-github-username/sample-app-lesson-10.git',  // <-- CHANGE to your repo
                       credentialsId: 'github-cred'
               }
           }

           stage('Build') {
               steps {
                   echo "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}"
                   // Use the committed Dockerfile if present; otherwise create one so the build never fails.
                   sh '''
                     if [ ! -f Dockerfile ]; then
                       echo "No Dockerfile found in repo - generating one"
                       printf 'FROM python\\nRUN pip install flask\\nCOPY ./static /home/myapp/static/\\nCOPY ./templates /home/myapp/templates/\\nCOPY sample_app.py /home/myapp/\\nEXPOSE 5050\\nCMD python3 /home/myapp/sample_app.py\\n' > Dockerfile
                     fi
                   '''
                   sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest ."
               }
           }

           stage('Test') {
               steps {
                   echo 'Starting a temporary container and checking the app responds'
                   // Free port 5050: remove our test container AND any leftover deploy container.
                   sh 'docker rm -f testcontainer samplerunning 2>/dev/null || true'
                   // Belt and suspenders: kill anything else still publishing 5050.
                   sh 'docker ps -q --filter "publish=5050" | xargs -r docker rm -f || true'
                   sh "docker run -d -p 5050:5050 --name testcontainer ${IMAGE_NAME}:${IMAGE_TAG}"
                   sh 'sleep 5'
                   sh 'curl -s http://172.17.0.1:5050/ | grep "You are calling me from"'
                   sh "docker rm -f testcontainer"
               }
           }

           stage('Push to Docker Hub') {
               steps {
                   echo "Pushing ${IMAGE_NAME}:${IMAGE_TAG} and :latest"
                   withCredentials([usernamePassword(
                       credentialsId: 'dockerhub',
                       usernameVariable: 'DH_USER',
                       passwordVariable: 'DH_PASS')]) {
                       sh 'echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin'
                       sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                       sh "docker push ${IMAGE_NAME}:latest"
                   }
               }
           }

           stage('Deploy') {
               steps {
                   echo 'Running the image we just built as a local container'
                   // Free port 5050 before binding: remove old deploy/test containers and anything else on 5050.
                   sh 'docker rm -f samplerunning testcontainer 2>/dev/null || true'
                   sh 'docker ps -q --filter "publish=5050" | xargs -r docker rm -f || true'
                   sh "docker run -d -p 5050:5050 --name samplerunning ${IMAGE_NAME}:${IMAGE_TAG}"
                   sh 'docker ps --filter name=samplerunning'
               }
           }
       }

       post {
           always  { sh 'docker logout || true' }
           success { echo "✅ Deployed ${IMAGE_NAME}:${IMAGE_TAG} — app live on port 5050" }
           failure { echo '❌ Pipeline failed — check the stage logs above.' }
       }
   }
   ```
4. Click **Save** → **Build Now** for the first run.

> **⚠️ If the Build stage fails with:**
> ```
> unable to prepare context: unable to evaluate symlinks in Dockerfile path:
> lstat /var/jenkins_home/workspace/SamplePipeline/Dockerfile: no such file or directory
> ```
> It means there's **no `Dockerfile` in your repo** — `docker build .` looks for one in the cloned workspace and can't find it. The Build stage above now auto-generates a Dockerfile when it's missing, so updating your pipeline script to the version above fixes it immediately.
>
> **The cleaner permanent fix** is to commit the `Dockerfile` to your repo (as described in Step 1) so it's version-controlled:
> ```bash
> cd ~/sample-app-lesson-10
> # create the Dockerfile if you don't have one yet:
> printf 'FROM python\nRUN pip install flask\nCOPY ./static /home/myapp/static/\nCOPY ./templates /home/myapp/templates/\nCOPY sample_app.py /home/myapp/\nEXPOSE 5050\nCMD python3 /home/myapp/sample_app.py\n' > Dockerfile
> git add Dockerfile
> git commit -m "Add Dockerfile"
> git push
> ```
> After pushing, the next pipeline run will find the committed `Dockerfile` and use it.
>
> **About the `DEPRECATED: legacy builder` warning:** that line is harmless — Docker is just suggesting you install BuildKit/buildx. The build still works. You can ignore it for this lab.

### Understanding the pipeline structure

This is a **declarative pipeline** — Jenkins reads it top to bottom. Before the stages, here's what the building blocks mean:

- `pipeline { ... }` — wraps the whole definition.
- `agent any` — run on any available Jenkins worker (here, the Jenkins container itself).
- `environment { ... }` — variables reused across stages. `BUILD_NUMBER` is a built-in Jenkins variable that increases by 1 each run, which is why every build gets a unique image tag.
- `triggers { pollSCM('H/2 * * * *') }` — the CI trigger; Jenkins checks GitHub every ~2 minutes for new commits.
- `stages { stage('Name') { steps { ... } } }` — the work itself, split into named stages that show as boxes in the Stage View.
- `sh '...'` — runs a shell command. If any `sh` command returns a non-zero exit code, that stage **fails** and the pipeline stops — that's how the Test stage acts as a quality gate.
- `withCredentials([...])` — temporarily injects your stored `dockerhub` username/token as environment variables, only inside that block, so secrets never appear in logs.
- `post { ... }` — runs after all stages, regardless of outcome (`always`, `success`, `failure`).

### What each stage does

- **Checkout** — clones the latest `main` from your GitHub repo.
- **Build** — builds the image, tagging it **twice**: with the unique build number (`:1`, `:2`, ...) and with `:latest`. It uses the `Dockerfile` committed to your repo; if that file isn't in the repo, the stage generates one automatically so the build still succeeds. Tagging the same image with two names costs nothing and lets others pull either a specific version or "the newest."
- **Test** — runs the freshly built image in a throwaway container and `curl`s it to confirm the app responds, then removes that container. A failed check fails the whole pipeline (this is your CI gate) — so a broken build never gets pushed or deployed.
- **Push to Docker Hub** — logs in with your stored `dockerhub` credentials (via `withCredentials`) and pushes both tags. After this, your image lives on Docker Hub and could be pulled onto any machine.
- **Deploy** — runs the image we just built (the `:<build-number>` tag) as a local container named `samplerunning` on port 5050. Because it uses the exact image that passed the Test stage and was pushed to Docker Hub, you know the running app matches the published one.
- **post** — always logs out of Docker Hub; prints a clear success/failure message.

> **Gateway IP reminder:** the Test stage uses `172.17.0.1`. If your `docker network inspect bridge` (Step 4) showed a different gateway, change it in the `curl` line.

### Step 7d — See CI in action

1. Edit something visible — e.g. change the heading in `templates/index.html`.
2. Commit and push:
   ```bash
   git add . && git commit -m "Update heading" && git push
   ```
3. Within ~2 minutes the **Poll SCM** trigger detects the change and the pipeline runs on its own. Watch the **Stage View** light up green across all five stages.
4. Check **hub.docker.com** — you'll see a new tag appear for each build, and `:latest` updated.
5. Open port `5050` in the **PORTS** tab to see your deployed change live.

That's a complete CI/CD loop: **push code → auto build → auto test → auto package & tag → auto push to registry → auto deploy.**

---

## Using the repo Jenkinsfile (the real two-image pipeline)

The walkthrough above teaches the pipeline concepts with the simple `jenkins-app/` Flask app. To run CI/CD on this repo's **actual** app — the FastAPI backend + Streamlit frontend — use the ready-made **`Jenkinsfile`** in the repo root. It does the same build → test → push, but for **both** images at once, and it lives in version control instead of being pasted into the Jenkins UI.

**What it does, stage by stage:**

- **Checkout** — `checkout scm` pulls your repo (Jenkins knows the URL because the job is configured "from SCM").
- **Build Backend** — `docker build ./backend` → tags `student-backend:<build-number>` and `:latest`.
- **Build Frontend** — `docker build ./frontend` → tags `student-frontend:<build-number>` and `:latest`.
- **Test** — runs the backend in a throwaway container and curls `/` for the "Student API is running" message (the CI gate).
- **Push to Docker Hub** — logs in with the `dockerhub` credential and pushes all four tags (both images, build-number + latest).
- **Deploy (local smoke run)** — starts the two images together on `appnet` with `API_URL=http://backend:8000` to confirm the published stack actually runs.

**To set it up:**

1. Have Jenkins running (Parts 4–5 above) with Docker available inside it.
2. Add the **`dockerhub`** credential (Step 7b) — Docker Hub username + access token.
3. If your repo is private, add the **`github-cred`** credential (Step 7b) — GitHub username + PAT.
4. **New Item → Pipeline → OK.** Under **Pipeline**, set **Definition = Pipeline script from SCM**, **SCM = Git**, your repo URL, branch `main`, credentials `github-cred`. Leave **Script Path** as `Jenkinsfile`.
5. Edit the `DOCKER_USER` line at the top of `Jenkinsfile` to your Docker Hub username, commit, and push.
6. **Build Now.** Every future push triggers the pipeline (via `pollSCM`), rebuilding and pushing both images automatically.

After a successful run you'll have `student-backend:latest` and `student-frontend:latest` on Docker Hub — exactly what the Ansible guide deploys.

---

## Step 8: Deploy with Ansible (staging → production)

Once Jenkins is pushing both images to Docker Hub, the next step is delivering them to real machines across multiple environments using **Ansible**. That workflow — deploying the **FastAPI back-end** and **Streamlit front-end** wired together across **staging → production** — is covered in a separate guide:

➡️ **See [`ANSIBLE_DEPLOY.md`](./ANSIBLE_DEPLOY.md)**

It's self-contained (it can build and push its own two images), and reinforces the same Docker Hub + deployment concepts this pipeline establishes.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| `docker ps` fails | Docker-in-Docker not enabled — see Step 0. |
| `CreateRepository` permission error on `gh repo create` | Codespaces' built-in token is scoped to one repo only. Run `unset GITHUB_TOKEN GH_TOKEN`, then `gh auth login --scopes repo`, then `gh auth setup-git`, then retry (Step 2 callout). |
| Docker commands fail inside Jenkins | Wrong Docker binary path in the `-v` mount — check `which docker` (Step 3). |
| `TestAppJob` exits `1` but the app works in the browser | Wrong gateway IP — re-check `docker network inspect bridge` (Step 4). |
| Build can't reach the repo | Wrong branch (`*/main` vs `*/master`), wrong case-sensitive username, or missing/expired PAT. |
| `Bind for 0.0.0.0:5050 failed: port is already allocated` | A previous container (usually `samplerunning` from the Deploy stage) still holds port 5050. The Test/Deploy stages above now remove it first. To clear it by hand: `docker ps -q --filter publish=5050 \| xargs -r docker rm -f`. |
| Build stage: `Dockerfile: no such file or directory` | No `Dockerfile` in the cloned repo. Either update to the Build stage that auto-generates one, or commit a `Dockerfile` to the repo and push (Step 7c callout). |
| Pipeline Checkout fails: `Invalid username or token. Password authentication is not supported` | Private repo needs auth. Add a `github-cred` credential (GitHub username + PAT, **not** password) and ensure the `git` step has `credentialsId: 'github-cred'` (Step 7b). |
| `sample-app.sh` fails on second run | Make sure the `rm -rf tempdir` line is present, or stop/remove the `samplerunning` container. |
| Pipeline `docker push` fails with `denied` / `unauthorized` | Wrong Docker Hub credentials, or `IMAGE_NAME` doesn't start with your Docker Hub username. Check the `dockerhub` credential (Step 7b) and the `IMAGE_NAME` line. |
| Pipeline `docker login` fails | Use a Docker Hub **access token** (Read & Write) as the password, not your account password (Step 7a). |
| Pipeline doesn't auto-run after a push | Confirm **Poll SCM** is checked with `H/2 * * * *`, wait ~2 min, and make sure you pushed to the `main` branch. |
| Test stage fails but app builds | Gateway IP in the `curl` line is wrong, or the app needs more than 5s to start — increase `sleep`. |
| Port 8080 not forwarding | Add it manually in the **PORTS** tab. |

For Ansible deployment issues, see the troubleshooting section in [`ANSIBLE_DEPLOY.md`](./ANSIBLE_DEPLOY.md).

---

*Adapted from the Cisco DEVASC lab "Build a CI/CD Pipeline Using Jenkins" for the GitHub Codespaces environment.*
