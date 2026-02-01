# Java LSP PoC

## Quick Start

### 1. Build LSP Docker Image
```bash
cd docker/lsp-java
docker build -t zero-lsp-java .
```

### 2. Start LSP Container
```bash
docker run -d \
    --name zero-lsp-java \
    -p 8080:8080 \
    -v /tmp/zero-lsp-workspace:/workspace \
    zero-lsp-java
```

### 3. Test WebSocket Connection
```bash
# Install wscat
npm install -g wscat

# Connect to LSP
wscat -c ws://localhost:8080

# Send initialize request
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":"file:///workspace","capabilities":{}}}
```

## Architecture

```
Zero IDE (SwiftUI + Monaco)
    ↓ WebSocket (ws://localhost:8080)
LSP Bridge (Node.js)
    ↓ stdio
Eclipse JDT Language Server
    ↓ Docker exec
Project Container (Alpine + JDK)
```

## Files

- `docker/lsp-java/Dockerfile` - LSP container definition
- `docker/lsp-java/lsp-bridge.js` - WebSocket ↔ LSP bridge
- `Sources/Zero/Services/LSPContainerManager.swift` - Swift LSP manager
- `Sources/Zero/Resources/monaco-lsp.html` - Monaco with LSP support

## Known Issues

1. **Large image size**: Eclipse JDT LS requires ~1GB
2. **Slow startup**: Initial download takes time
3. **Single language**: Currently Java only

## Next Steps

- [ ] Test with actual Java project
- [ ] Add Python LSP (Pyright)
- [ ] Optimize image size
- [ ] Add LSP status indicator in UI
