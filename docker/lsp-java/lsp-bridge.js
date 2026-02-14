const WebSocket = require('ws');
const { spawn } = require('child_process');

const PORT = process.env.LSP_PORT || 8080;
const WORKSPACE = process.env.LSP_WORKSPACE || '/workspace';
const JDT_LS_HOME = '/lsp';
const JDT_LS_LAUNCHER = require('child_process')
    .execSync(`find ${JDT_LS_HOME} -name "org.eclipse.equinox.launcher_*.jar" | head -1`)
    .toString()
    .trim();

const lspProcess = spawn('java', [
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.level=ALL',
    '-noverify',
    '-Xmx1G',
    '-jar', JDT_LS_LAUNCHER,
    '-configuration', `${JDT_LS_HOME}/config_linux`,
    '-data', WORKSPACE
], {
    stdio: ['pipe', 'pipe', 'pipe']
});

const wss = new WebSocket.Server({ port: PORT });
let activeClient = null;
let buffer = '';
let contentLength = -1;

function sendToActiveClient(message) {
    if (!activeClient || activeClient.readyState !== WebSocket.OPEN) {
        return;
    }

    try {
        activeClient.send(JSON.stringify(message));
    } catch (_) {}
}

lspProcess.stdout.on('data', (data) => {
    buffer += data.toString();

    while (true) {
        if (contentLength === -1) {
            const headerEnd = buffer.indexOf('\r\n\r\n');
            if (headerEnd === -1) break;

            const header = buffer.substring(0, headerEnd);
            const match = header.match(/Content-Length: (\d+)/);
            if (!match) break;

            contentLength = parseInt(match[1]);
            buffer = buffer.substring(headerEnd + 4);
        }

        if (buffer.length >= contentLength) {
            const content = buffer.substring(0, contentLength);
            buffer = buffer.substring(contentLength);
            contentLength = -1;

            try {
                const message = JSON.parse(content);
                sendToActiveClient(message);
            } catch (_) {}
        } else {
            break;
        }
    }
});

wss.on('connection', (ws) => {
    if (activeClient && activeClient.readyState === WebSocket.OPEN) {
        try {
            activeClient.close(1012, 'Replaced by a newer editor session');
        } catch (_) {}
    }

    activeClient = ws;

    ws.on('message', (data) => {
        if (ws !== activeClient) {
            return;
        }

        try {
            const message = JSON.parse(data);
            const lspMessage = JSON.stringify(message) + '\r\n';
            const header = `Content-Length: ${Buffer.byteLength(lspMessage)}\r\n\r\n`;

            if (lspProcess.stdin.writable) {
                lspProcess.stdin.write(header + lspMessage);
            }
        } catch (_) {}
    });

    ws.on('close', () => {
        if (ws === activeClient) {
            activeClient = null;
        }
    });

    ws.on('error', () => {
        if (ws === activeClient) {
            activeClient = null;
        }
    });
});

lspProcess.stderr.on('data', () => {});

lspProcess.on('exit', (code) => {
    process.exit(code);
});
