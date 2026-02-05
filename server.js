import { createServer } from 'http';
import { readFileSync, existsSync } from 'fs';
import { execSync, spawn } from 'child_process';
import { extname, join } from 'path';

const PORT = process.env.PORT || 3000;
const PROJECT_DIR = new URL('.', import.meta.url).pathname;

const MIME_TYPES = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.mp3': 'audio/mpeg',
    '.json': 'application/json',
    '.md': 'text/markdown',
};

let researchInProgress = false;

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

function runResearch() {
    return new Promise((resolve, reject) => {
        const scriptPath = join(PROJECT_DIR, 'update-briefing.sh');

        if (existsSync(scriptPath)) {
            const child = spawn('bash', [scriptPath], {
                cwd: PROJECT_DIR,
                env: { ...process.env, PATH: `/opt/homebrew/bin:/usr/local/bin:${process.env.PATH}` },
            });

            let stdout = '';
            let stderr = '';
            child.stdout.on('data', (data) => { stdout += data; });
            child.stderr.on('data', (data) => { stderr += data; });

            child.on('close', (code) => {
                if (code === 0) {
                    resolve(stdout);
                } else {
                    reject(new Error(`Research script exited with code ${code}: ${stderr}`));
                }
            });

            child.on('error', (err) => reject(err));
        } else {
            reject(new Error('update-briefing.sh not found'));
        }
    });
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

    // API: Run research
    if (req.method === 'POST' && req.url === '/api/research') {
        if (researchInProgress) {
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Research already in progress' }));
            return;
        }

        researchInProgress = true;
        console.log('Starting research...');

        try {
            const output = await runResearch();
            console.log('Research completed successfully');
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ status: 'ok', output }));
        } catch (err) {
            console.error('Research failed:', err.message);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: err.message }));
        } finally {
            researchInProgress = false;
        }
        return;
    }

    // API: Check research status
    if (req.method === 'GET' && req.url === '/api/research/status') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ inProgress: researchInProgress }));
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

server.listen(PORT, () => {
    console.log(`Morning Briefing server running at http://localhost:${PORT}`);
});
