#!/bin/bash

# Step 0: Check if required secrets exist
if [ -z "${RENKU_SECRETS_PATH:-}" ]; then
    echo "ERROR: \$RENKU_SECRETS_PATH is not defined, skipping SSH setup"
    exit 0
fi

SSH_FOLDER="${HOME}/.ssh"
KEYS_FOLDER="${RENKU_MOUNT_DIR}/.keys"
PI_AGENT_DIR="${RENKU_WORKING_DIR}/.pi/agent"
echo 'export PATH="$RENKU_WORKING_DIR/.local/bin:$PATH"' >> ~/.bashrc

# Step 1: Setup SSH directory structure
mkdir -p "${SSH_FOLDER}"
chmod 700 "${SSH_FOLDER}"

mkdir -p "${KEYS_FOLDER}"
chmod 700 "${KEYS_FOLDER}"


# Step 2: Setup SSH host key
HOST_KEY_FILE_SECRET="${RENKU_SECRETS_PATH}/ssh_host_ed25519_key"
HOST_KEY_FILE="${SSH_FOLDER}/ssh_host_ed25519_key"

echo ${RENKU_WORKING_DIR}
echo ${HOST_KEY_FILE} 

if [ -f "${HOST_KEY_FILE_SECRET}" ]; then
    cp "${HOST_KEY_FILE_SECRET}" "${HOST_KEY_FILE}"
    echo "" >> "${HOST_KEY_FILE}"  # Make sure the host key file ends with an empty line
    chmod 600 "${HOST_KEY_FILE}"
    echo "Using SSH host key from secrets"
fi

# Step 3: Setup authorized_keys for SSH
AUTHORIZED_KEYS_FILE="${SSH_FOLDER}/authorized_keys"
AUTHORIZED_KEYS_FILE_SECRET="${RENKU_SECRETS_PATH}/authorized_keys"

if [ -f "${AUTHORIZED_KEYS_FILE_SECRET}" ]; then
    cat "${AUTHORIZED_KEYS_FILE_SECRET}" > "${AUTHORIZED_KEYS_FILE}"
    echo "Populated ${AUTHORIZED_KEYS_FILE} from secrets"
fi

# Step 4: Setup sshd_config
SSHD_CONFIG="${SSH_FOLDER}/sshd_config"
cat >"${SSHD_CONFIG}" <<EOF 
Port                          2222
ListenAddress                 127.0.0.1
HostKey                       ${HOST_KEY_FILE}
AuthorizedKeysFile            ${AUTHORIZED_KEYS_FILE}
KbdInteractiveAuthentication  no
UsePAM                        yes
X11Forwarding                 yes
PrintMotd                     no
AcceptEnv                     LANG LC_*
PidFile                       /home/renku/sshd.pid
PermitRootLogin               no
PasswordAuthentication        no
EOF
chmod 600 "${SSHD_CONFIG}"

# Step 5: Start sshd daemon
SSHD="$(which sshd)"
"${SSHD}" -f "${SSHD_CONFIG}" -E /tmp/sshd.log
echo "Started sshd daemon"

# Step 6: Setup iroh-ssh (version 0.2.10)
BIN_FOLDER="${RENKU_MOUNT_DIR}/.local/bin"
IROH_SSH_BIN="${BIN_FOLDER}/iroh-ssh"
IROH_SSH_VERSION="0.2.10"
IROH_SSH_SHA256="2e8edc7d0868754486dc32052ce32aa67271729fd91c83c544a3e1ec4a06a7f1"

if [ -x "${IROH_SSH_BIN}" ]; then
    echo "Executable ${IROH_SSH_BIN} already present, skipping download"
else
    mkdir -p "${BIN_FOLDER}"
    curl -L -o "${IROH_SSH_BIN}" "https://github.com/rustonbsd/iroh-ssh/releases/download/${IROH_SSH_VERSION}/iroh-ssh.linux" 2>/dev/null
    chmod +x "${IROH_SSH_BIN}"
    echo "Downloaded iroh-ssh ${IROH_SSH_VERSION} to ${IROH_SSH_BIN}"
