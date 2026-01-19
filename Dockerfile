FROM ghcr.io/swissdatasciencecenter/renku/py-basic-ttyd:2.10.0

# 1. Switch to root to install packages
USER root

# 2. Install dependencies (as root)
RUN apt-get update && apt-get install -y \
    openssh-server \
    openssh-client \
    wget \
    ca-certificates curl gnupg \
    && rm -rf /var/lib/apt/lists/*


# 2. Add NodeSource repository for Node 20
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# 3. Install Node.js and Gemini CLI
RUN apt-get update && apt-get install -y nodejs && \
    npm install -g @google/gemini-cli
ENV GEMINI_CONFIG_DIR=/home/renku/work/.config/


# 3. Copy your wrapper script
COPY entrypoint-wrapper.sh /entrypoint-wrapper.sh

# 4. Make the script executable
RUN chmod +x /entrypoint-wrapper.sh

# 5. Add iroh-ssh for Linux
ENV IROH_SSH_SHA256="cbd4055fff9caa3b9513a02b8ab45bf06d81229f6aead843da003168029075ab"
RUN wget https://github.com/rustonbsd/iroh-ssh/releases/download/0.2.7/iroh-ssh.linux && \
    echo "${IROH_SSH_SHA256}  iroh-ssh.linux" | sha256sum -c - && \
    chmod +x iroh-ssh.linux && \
    mv iroh-ssh.linux /usr/local/bin/iroh-ssh


# 5. Add dumbpipe for Linux
ENV DUMBPIPE_SHA256="a422cf76030d0240891505211297f3f5b6937d20b0329fbc5cccd3a0461f8ace"
RUN curl -sL https://github.com/n0-computer/dumbpipe/releases/download/v0.33.0/dumbpipe-v0.33.0-linux-x86_64.tar.gz | tar xz && \
    # echo "${DUMBPIPE_SHA256}  dumbpipe-v0.33.0-linux-x86_64.tar.gz" | sha256sum -c - && \
    chmod +x dumbpipe && \
    mv dumbpipe /usr/local/bin/dumbpipe

# 5. Add dumbpipe for Linux
RUN wget https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 && \
    chmod +x ttyd.x86_64 && \
    mv ttyd.x86_64 /usr/local/bin/ttyd-coductor
    
# 6. Switch to the 'renku' user and configure userspace openssh-server
USER renku

# 7. Create the SSH directory structure and set permissions
RUN mkdir -p /home/renku/.config/user_sshd && \
    chmod 700 /home/renku/.config

# 8. Create the userspace sshd_config file using absolute paths
RUN printf "%s\n" \
    "Port 2222" \
    "HostKey /home/renku/.config/user_sshd/ssh_host_ed25519_key" \
    "PasswordAuthentication no" \
    "PubkeyAuthentication yes" \
    "AuthorizedKeysFile /home/renku/.ssh/authorized_keys" \
    "UsePAM no" \
    > /home/renku/.config/user_sshd/sshd_config

# 9. Switch back to the original user 
USER renku

# 10. Set wrapper as the new ENTRYPOINT
ENTRYPOINT ["/entrypoint-wrapper.sh"]
