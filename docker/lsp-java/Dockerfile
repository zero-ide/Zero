# Java LSP Container
# Eclipse JDT Language Server with WebSocket bridge

FROM eclipse-temurin:21-jdk-alpine

# Install required packages
RUN apk add --no-cache \
    curl \
    jq \
    nodejs \
    npm

# Download Eclipse JDT Language Server
WORKDIR /lsp
RUN curl -L -o jdt-language-server-latest.tar.gz \
    https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz && \
    tar -xzf jdt-language-server-latest.tar.gz && \
    rm jdt-language-server-latest.tar.gz

# Install WebSocket bridge for LSP
WORKDIR /lsp/bridge
RUN npm init -y && \
    npm install ws vscode-languageserver-protocol

# Copy bridge script
COPY lsp-bridge.js /lsp/bridge/

# Expose WebSocket port
EXPOSE 8080

# Start LSP with WebSocket bridge
WORKDIR /workspace
CMD ["node", "/lsp/bridge/lsp-bridge.js"]
