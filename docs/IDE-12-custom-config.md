# IDE-12: Custom Configuration (zero-ide.json)

## 🎯 Goal
Allow users to define custom build and run commands using a `zero-ide.json` file in the project root.

## 📋 Requirements

### 1. Configuration Schema (`zero-ide.json`)
```json
{
  "command": "npm run dev",      // Main run command
  "setup": "npm install",        // (Optional) Setup command to run before 'command'
  "image": "node:18-alpine"      // (Optional) Future support
}
```

### 2. Execution Logic Update
- **Priority 1**: `zero-ide.json` (If exists)
- **Priority 2**: `Dockerfile`
- **Priority 3**: Auto-Detect (Language based)

### 3. Implementation Details
- `ExecutionService` reads `zero-ide.json` using `cat`.
- Parse JSON using `Codable`.
- If `setup` command exists, run it first (and log "📦 Setting up...").
- Run `command`.

## 📅 Plan
1. Define `ZeroConfig` struct.
2. Update `ExecutionService.detectRunCommand` to check for `zero-ide.json`.
3. Implement `setup` command execution.
