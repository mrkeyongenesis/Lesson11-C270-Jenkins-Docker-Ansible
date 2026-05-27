FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install SSH server, Docker, and Python support needed by Ansible target hosts.
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server docker.io python3 python3-pip && \
    python3 -m pip install --no-cache-dir docker && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd && \
    ssh-keygen -A

# Configure SSH: allow root login with a password (lab only)
RUN echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22

RUN cat > /start.sh <<'EOF'
#!/bin/sh
set -e

dockerd --host=unix:///var/run/docker.sock --storage-driver=vfs &

# Wait for the daemon to become available
for i in $(seq 1 30); do
  if docker version >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

exec /usr/sbin/sshd -D
EOF
RUN chmod +x /start.sh

CMD ["/start.sh"]
