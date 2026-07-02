#!/bin/bash

LOCAL_DIR="$(pwd)/"
REMOTE_USER="ec2-user"
REMOTE_HOST="13.201.167.237"
REMOTE_DIR="/var/www/html"
SSH_KEY="D:/Learning/keys/linux-server.pem"

# Function to run a command with error checking
run_command() {
    if ! "$@"; then
        echo "Error: Command failed: $*"
        exit 1
    fi
}

# Ensure the remote directory exists and has correct permissions
echo "Setting up remote directory..."
run_command ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" "sudo mkdir -p $REMOTE_DIR && sudo chown -R $REMOTE_USER:$REMOTE_USER $REMOTE_DIR && sudo chmod -R 755 $REMOTE_DIR"

# Sync files
echo "Syncing files..."
run_command rsync -avz --chmod=D755,F644 -e "ssh -i $SSH_KEY" "$LOCAL_DIR" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"

# Set correct permissions after sync
echo "Setting final permissions..."
run_command ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" "sudo chown -R nginx:nginx $REMOTE_DIR && sudo chmod -R 755 $REMOTE_DIR"

echo "Deployment completed successfully!"