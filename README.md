# Static Site Server

A hands-on DevOps project demonstrating how to deploy and serve a static website on AWS EC2 using **Nginx** for web serving and **rsync** for fast, incremental file synchronization between a local development environment and a remote production server.

## Project Overview

This project covers the full lifecycle of deploying a static site to a cloud server:

- Provisioning a Linux server on AWS EC2 (free tier)
- Installing and configuring Nginx as the web server
- Building a local static site (HTML/CSS/images)
- Writing an automated `rsync`-based deployment script
- Optionally pointing a custom domain to the server

## Tech Stack

| Component | Purpose |
|---|---|
| **AWS EC2** | Remote Linux host (Amazon Linux 2/2023, t2.micro — free tier) |
| **Nginx** | Static file web server |
| **rsync** | Efficient, incremental file sync over SSH |
| **Bash** | Deployment automation script |

## Architecture

```
Local Machine (~/sitename)
        │
        │  rsync over SSH (deploy.sh)
        ▼
AWS EC2 Instance
        │
        ▼
/var/www/html  ──►  Nginx  ──►  Public Internet
```

## Setup Guide

### Step 1 — Launch an EC2 Instance

1. Log in to the AWS Console and open the **EC2 Dashboard**.
2. Click **Launch Instance** and assign a name (e.g. `devops-project`).
3. Choose an **Amazon Linux 2023** or **Amazon Linux 2** AMI (free tier eligible).
4. Select the **t2.micro** instance type (free tier eligible).
5. Create a new key pair, download it, and store it securely.
6. Configure the security group to allow **SSH (port 22)** from your IP.
7. Leave storage at the default 8 GB.
8. (Optional) Add tags, then launch the instance.

### Step 2 — Install and Configure Nginx

Connect to the instance:

```bash
ssh -i key-name.pem ec2-user@your-instance-ip
```

Update packages and install Nginx:

```bash
sudo yum update -y
sudo yum install nginx
```

Start Nginx and enable it on boot:

```bash
sudo systemctl start nginx
sudo systemctl enable nginx
```

Create the web root and set permissions:

```bash
sudo mkdir -p /var/www/html
sudo chown -R ec2-user:ec2-user /var/www/html
sudo chmod -R 755 /var/www/html
```

Update the Nginx config to point to the web root:

```bash
sudo nano /etc/nginx/nginx.conf
```

Inside the `server` block:

```nginx
root /var/www/html;
```

Save, exit, and restart Nginx:

```bash
sudo systemctl restart nginx
```

### Step 3 — Prepare the Static Site Locally

```bash
mkdir ~/sitename
cd ~/sitename
```

Add your HTML, CSS, and image files here.

### Step 4 — Automate Deployment with rsync

Create `deploy.sh` on your local machine:

```bash
#!/bin/bash

LOCAL_DIR="~/sitename/"
REMOTE_USER="ec2-user"
REMOTE_HOST="your-instance-ip"
REMOTE_DIR="/var/www/html"
SSH_KEY="location to your private key/key.pem"

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
```

> Replace `your-instance-ip` and `location to your private key/key.pem` with your actual EC2 public IP and key file path.

Make the script executable and run it:

```bash
chmod +x deploy.sh
./deploy.sh
```

### Step 5 — Point a Domain Name (Optional)

1. Register a domain name if you don't already have one.
2. In your registrar's DNS settings, create an **A record**:
   - **Type:** A
   - **Host:** `@` (or `www`)
   - **Value:** Your EC2 instance's public IP address
3. Wait for DNS propagation (usually minutes, up to 48 hours in some cases).

If you don't have a domain, the site is already accessible directly via the EC2 instance's public IP with the current Nginx configuration.

## What This Project Demonstrates

- Provisioning and securing a cloud VM on AWS
- Installing and configuring a production web server (Nginx)
- Building a repeatable, idempotent deployment workflow with `rsync` and Bash
- Basic error handling in shell scripting
- Fundamentals of DNS and domain routing
