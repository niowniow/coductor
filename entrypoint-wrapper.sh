#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Define key paths
KEY_DIR="/home/renku/.config/user_sshd"
SSH_SERVER_KEY_FILE="${KEY_DIR}/ssh_host_ed25519_key"


# Define source and destination paths
SOURCE_DIR="/secrets"
DEST_DIR="$HOME/.ssh"

# --- Ensure .ssh directory exists and is secure ---
# Create the .ssh directory if it doesn't exist
mkdir -p "$DEST_DIR"
# Set strict permissions on the directory
chmod 700 "$DEST_DIR"


# --- File: ssh_host_ed25519_key ---
SOURCE_FILE="$SOURCE_DIR/ssh_host_ed25519_key"
DEST_FILE="$DEST_DIR/ssh_host_ed25519_key"

if [ -f "$SOURCE_FILE" ]; then
    echo "Found ssh_host_ed25519_key, copying..."
    cp "$SOURCE_FILE" "$DEST_FILE"
    chmod 600 "$DEST_FILE"
else
    echo "WARNING: No ssh_host_ed25519_key file found at $SOURCE_FILE."
fi

# --- File: authorized_keys ---
SOURCE_FILE="$SOURCE_DIR/authorized_keys"
DEST_FILE="$DEST_DIR/authorized_keys"

if [ -f "$SOURCE_FILE" ]; then
    echo "Found authorized_keys, copying..."
    cp "$SOURCE_FILE" "$DEST_FILE"
    chmod 600 "$DEST_FILE"
else
    echo "WARNING: No authorized_keys file found at $SOURCE_FILE."
fi

# --- File: irohssh_ed25519 (Private Key) ---
SOURCE_FILE="$SOURCE_DIR/irohssh_ed25519"
DEST_FILE="$DEST_DIR/irohssh_ed25519"

if [ -f "$SOURCE_FILE" ]; then
    echo "Found irohssh_ed25519 private key, copying..."
    cp "$SOURCE_FILE" "$DEST_FILE"
    chmod 600 "$DEST_FILE"
fi

# --- File: irohssh_ed25519 (Public Key) ---
SOURCE_FILE="$SOURCE_DIR/irohssh_ed25519.pub"
DEST_FILE="$DEST_DIR/irohssh_ed25519.pub"

if [ -f "$SOURCE_FILE" ]; then
    echo "Found irohssh_ed25519.pub public key, copying..."
    cp "$SOURCE_FILE" "$DEST_FILE"
    chmod 600 "$DEST_FILE"
fi


DEST_DIR="$HOME/.keys/"
mkdir -p "$DEST_DIR"

# --- File: llmApiKey  ---
SOURCE_FILE="$SOURCE_DIR/llmApiKey"
DEST_FILE="$DEST_DIR/llmApiKey"

if [ -f "$SOURCE_FILE" ]; then
    echo "Found llmApiKey , copying..."
    cp "$SOURCE_FILE" "$DEST_FILE"
    chmod 600 "$DEST_FILE"
fi

DEST_DIR="/home/renku/work/.pi/agent"
mkdir -p "$DEST_DIR"

# --- File: models.json pi ---
SOURCE_FILE="/models.json"
DEST_FILE="$DEST_DIR/models.json"

if [ -f "$SOURCE_FILE" ]; then
    echo "Found models.json, copying to $DEST_FILE..."
    cp "$SOURCE_FILE" "$DEST_FILE"
else
    echo "WARNING: No models.json file found at $SOURCE_FILE. pi agent models will not be configured."
fi


# Check if the host key file is missing
if [ ! -f "$SSH_SERVER_KEY_FILE" ]; then
    echo "--- No SSH host keys found, generating new ones... ---"    
    ssh-keygen -f "$SSH_SERVER_KEY_FILE" -N "" -t ed25519
    echo "--- Host keys generated. ---"
else
    echo "--- Found existing SSH host keys. ---"
fi

echo "SSH secret configuration complete."

echo "Starting sshd service..."

# Start the sshd daemon in the background
/usr/sbin/sshd -D -f ~/.config/user_sshd/sshd_config &

/usr/local/bin/iroh-ssh server --ssh-port 2222 --persist &

# Set PI_CODING_AGENT_DIR to store pi config in /home/renku/work
export PI_CODING_AGENT_DIR=/home/renku/work/.pi/agent

# Write PI_CODING_AGENT_DIR to .bashrc so it's available in SSH sessions
echo "export PI_CODING_AGENT_DIR=/home/renku/work/.pi/agent" >> ~/.bashrc

/home/renku/work/.venv/bin/pip install https://github.com/SwissDataScienceCenter/ocli/releases/download/v0.1.0/pyocli-0.1.0-cp310-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl


echo "Executing original entrypoint: /cnb/process/ttyd"
exec /cnb/process/ttyd "$@"
