#!/bin/bash

# Update the system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install Node.js and npm
echo "Installing Node.js and npm..."
sudo apt install nodejs npm -y

# Check Node.js and npm installation
if command -v node >/dev/null 2>&1; then
    echo "Node.js installed successfully: $(node -v)"
else
    echo "Node.js installation failed. Please check the installation."
fi

if command -v npm >/dev/null 2>&1; then
    echo "npm installed successfully: $(npm -v)"
else
    echo "npm installation failed. Please check Node.js installation."
fi

# Navigate to your app's directory
APP_DIR="/root/ytl"  # Change to your desired application directory
mkdir -p "$APP_DIR"           # Create the app directory if it doesn't exist
cd "$APP_DIR"

# Download app.js
echo "Downloading app.js..."
curl -O https://raw.githubusercontent.com/wayangkulit95/youtubefetcher/refs/heads/main/app.js || { echo "Failed to download app.js"; }

# Create package.json
echo "Creating package.json..."
cat << 'EOF' > package.json
{
  "name": "yl",
  "version": "1.0.0",
  "description": "YouTube Live Stream URL Fetcher",
  "main": "app.js",
  "type": "module",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.17.3",
    "node-fetch": "^2.6.7",
    "sqlite3": "^5.0.2",
    "body-parser": "^1.19.0",
    "express-session": "^1.17.2"
  },
  "devDependencies": {
    "nodemon": "^2.0.15"
  },
  "author": "MTS",
  "license": "MIT"
}
EOF
# Install SQLite3
echo "Installing SQLite3..."
sudo apt install sqlite3 -y

# Install Node-Fetch
echo "Installing node-fetch..."
sudo apt install node-fetch -y\

# Install Express
echo "Installing express..."
sudo apt install express -y

# Install Body-Parser
echo "Installing body-parser..."
sudo apt install body-parser -y

# Install express-session
echo "Installing express-session..."
sudo apt install express-session -y

# Install PM2 to run the app 24/7
echo "Installing PM2..."
sudo npm install pm2 -g

# Set the system time zone to Malaysia time
echo "Setting the time zone to Malaysia (Asia/Kuala_Lumpur)..."
sudo timedatectl set-timezone Asia/Kuala_Lumpur

# Install necessary Node.js packages
echo "Installing necessary Node.js packages..."
npm install || { echo "Failed to install Node.js packages"; }

# Install PM2 for process management
echo "Installing PM2..."
sudo npm install -g pm2 || { echo "Failed to install PM2"; }

# Start the application with PM2
echo "Starting the application with PM2..."
pm2 start "$APP_FILE" --name yl || { echo "Failed to start the application"; }
pm2 save
pm2 startup

echo "Installation complete. Access the application at http://<your-server-ip>:2000"
