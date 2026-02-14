FROM eclipse-temurin:21-jdk-alpine

RUN apk add --no-cache \
    curl \
    jq \
    nodejs \
    npm

WORKDIR /lsp
RUN curl -L -o jdt-language-server-latest.tar.gz \
    https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz && \
    tar -xzf jdt-language-server-latest.tar.gz && \
    rm jdt-language-server-latest.tar.gz

WORKDIR /lsp/bridge
RUN npm init -y && \
    npm install ws vscode-languageserver-protocol

COPY lsp-bridge.js /lsp/bridge/

EXPOSE 8080

WORKDIR /workspace
CMD ["node", "/lsp/bridge/lsp-bridge.js"]
