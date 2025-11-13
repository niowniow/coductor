FROM ghcr.io/swissdatasciencecenter/renku/py-basic-vscodium:2.10.0

# 1. Switch to root to install packages
USER root

# 2. Install dependencies (as root)
RUN apt-get update && apt-get install -y \
    openssh-server \
    openssh-client \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 3. Copy your wrapper script
COPY entrypoint-wrapper.sh /entrypoint-wrapper.sh

# 4. Make the script executable
RUN chmod +x /entrypoint-wrapper.sh

# 5. Add iroh-ssh for Linux
RUN wget https://github.com/rustonbsd/iroh-ssh/releases/download/0.2.7/iroh-ssh.linux
RUN chmod +x iroh-ssh.linux
RUN mv iroh-ssh.linux /usr/local/bin/iroh-ssh

# 6. Switch to the 'renku' user and configure userspace openssh-server
USER renku

# 7. Create the SSH directory structure and set permissions
RUN mkdir -p /home/renku/.config/user_sshd && \
    chmod 700 /home/renku/.config

# 8. Generate the userspace host keys
RUN ssh-keygen -f /home/renku/.config/user_sshd/ssh_host_ed25519_key -N "" -t ed25519

# 9. Create the userspace sshd_config file using absolute paths
RUN printf "%s\n" \
    "Port 2222" \
    "HostKey /home/renku/.config/user_sshd/ssh_host_ed25519_key" \
    "PasswordAuthentication no" \
    "PubkeyAuthentication yes" \
    "AuthorizedKeysFile /home/renku/.ssh/authorized_keys" \
    "UsePAM no" \
    > /home/renku/.config/user_sshd/sshd_config


# 10. Switch back to the original user 
USER renku

# 11. Set wrapper as the new ENTRYPOINT
ENTRYPOINT ["/entrypoint-wrapper.sh"]
