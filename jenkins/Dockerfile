# ============================================================
#  Custom Jenkins image for the Student App CI/CD lesson.
#
#  Compared to the stock jenkins/jenkins:lts image, this adds:
#   1. Docker CLI          → so pipeline stages can run `docker build/run/push`
#                            against the host daemon (docker.sock is mounted
#                            by docker-compose.yml)
#   2. Ansible + community.docker → so the "Deploy via Ansible" stage works
#   3. All required plugins pre-installed (see plugins.txt)
#   4. Setup wizard disabled — Jenkins is configured automatically at boot
#      by Configuration as Code (see casc/jenkins.yaml)
#
#  Built automatically by:  docker compose up -d --build jenkins
# ============================================================
FROM jenkins/jenkins:lts-jdk17

USER root

# --- Docker CLI (talks to the host daemon via the mounted socket) ---
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg python3 python3-pip \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli \
 && rm -rf /var/lib/apt/lists/*

# --- Ansible + Docker SDK (used by the "Deploy via Ansible" stage) ---
RUN pip3 install --no-cache-dir --break-system-packages ansible docker requests \
 && ansible-galaxy collection install community.docker -p /usr/share/ansible/collections

ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections

# --- Plugins (pre-installed so no manual plugin setup is needed) ---
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# --- Skip the interactive setup wizard; JCasC configures everything ---
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Teaching simplification: run as root so the jenkins process can always
# use the mounted /var/run/docker.sock. In production, add the jenkins
# user to the docker group instead.
USER root
