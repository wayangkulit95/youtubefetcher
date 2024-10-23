#!/bin/bash

# Variables
PROJECT_DIR="youtube-live-stream-fetcher"
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

# Create app.js
echo "Creating app.js..."
cat << 'EOF' > $APP_FILE
const express = require('express');
const fetch = require('node-fetch');
const sqlite3 = require('sqlite3').verbose();
const bodyParser = require('body-parser');
const session = require('express-session');

// Initialize the database
const db = new sqlite3.Database('./streams.db', (err) => {
    if (err) {
        console.error('Could not open database', err.message);
    } else {
        db.run(`CREATE TABLE IF NOT EXISTS streams (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            url TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )`);
        db.run(`CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL
        )`);
    }
});

const app = express();
const port = 2000; // Port for the application

// Middleware
app.use(bodyParser.json());
app.use(express.static('public'));
app.use(session({
    secret: 'your_secret_key', // Change this to a secure secret
    resave: false,
    saveUninitialized: true
}));

// Function to fetch DASH URL
async function dashUrl(ytUrl) {
    const response = await fetch(ytUrl);
    const text = await response.text();
    const match = text.match(/(?<=dashManifestUrl":").+?(?=",)/g);
    return match ? match[0] : null;
}

// Function to fetch HLS URL
async function hlsUrl(ytUrl) {
    const response = await fetch(ytUrl);
    const text = await response.text();
    const match = text.match(/(?<=hlsManifestUrl":").*\.m3u8/g);
    return match ? match[0] : null;
}

// Endpoint to fetch URLs
app.post('/fetch-urls', (req, res) => {
    if (!req.session.user) {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    const { url, name } = req.body;

    (async () => {
        try {
            const dash = await dashUrl(url);
            const hls = await hlsUrl(url);

            // Save to database
            db.run(`INSERT INTO streams (name, url) VALUES (?, ?)`, [name, url]);

            res.json({ dash, hls });
        } catch (error) {
            res.status(500).json({ error: 'Unable to fetch URLs.' });
        }
    })();
});

// Endpoint to get all stored streams
app.get('/streams', (req, res) => {
    if (!req.session.user) {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    db.all(`SELECT * FROM streams`, [], (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json(rows);
    });
});

// Route for serving HLS stream
app.get('/hls/:name.m3u8', (req, res) => {
    const name = req.params.name;

    db.get(`SELECT url FROM streams WHERE name = ?`, [name], (err, row) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        if (row) {
            const hlsUrl = row.url; // Assuming this URL is already the HLS URL
            res.redirect(hlsUrl);
        } else {
            res.status(404).json({ error: 'Stream not found' });
        }
    });
});

// Serve the login page
app.get('/login', (req, res) => {
    res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Login</title>
    </head>
    <body>
        <h2>Login</h2>
        <form id="loginForm">
            <input type="text" id="username" placeholder="Username" required />
            <input type="password" id="password" placeholder="Password" required />
            <button type="submit">Login</button>
        </form>
        <div id="message"></div>
        <script>
            document.getElementById('loginForm').onsubmit = async (e) => {
                e.preventDefault();
                const response = await fetch('/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        username: document.getElementById('username').value,
                        password: document.getElementById('password').value,
                    }),
                });
                const data = await response.json();
                document.getElementById('message').innerText = data.message || data.error;
                if (response.ok) {
                    window.location.href = '/';
                }
            };
        </script>
    </body>
    </html>
    `);
});

// Handle login POST request
app.post('/login', (req, res) => {
    const { username, password } = req.body;

    db.get(`SELECT * FROM users WHERE username = ? AND password = ?`, [username, password], (err, row) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        if (row) {
            req.session.user = username; // Set session user
            return res.json({ message: 'Login successful' });
        } else {
            return res.status(401).json({ error: 'Invalid username or password' });
        }
    });
});

// Serve the main panel page
app.get('/', (req, res) => {
    if (!req.session.user) {
        return res.redirect('/login');
    }

    res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>YouTube Live Stream Panel</title>
        <style>
            body { font-family: Arial, sans-serif; }
            .container { max-width: 600px; margin: auto; padding: 20px; }
            input, button { width: 100%; margin: 10px 0; padding: 10px; }
            .output { margin-top: 20px; }
        </style>
    </head>
    <body>

    <div class="container">
        <h1>YouTube Live Stream URL Fetcher</h1>
        <input type="text" id="ytUrl" placeholder="Enter YouTube Channel or Video URL" />
        <input type="text" id="streamName" placeholder="Enter Stream Name" />
        <button id="fetchUrls">Fetch DASH and HLS URLs</button>
        
        <div class="output" id="output"></div>
    </div>

    <script>
        document.getElementById('fetchUrls').addEventListener('click', async () => {
            const ytUrl = document.getElementById('ytUrl').value;
            const streamName = document.getElementById('streamName').value;
            const outputDiv = document.getElementById('output');
            outputDiv.innerHTML = '';

            try {
                const response = await fetch('/fetch-urls', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ url: ytUrl, name: streamName }),
                });
                const data = await response.json();

                if (response.ok) {
                    outputDiv.innerHTML += \`<strong>DASH URL:</strong> <a href="\${data.dash}" target="_blank">\${data.dash}</a><br>\`;
                    outputDiv.innerHTML += \`<strong>HLS URL:</strong> <a href="\${data.hls}" target="_blank">\${data.hls}</a><br>\`;
                    outputDiv.innerHTML += \`<strong>Access Stream:</strong> <a href="/hls/\${streamName}.m3u8">/hls/\${streamName}.m3u8</a><br>\`;
                } else {
                    outputDiv.innerHTML = \`<strong>Error:</strong> \${data.error}\`;
                }
            } catch (error) {
                outputDiv.innerHTML = '<strong>Error:</strong> Unable to fetch URLs.';
            }
        });
    </script>
    </body>
    </html>
    `);
});

// Start the server
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
EOF

# Install necessary Node.js packages
echo "Installing necessary Node.js packages..."
npm init -y
npm install express node-fetch sqlite3 body-parser express-session

# Install PM2 for process management
echo "Installing PM2..."
sudo npm install -g pm2

# Start the application with PM2
echo "Starting the application with PM2..."
pm2 start $APP_FILE --name youtube-live-stream-fetcher
pm2 save
pm2 startup

echo "Installation complete. Access the application at http://<your-server-ip>:2000"
