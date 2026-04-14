#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Define key paths
KEY_DIR="/home/renku/.config/user_sshd"
KEY_FILE="${KEY_DIR}/ssh_host_ed25519_key"

# Check if the host key file is missing
if [ ! -f "$KEY_FILE" ]; then
    echo "--- No SSH host keys found, generating new ones... ---"    
    ssh-keygen -f "$KEY_FILE" -N "" -t ed25519
    echo "--- Host keys generated. ---"
else
    echo "--- Found existing SSH host keys. ---"
fi

# Define source and destination paths
SOURCE_DIR="/secrets"
DEST_DIR="$HOME/.ssh"

# --- Ensure .ssh directory exists and is secure ---
# Create the .ssh directory if it doesn't exist
mkdir -p "$DEST_DIR"
# Set strict permissions on the directory
chmod 700 "$DEST_DIR"

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

# --- File: iroh_secret ---
SOURCE_FILE="$SOURCE_DIR/iroh_secret"

if [ -f "$SOURCE_FILE" ]; then
    echo "Found iroh_secret key, setting..."
    export IROH_SECRET=$(cat "$SOURCE_FILE")
fi

DEST_DIR="$HOME/.config/opencode/"
mkdir -p "$DEST_DIR"

cat <<EOF > "${DEST_DIR}/opencode.json"
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-gemini-auth@latest"]
}
EOF



DEST_DIR="$HOME/.local/share/opencode/"
mkdir -p "$DEST_DIR"

# --- File: opencode_auth ---
SOURCE_FILE="$SOURCE_DIR/opencode_auth"
DEST_FILE="$DEST_DIR/auth.json"

if [ -f "$SOURCE_FILE" ]; then
    echo "Found opencode_auth, copying to $DEST_FILE..."
    cp "$SOURCE_FILE" "$DEST_FILE"
else
    echo "WARNING: No opencode_auth file found at $SOURCE_FILE. Opencode auth will not be configured."
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

echo "SSH secret configuration complete."

echo "Starting sshd service..."

# Start the sshd daemon in the background
/usr/sbin/sshd -D -f ~/.config/user_sshd/sshd_config &

/usr/local/bin/iroh-ssh server --ssh-port 2222 --persist &

# Set PI_CODING_AGENT_DIR to store pi config in /home/renku/work
export PI_CODING_AGENT_DIR=/home/renku/work/.pi/agent

echo "Executing original entrypoint: /cnb/process/ttyd"
exec /cnb/process/ttyd "$@"
