#!/usr/bin/env node
/**
 * LSP WebSocket Bridge
 * Connects Monaco Editor (WebSocket) to Eclipse JDT Language Server (stdio)
 */

const WebSocket = require('ws');
const { spawn } = require('child_process');
const path = require('path');

const PORT = process.env.LSP_PORT || 8080;
const WORKSPACE = process.env.LSP_WORKSPACE || '/workspace';

// Find JDT Language Server
const JDT_LS_HOME = '/lsp';
const JDT_LS_LAUNCHER = require('child_process')
    .execSync(`find ${JDT_LS_HOME} -name "org.eclipse.equinox.launcher_*.jar" | head -1`)
    .toString()
    .trim();

console.log('🔧 LSP Bridge starting...');
console.log(`📁 Workspace: ${WORKSPACE}`);
console.log(`🚀 JDT Launcher: ${JDT_LS_LAUNCHER}`);

// Start JDT Language Server
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

console.log('✅ JDT Language Server started');

// Create WebSocket server
const wss = new WebSocket.Server({ port: PORT });

wss.on('connection', (ws) => {
    console.log('🔗 Client connected');
    
    // Forward messages from WebSocket to LSP
    ws.on('message', (data) => {
        try {
            const message = JSON.parse(data);
            const lspMessage = JSON.stringify(message) + '\r\n';
            const header = `Content-Length: ${Buffer.byteLength(lspMessage)}\r\n\r\n`;
            
            lspProcess.stdin.write(header + lspMessage);
        } catch (e) {
            console.error('❌ Invalid message:', e.message);
        }
    });
    
    // Forward messages from LSP to WebSocket
    let buffer = '';
    let contentLength = -1;
    
    lspProcess.stdout.on('data', (data) => {
        buffer += data.toString();
        
        while (true) {
            // Parse LSP header
            if (contentLength === -1) {
                const headerEnd = buffer.indexOf('\r\n\r\n');
                if (headerEnd === -1) break;
                
                const header = buffer.substring(0, headerEnd);
                const match = header.match(/Content-Length: (\d+)/);
                if (!match) break;
                
                contentLength = parseInt(match[1]);
                buffer = buffer.substring(headerEnd + 4);
            }
            
            // Parse LSP content
            if (buffer.length >= contentLength) {
                const content = buffer.substring(0, contentLength);
                buffer = buffer.substring(contentLength);
                contentLength = -1;
                
                try {
                    const message = JSON.parse(content);
                    ws.send(JSON.stringify(message));
                } catch (e) {
                    console.error('❌ Invalid LSP message:', e.message);
                }
            } else {
                break;
            }
        }
    });
    
    ws.on('close', () => {
        console.log('👋 Client disconnected');
    });
});

// Handle LSP process errors
lspProcess.stderr.on('data', (data) => {
    console.error('⚠️  LSP Error:', data.toString().substring(0, 200));
});

lspProcess.on('exit', (code) => {
    console.log(`💀 LSP process exited with code ${code}`);
    process.exit(code);
});

console.log(`🌐 WebSocket server listening on ws://localhost:${PORT}`);
console.log('⏳ Waiting for connections...');
