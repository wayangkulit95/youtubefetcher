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
    res.send(`...`); // Your login HTML here
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

    res.send(`...`); // Your main panel HTML here
});

// Start the server
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
