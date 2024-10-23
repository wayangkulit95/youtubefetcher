const express = require('express');
const fetch = require('node-fetch');
const bodyParser = require('body-parser');
const app = express();
const port = 3000;

let youtubeUrls = [];

app.use(bodyParser.urlencoded({ extended: true }));

app.get('/', (req, res) => {
  res.send(`
    <h1>YouTube Live Stream Manager</h1>
    <form action="/add-url" method="POST">
      <input type="text" name="url" placeholder="YouTube Live URL" required>
      <button type="submit">Add URL</button>
    </form>
    <h2>Current URLs:</h2>
    <ul>
      ${youtubeUrls.map(url => `<li>${url}</li>`).join('')}
    </ul>
  `);
});

app.post('/add-url', (req, res) => {
  const url = req.body.url;
  if (youtubeUrls.indexOf(url) === -1) {
    youtubeUrls.push(url);
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
    res.redirect(url);
  } catch {
    res.status(500).send('Error fetching HLS URL');
  }
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
