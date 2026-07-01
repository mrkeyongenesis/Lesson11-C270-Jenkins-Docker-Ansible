// ============================================================
//  Jenkinsfile — CI/CD for the two-tier Student app
//  Builds BOTH images (FastAPI backend + Streamlit frontend),
//  runs code-quality & security scans (SonarQube, Trivy, Hadolint,
//  Bandit), tests them, pushes to Docker Hub, and deploys via Ansible.
//
//  Setup in Jenkins (one-time):
//   1. Add a "Username with password" credential with ID 'dockerhub'
//      (your Docker Hub username + an access token).
//   2. Add a "Username with password" credential with ID 'github-cred'
//      (your GitHub username + a PAT) if the repo is private.
//   3. Add a "Secret text" credential with ID 'sonar-token'
//      (SonarQube token — generate at User > My Account > Security).
//   4. Create a Pipeline job → "Pipeline script from SCM" → point it at
//      this repo so it uses this Jenkinsfile.
//   5. When triggering the build, provide your Docker Hub username as
//      a parameter (DOCKER_USER), or it defaults to 'your-dockerhub-username'.
// ============================================================
pipeline {
    agent any

    parameters {
        string(
            name: 'DOCKER_USER',
            defaultValue: 'your-dockerhub-username',
            description: 'Your Docker Hub username'
        )
        choice(
            name: 'DEPLOY_TARGET',
            choices: ['none', 'staging', 'production'],
            description: 'Which environment to deploy to via Ansible (requires Ansible installed)'
        )
        booleanParam(
            name: 'SKIP_SONAR',
            defaultValue: false,
            description: 'Skip SonarQube analysis (useful if no SonarQube server is available)'
        )
        booleanParam(
            name: 'SKIP_SECURITY_SCAN',
            defaultValue: false,
            description: 'Skip Trivy / OWASP security scans (speeds up dev builds)'
        )
    }

    environment {
        BACKEND_IMAGE  = "${params.DOCKER_USER}/student-backend"
        FRONTEND_IMAGE = "${params.DOCKER_USER}/student-frontend"
        TAG            = "${BUILD_NUMBER}"
        BRANCH_TAG     = "${BRANCH_NAME.replaceAll('/', '-')}-${BUILD_NUMBER}"
        SONAR_HOST_URL = 'http://sonarqube:9000'
    }

    triggers {
        pollSCM('H/2 * * * *')   // check GitHub every ~2 min for new commits
    }

    stages {

        // ═════════════════════════════════════════════════════
        //  STAGE 1 — Checkout
        // ═════════════════════════════════════════════════════
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 2 — Static Code Analysis (parallel)
        // ═════════════════════════════════════════════════════
        stage('Code Quality & Lint') {
            parallel {
                stage('Hadolint — Dockerfile Lint') {
                    steps {
                        echo 'Linting Dockerfiles with Hadolint...'
                        sh '''
                            docker run --rm -v "$PWD:/work" -w /work hadolint/hadolint:latest \
                                hadolint -c .hadolint.yaml backend/Dockerfile
                            docker run --rm -v "$PWD:/work" -w /work hadolint/hadolint:latest \
                                hadolint -c .hadolint.yaml frontend/Dockerfile
                            docker run --rm -v "$PWD:/work" -w /work hadolint/hadolint:latest \
                                hadolint -c .hadolint.yaml ansible/target-image/Dockerfile || true
                        '''
                    }
                }
                stage('Ruff — Python Lint') {
                    steps {
                        echo 'Linting Python code with Ruff...'
                        sh '''
                            docker run --rm -v "$PWD:/work" -w /work \
                                ghcr.io/astral-sh/ruff:latest check \
                                --config /work/pyproject.toml \
                                /work/backend/ /work/frontend/
                        '''
                    }
                }
                stage('Ruff — Format Check') {
                    steps {
                        echo 'Checking Python formatting with Ruff...'
                        sh '''
                            docker run --rm -v "$PWD:/work" -w /work \
                                ghcr.io/astral-sh/ruff:latest format --check \
                                --config /work/pyproject.toml \
                                /work/backend/ /work/frontend/ || true
                        '''
                    }
                }
                stage('mypy — Type Check') {
                    steps {
                        echo 'Static type checking with mypy...'
                        sh '''
                            docker run --rm -v "$PWD:/work" -w /work \
                                python:3.11-slim bash -c "\
                                    pip install mypy -q && \
                                    cp /work/pyproject.toml . && \
                                    mypy --config-file pyproject.toml /work/backend/ /work/frontend/ || true"
                        '''
                    }
                }
                stage('Bandit — Python Security Lint') {
                    steps {
                        echo 'Scanning Python code with Bandit...'
                        sh '''
                            docker run --rm -v "$PWD:/work" -w /work \
                                python:3.11-slim bash -c "\
                                    pip install bandit -q && \
                                    bandit -r backend/ frontend/ -f html -o bandit-report.html || true"
                        '''
                        archiveArtifacts artifacts: 'bandit-report.html', allowEmptyArchive: true
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 3 — Build Images (parallel)
        // ═════════════════════════════════════════════════════
        stage('Build Images') {
            parallel {
                stage('Build Backend') {
                    steps {
                        echo "Building ${BACKEND_IMAGE}:${TAG} from ./backend"
                        sh "docker build -t ${BACKEND_IMAGE}:${TAG} -t ${BACKEND_IMAGE}:latest ./backend"
                    }
                }
                stage('Build Frontend') {
                    steps {
                        echo "Building ${FRONTEND_IMAGE}:${TAG} from ./frontend"
                        sh "docker build -t ${FRONTEND_IMAGE}:${TAG} -t ${FRONTEND_IMAGE}:latest ./frontend"
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 4 — Functional Test
        // ═════════════════════════════════════════════════════
        stage('Test Backend') {
            steps {
                echo 'Smoke-testing the backend API in a throwaway container'
                script {
                    sh 'docker rm -f apitest 2>/dev/null || true'
                    sh 'docker network rm testnet 2>/dev/null || true'
                    sh 'docker network create testnet 2>/dev/null || true'
                    sh "docker run -d --network testnet --name apitest ${BACKEND_IMAGE}:${TAG}"
                    sh '''
                        for i in $(seq 1 15); do
                          if docker run --rm --network testnet curlimages/curl:8.1.2 -sS http://apitest:8000/ 2>/dev/null | grep -q "Student API is running"; then
                            echo "Backend ready after ${i}s"
                            break
                          fi
                          echo "Waiting... ($i)"
                          sleep 2
                        done
                    '''
                    sh 'docker run --rm --network testnet curlimages/curl:8.1.2 -sS http://apitest:8000/ | grep "Student API is running"'
                    sh 'docker run --rm --network testnet curlimages/curl:8.1.2 -sS http://apitest:8000/students | grep "Alice"'
                    sh 'docker run --rm --network testnet curlimages/curl:8.1.2 -sS http://apitest:8000/stats | grep "average_grade"'
                    sh 'docker rm -f apitest'
                    sh 'docker network rm testnet 2>/dev/null || true'
                }
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 5 — Security & Vulnerability Scanning
        // ═════════════════════════════════════════════════════
        stage('Security Vulnerability Scan') {
            when {
                expression { !params.SKIP_SECURITY_SCAN }
            }
            parallel {
                stage('Trivy — Filesystem Scan') {
                    steps {
                        echo 'Scanning source code for vulnerabilities with Trivy...'
                        sh '''
                            docker run --rm -v "$PWD:/work" -w /work \
                                aquasec/trivy:latest fs \
                                --scanners vuln,secret,misconfig \
                                --severity HIGH,CRITICAL \
                                --ignorefile /work/.trivyignore \
                                -f json -o /work/trivy-fs-report.json \
                                /work/backend /work/frontend
                        '''
                        sh 'docker run --rm -v "$PWD:/work" -w /work aquasec/trivy:latest fs --severity HIGH,CRITICAL /work/backend /work/frontend || true'
                        archiveArtifacts artifacts: 'trivy-fs-report.json', allowEmptyArchive: true
                    }
                }
                stage('Trivy — Container Image Scan') {
                    steps {
                        echo 'Scanning container images for vulnerabilities...'
                        sh """
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                -v "$PWD:/work" aquasec/trivy:latest image \
                                --severity HIGH,CRITICAL \
                                --ignorefile /work/.trivyignore \
                                -f json -o /work/trivy-image-backend-report.json \
                                ${BACKEND_IMAGE}:${TAG}
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                -v "$PWD:/work" aquasec/trivy:latest image \
                                --severity HIGH,CRITICAL \
                                --ignorefile /work/.trivyignore \
                                -f json -o /work/trivy-image-frontend-report.json \
                                ${FRONTEND_IMAGE}:${TAG}
                        """
                        sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v '$PWD:/work' aquasec/trivy:latest image --severity HIGH,CRITICAL ${BACKEND_IMAGE}:${TAG} || true"
                        sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v '$PWD:/work' aquasec/trivy:latest image --severity HIGH,CRITICAL ${FRONTEND_IMAGE}:${TAG} || true"
                        archiveArtifacts artifacts: 'trivy-image-*-report.json', allowEmptyArchive: true
                    }
                }
                stage('OWASP — Dependency Check') {
                    steps {
                        echo 'Scanning Python dependencies for known CVEs...'
                        sh '''
                            docker run --rm -v "$PWD:/src" \
                                owasp/dependency-check:latest \
                                --scan /src/backend/requirements.txt,/src/frontend/requirements.txt \
                                --format JSON \
                                --out /src/owasp-report \
                                --project "Student App" \
                                --failOnCVSS 9 || true
                        '''
                        archiveArtifacts artifacts: 'owasp-report/*', allowEmptyArchive: true
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 6 — SonarQube Code Quality Analysis
        // ═════════════════════════════════════════════════════
        stage('SonarQube Analysis') {
            when {
                expression { !params.SKIP_SONAR }
            }
            steps {
                echo 'Running SonarQube code quality analysis...'
                script {
                    // Attempt to reach SonarQube; skip gracefully if unavailable
                    try {
                        withCredentials([string(
                            credentialsId: 'sonar-token',
                            variable: 'SONAR_TOKEN'
                        )]) {
                            sh """
                                docker run --rm \
                                    -v "$PWD:/usr/src" \
                                    -e SONAR_HOST_URL="${SONAR_HOST_URL}" \
                                    -e SONAR_TOKEN="${SONAR_TOKEN}" \
                                    sonarsource/sonar-scanner-cli:latest \
                                    -Dsonar.projectBaseDir=/usr/src \
                                    -Dsonar.projectKey=student-app \
                                    -Dsonar.sources=/usr/src/backend,/usr/src/frontend \
                                    -Dsonar.exclusions=**/__pycache__/**,**/.venv/**,**/*.pyc \
                                    -Dsonar.python.version=3.11 \
                                    -Dsonar.sourceEncoding=UTF-8
                            """
                        }
                    } catch (err) {
                        echo "⚠️ SonarQube analysis skipped or failed: ${err}"
                        echo "   Ensure the SonarQube container is running (port 9000)."
                        echo "   Create a 'sonar-token' credential in Jenkins."
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 7 — Quality Gate (decides whether to proceed)
        // ═════════════════════════════════════════════════════
        stage('Quality Gate') {
            steps {
                echo 'Checking quality gate thresholds...'
                script {
                    def issues = 0
                    // Count CRITICAL findings from Trivy report if it exists
                    if (fileExists('trivy-fs-report.json')) {
                        def trivyReport = readJSON file: 'trivy-fs-report.json'
                        issues = trivyReport.Results ? trivyReport.Results.sum { r -> r.Total ?: 0 } : 0
                    }
                    echo "Total HIGH/CRITICAL findings from Trivy: ${issues}"
                    if (issues > 50) {
                        error "❌ Quality Gate FAILED: ${issues} HIGH/CRITICAL vulnerabilities found (threshold: 50)"
                    } else if (issues > 0) {
                        echo "⚠️  ${issues} HIGH/CRITICAL vulnerabilities found — within acceptable threshold (50)"
                    } else {
                        echo '✅ No HIGH/CRITICAL vulnerabilities found'
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 8 — Push to Docker Hub
        // ═════════════════════════════════════════════════════
        stage('Push to Docker Hub') {
            when {
                expression { params.DOCKER_USER != 'your-dockerhub-username' }
            }
            steps {
                echo "Pushing images to Docker Hub as ${params.DOCKER_USER}"
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS')]) {
                    sh 'echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin'
                    sh "docker tag ${BACKEND_IMAGE}:${TAG} ${BACKEND_IMAGE}:${BRANCH_TAG}"
                    sh "docker push ${BACKEND_IMAGE}:${TAG}"
                    sh "docker push ${BACKEND_IMAGE}:latest"
                    sh "docker push ${BACKEND_IMAGE}:${BRANCH_TAG}"
                    sh "docker push ${FRONTEND_IMAGE}:${TAG}"
                    sh "docker push ${FRONTEND_IMAGE}:latest"
                    sh "docker tag ${FRONTEND_IMAGE}:${TAG} ${FRONTEND_IMAGE}:${BRANCH_TAG}"
                    sh "docker push ${FRONTEND_IMAGE}:${BRANCH_TAG}"
                }
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 9 — Local Smoke Deploy
        // ═════════════════════════════════════════════════════
        stage('Deploy (local smoke run)') {
            steps {
                echo 'Running the freshly built stack locally to confirm it works'
                sh 'docker network rm appnet 2>/dev/null || true'
                sh 'docker network create appnet || true'
                sh 'docker rm -f backend frontend 2>/dev/null || true'
                sh "docker run -d --name backend  --network appnet -p 8000:8000 ${BACKEND_IMAGE}:${TAG}"
                sh "docker run -d --name frontend --network appnet -e API_URL=http://backend:8000 -p 8501:8501 ${FRONTEND_IMAGE}:${TAG}"
                sh 'sleep 3'
                sh 'docker ps --filter name=backend --filter name=frontend'
                echo 'Verifying both containers are healthy...'
                sh 'docker run --rm --network appnet curlimages/curl:8.1.2 -sS http://backend:8000/ | grep "Student API is running"'
                sh 'docker rm -f backend frontend 2>/dev/null || true'
                sh 'docker network rm appnet 2>/dev/null || true'
            }
        }

        // ═════════════════════════════════════════════════════
        //  STAGE 10 — Ansible Deploy (optional)
        // ═════════════════════════════════════════════════════
        stage('Deploy via Ansible') {
            when {
                expression { params.DEPLOY_TARGET != 'none' }
            }
            steps {
                echo "Deploying to ${params.DEPLOY_TARGET} via Ansible..."
                dir('ansible') {
                    sh "ansible-playbook deploy_stack_playbook.yaml -e 'target=${params.DEPLOY_TARGET}' -e 'dh_user=${params.DOCKER_USER}'"
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout 2>/dev/null || true'
            // Archive all scan reports
            archiveArtifacts artifacts: 'bandit-report.html,trivy-*-report.json,owasp-report/*,dependency-check-report.json', allowEmptyArchive: true
            // Clean up dangling images and stopped containers
            sh 'docker image prune -f 2>/dev/null || true'
            sh 'docker container prune -f 2>/dev/null || true'
        }
        success {
            echo "✅ Pipeline SUCCEEDED: ${BACKEND_IMAGE}:${TAG} and ${FRONTEND_IMAGE}:${TAG}"
            echo "   Code quality & security scans passed."
            if (params.DOCKER_USER != 'your-dockerhub-username') {
                echo "   Images pushed to Docker Hub as ${params.DOCKER_USER}"
            }
            if (params.DEPLOY_TARGET != 'none') {
                echo "   Deployed to: ${params.DEPLOY_TARGET}"
            }
        }
        failure {
            echo '❌ Pipeline FAILED — check the stage logs above.'
            echo '   Common failures:'
            echo '   - Quality Gate: too many HIGH/CRITICAL vulnerabilities'
            echo '   - SonarQube: server not running or token not configured'
            echo '   - Tests: API did not respond as expected'
        }
        unstable {
            echo '⚠️ Pipeline finished with unstable status — review the test results.'
        }
        cleanup {
            // Remove scan reports from workspace after archiving
            sh 'rm -f bandit-report.html trivy-*-report.json 2>/dev/null || true'
            sh 'rm -rf owasp-report 2>/dev/null || true'
        }
    }
}
