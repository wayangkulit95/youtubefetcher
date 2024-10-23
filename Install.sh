#!/bin/bash

# Variables
PROJECT_DIR="yl"
DB_FILE="streams.db"
APP_FILE="app.js"
NODE_VERSION="16.x"

# Update and install required packages
echo "Updating package index..."
sudo apt update -y

# Install required packages for Debian 11
echo "Installing required packages..."
sudo apt install -y curl git build-essential

# Install Node.js
echo "Installing Node.js..."
curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js and npm installation
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "Node.js and npm installed successfully."
else
    echo "Node.js installation failed. Exiting."
    exit 1
fi

# Create project directory
echo "Creating project directory..."
mkdir $PROJECT_DIR
cd $PROJECT_DIR

# Download app.js
echo "Downloading app.js..."
curl -O https://raw.githubusercontent.com/wayangkulit95/youtubefetcher/main/app.js

# Install necessary Node.js packages
echo "Installing necessary Node.js packages..."
npm init -y
npm install express node-fetch sqlite3 body-parser express-session

# Install PM2 for process management
echo "Installing PM2..."
sudo npm install -g pm2

# Start the application with PM2
echo "Starting the application with PM2..."
pm2 start $APP_FILE --name yl
pm2 save
pm2 startup

echo "Installation complete. Access the application at http://<your-server-ip>:2000"
