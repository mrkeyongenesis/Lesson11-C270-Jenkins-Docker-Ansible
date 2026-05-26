// ============================================================
//  Jenkinsfile — CI/CD for the two-tier Student app
//  Builds BOTH images (FastAPI backend + Streamlit frontend),
//  tests them, and pushes both to Docker Hub on every code change.
//
//  Setup in Jenkins (one-time):
//   1. Add a "Username with password" credential with ID 'dockerhub'
//      (your Docker Hub username + an access token).
//   2. Add a "Username with password" credential with ID 'github-cred'
//      (your GitHub username + a PAT) if the repo is private.
//   3. Create a Pipeline job → "Pipeline script from SCM" → point it at
//      this repo so it uses this Jenkinsfile.
//   4. Edit DOCKER_USER below to your Docker Hub username.
// ============================================================
pipeline {
    agent any

    environment {
        DOCKER_USER    = 'your-dockerhub-username'          // <-- CHANGE
        BACKEND_IMAGE  = "${DOCKER_USER}/student-backend"
        FRONTEND_IMAGE = "${DOCKER_USER}/student-frontend"
        TAG            = "${BUILD_NUMBER}"                   // unique tag per build
    }

    triggers {
        pollSCM('H/2 * * * *')   // check GitHub every ~2 min for new commits
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Backend') {
            steps {
                echo "Building ${BACKEND_IMAGE}:${TAG}"
                sh "docker build -t ${BACKEND_IMAGE}:${TAG} -t ${BACKEND_IMAGE}:latest ./backend"
            }
        }

        stage('Build Frontend') {
            steps {
                echo "Building ${FRONTEND_IMAGE}:${TAG}"
                sh "docker build -t ${FRONTEND_IMAGE}:${TAG} -t ${FRONTEND_IMAGE}:latest ./frontend"
            }
        }

        stage('Test') {
            steps {
                echo 'Smoke-testing the backend API in a throwaway container'
                // free port 8000 from any previous run
                sh 'docker ps -q --filter "publish=8000" | xargs -r docker rm -f || true'
                sh "docker rm -f apitest || true"
                sh "docker run -d -p 8000:8000 --name apitest ${BACKEND_IMAGE}:${TAG}"
                sh 'sleep 5'
                // the health-check route returns the running message
                sh 'curl -s http://172.17.0.1:8000/ | grep "Student API is running"'
                sh "docker rm -f apitest"
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo 'Pushing both images (build tag + latest)'
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS')]) {
                    sh 'echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin'
                    sh "docker push ${BACKEND_IMAGE}:${TAG}"
                    sh "docker push ${BACKEND_IMAGE}:latest"
                    sh "docker push ${FRONTEND_IMAGE}:${TAG}"
                    sh "docker push ${FRONTEND_IMAGE}:latest"
                }
            }
        }

        stage('Deploy (local smoke run)') {
            steps {
                echo 'Running the freshly built stack locally to confirm it works'
                sh 'docker network create appnet || true'
                sh 'docker rm -f backend frontend || true'
                sh 'docker ps -q --filter "publish=8501" | xargs -r docker rm -f || true'
                sh "docker run -d --name backend  --network appnet -p 8000:8000 ${BACKEND_IMAGE}:${TAG}"
                sh "docker run -d --name frontend --network appnet -e API_URL=http://backend:8000 -p 8501:8501 ${FRONTEND_IMAGE}:${TAG}"
                sh 'docker ps --filter name=backend --filter name=frontend'
            }
        }
    }

    post {
        always  { sh 'docker logout || true' }
        success { echo "✅ Built & pushed ${BACKEND_IMAGE}:${TAG} and ${FRONTEND_IMAGE}:${TAG}. UI on :8501, API on :8000." }
        failure { echo '❌ Pipeline failed — check the stage logs above.' }
    }
}
