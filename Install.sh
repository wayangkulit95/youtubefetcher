#!/bin/bash

# Exit on error
set -e

# Update package list and install necessary packages
echo "Updating package list..."
sudo apt update

echo "Installing Node.js and npm..."
sudo apt install -y nodejs npm

# Create project directory
PROJECT_DIR="ytl"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Creating project directory: $PROJECT_DIR"
    mkdir "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# Initialize a new Node.js project
echo "Initializing Node.js project..."
npm init -y

# Install dependencies
echo "Installing required dependencies..."
npm install express node-fetch body-parser

# Create app.js file
echo "Creating app.js..."
cat <<EOL > app.js
const express = require('express');
const fetch = require('node-fetch');
const bodyParser = require('body-parser');
const fs = require('fs');
const app = express();
const port = 3000;
const urlFilePath = './youtubeUrls.json';

// Load existing URLs from file
let youtubeUrls = [];
if (fs.existsSync(urlFilePath)) {
  youtubeUrls = JSON.parse(fs.readFileSync(urlFilePath));
}

app.use(bodyParser.urlencoded({ extended: true }));

app.get('/', (req, res) => {
  res.send(\`
    <h1>YouTube Live Stream Manager</h1>
    <form action="/add-url" method="POST">
      <input type="text" name="url" placeholder="YouTube Live URL" required>
      <button type="submit">Add URL</button>
    </form>
    <h2>Current URLs:</h2>
    <ul>
      \${youtubeUrls.map((url, index) => \`<li>\${url} <a href="/stream/\${index}/master.m3u8">Export M3U8</a></li>\`).join('')}
    </ul>
  \`);
});

app.post('/add-url', (req, res) => {
  const url = req.body.url;
  if (!youtubeUrls.includes(url)) {
    youtubeUrls.push(url);
    fs.writeFileSync(urlFilePath, JSON.stringify(youtubeUrls, null, 2)); // Save URLs to file
  }
  res.redirect('/');
});

async function dashUrl(ytUrl) {
  const response = await fetch(ytUrl);
  const text = await response.text();
  const match = text.match(/(?<=dashManifestUrl":").+?(?=",)/g);
  return match ? match[0] : null;
}

async function hlsUrl(ytUrl) {
  const response = await fetch(ytUrl);
  const text = await response.text();
  const match = text.match(/(?<=hlsManifestUrl":").*\.m3u8/g);
  return match ? match[0] : null;
}

app.get('/stream/:id/master.mpd', async (req, res) => {
  const ytUrl = youtubeUrls[req.params.id];
  if (!ytUrl) return res.status(404).send('Not Found');

  try {
    const url = await dashUrl(ytUrl);
    res.redirect(url);
  } catch {
    res.status(500).send('Error fetching DASH URL');
  }
});

app.get('/stream/:id/master.m3u8', async (req, res) => {
  const ytUrl = youtubeUrls[req.params.id];
  if (!ytUrl) return res.status(404).send('Not Found');

  try {
    const url = await hlsUrl(ytUrl);
    const response = await fetch(url);
    const m3u8Content = await response.text();
    res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
    res.send(m3u8Content);
  } catch {
    res.status(500).send('Error fetching HLS URL');
  }
});

app.listen(port, () => {
  console.log(\`Server running at http://localhost:\${port}\`);
});
EOL

# Create an empty JSON file for storing URLs
echo "Creating youtubeUrls.json file..."
echo "[]" > youtubeUrls.json

echo "Setup complete! You can start the server by running 'node app.js'."