fi

echo "${IROH_SSH_SHA256}  ${IROH_SSH_BIN}" | sha256sum --check -
echo "iroh-ssh SHA256 verified"

# Step 7: Setup iroh-ssh persistent keys from secrets
IROH_PRIVATE_KEY="${SSH_FOLDER}/irohssh_ed25519"
IROH_PUBLIC_KEY="${SSH_FOLDER}/irohssh_ed25519.pub"
IROH_PRIVATE_KEY_SECRET="${RENKU_SECRETS_PATH}/irohssh_ed25519"
IROH_PUBLIC_KEY_SECRET="${RENKU_SECRETS_PATH}/irohssh_ed25519.pub"

if [ -f "${IROH_PRIVATE_KEY_SECRET}" ] && [ -f "${IROH_PUBLIC_KEY_SECRET}" ]; then
    cp "${IROH_PRIVATE_KEY_SECRET}" "${IROH_PRIVATE_KEY}"
    cp "${IROH_PUBLIC_KEY_SECRET}" "${IROH_PUBLIC_KEY}"
    chmod 600 "${IROH_PRIVATE_KEY}"
    chmod 600 "${IROH_PUBLIC_KEY}"
    echo "Using persistent iroh-ssh keys from secrets"
fi


# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"
# Download and install Node.js:
nvm install 24

# Step 8: Install pi coding agent
if ! command -v pi &> /dev/null; then
    echo "Installing pi coding agent..."
    npm install -g @mariozechner/pi-coding-agent
    echo "Installed pi coding agent"
else
    echo "pi coding agent already installed"
fi

# Step 9: Setup pi coding agent model configuration
mkdir -p "${PI_AGENT_DIR}"
MODELS_JSON="/workspace/source/models.json"
PI_MODELS_FILE="${PI_AGENT_DIR}/models.json"

if [ -f "${MODELS_JSON}" ]; then
    cp "${MODELS_JSON}" "${PI_MODELS_FILE}"
    echo "Setup pi coding agent models from ${MODELS_JSON}"
else
    echo "WARNING: models.json not found, pi coding agent will use default configuration"
fi

# Set PI_CODING_AGENT_DIR so it persists in sessions
echo "export PI_CODING_AGENT_DIR=/home/renku/work/.pi/agent" >> ~/.bashrc
PI_CODING_AGENT_DIR=/home/renku/work/.pi/agent pi install npm:pi-sandbox

cp /workspace/source/ocli-login.py $RENKU_WORKING_DIR/.local/bin/ocli-login
chmod +x $RENKU_WORKING_DIR/.local/bin/ocli-login

# Step 9: Setup ocli token from secrets
LLOCM_API_KEY_SECRET="${RENKU_SECRETS_PATH}/llmApiKey"
LLOCM_API_KEY_FILE="${KEYS_FOLDER}/llmApiKey"

if [ -f "${LLOCM_API_KEY_SECRET}" ]; then
    cp "${LLOCM_API_KEY_SECRET}" "${LLOCM_API_KEY_FILE}"
    chmod 600 "${LLOCM_API_KEY_FILE}"
    echo "Setup ocli API key from secrets"
fi

# Step 10: Print instructions
SSH_INSTRUCTIONS_FILE="${RENKU_WORKING_DIR}/ssh_instructions.md"
echo "# SSH instructions" > "${SSH_INSTRUCTIONS_FILE}"
echo "" >> "${SSH_INSTRUCTIONS_FILE}"
echo "To start iroh-ssh, run:"  | tee -a "${SSH_INSTRUCTIONS_FILE}"
echo "  ${IROH_SSH_BIN} server --persist --ssh-port 2222" | tee -a "${SSH_INSTRUCTIONS_FILE}"
echo "" >> "${SSH_INSTRUCTIONS_FILE}"
echo "For more information, see README.md" | tee -a "${SSH_INSTRUCTIONS_FILE}"

echo "SSH setup complete. See ${SSH_INSTRUCTIONS_FILE} for connection details."
