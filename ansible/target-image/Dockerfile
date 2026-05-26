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
# Use a script to ensure both start properly with proper timing
RUN echo '#!/bin/bash\nservice docker start\nsleep 2\n/usr/sbin/sshd -D' > /start.sh && chmod +x /start.sh
CMD ["/start.sh"]
