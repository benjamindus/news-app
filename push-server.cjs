#!/usr/bin/env node
// Simple push notification subscription server (HTTP)
// Vercel proxy handles SSL termination

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3001;
const subscriptionsFile = path.join(__dirname, 'subscriptions.json');

function loadSubscriptions() {
  try {
    if (fs.existsSync(subscriptionsFile)) {
      return JSON.parse(fs.readFileSync(subscriptionsFile, 'utf8'));
    }
  } catch (e) {
    console.error('Error loading subscriptions:', e);
  }
  return [];
}

function saveSubscriptions(subs) {
  fs.writeFileSync(subscriptionsFile, JSON.stringify(subs, null, 2));
}

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'POST' && req.url === '/subscribe') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const subscription = JSON.parse(body);
        const subs = loadSubscriptions();

        // Check if already subscribed (by endpoint)
        const exists = subs.some(s => s.endpoint === subscription.endpoint);
        if (!exists) {
          subs.push(subscription);
          saveSubscriptions(subs);
          console.log('New subscription added. Total:', subs.length);
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true }));
      } catch (e) {
        console.error('Error:', e);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid subscription' }));
      }
    });
    return;
  }

  if (req.method === 'GET' && req.url === '/vapid-key') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      publicKey: 'BODcbyNqGOZ7tKq89PVuHQycXdxNDq-HGQT4R-1VGzaPQJqxPzKA4TCno3tk2sI4YfRbaGt-W8B62qaQJv-33KY'
    }));
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Push subscription server running on HTTP port ${PORT}`);
});
