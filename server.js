import { createServer } from 'http';
import { readFileSync, existsSync } from 'fs';
import { execSync } from 'child_process';
import { extname, join } from 'path';
import { networkInterfaces } from 'os';

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';
const PROJECT_DIR = new URL('.', import.meta.url).pathname;

function getLocalIP() {
    const nets = networkInterfaces();
    for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
            if (net.family === 'IPv4' && !net.internal) {
                return net.address;
            }
        }
    }
    return 'localhost';
}

const MIME_TYPES = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.mp3': 'audio/mpeg',
    '.json': 'application/json',
    '.md': 'text/markdown',
};

function buildHtml() {
    execSync('node build-html.js', { cwd: PROJECT_DIR });
}

function serveFile(res, filePath) {
    const fullPath = join(PROJECT_DIR, filePath);
    if (!existsSync(fullPath)) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Not found' }));
        return;
    }

    const ext = extname(fullPath);
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    const content = readFileSync(fullPath);
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(content);
}

const server = createServer(async (req, res) => {
    // CORS headers for local dev
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    // Serve static files
    let filePath = req.url === '/' ? 'morning_briefing.html' : req.url.slice(1);

    // Rebuild HTML on each page load to pick up latest content
    if (filePath === 'morning_briefing.html') {
        try {
            buildHtml();
        } catch (err) {
            console.error('Build failed:', err.message);
        }
    }

    serveFile(res, filePath);
});

server.listen(PORT, HOST, () => {
    const localIP = getLocalIP();
    console.log(`Morning Briefing server running:`);
    console.log(`  Local:   http://localhost:${PORT}`);
    console.log(`  Network: http://${localIP}:${PORT}  ← open this on your phone`);
});
