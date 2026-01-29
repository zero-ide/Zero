# IDE-11: Build & Run System

## 🎯 Goal
Implement a build and execution system that allows users to run their code inside the Docker container and see the output in real-time.

## 📋 Requirements

### 1. UI Changes
- **Toolbar**: Add a "Run" button (▶️) and "Stop" button (⏹️).
- **Bottom Panel**: Add a collapsible "Terminal" or "Output" view to display stdout/stderr.
- **Status Bar**: Show "Running...", "Build Succeeded", or "Failed" status.

### 2. Execution Logic
- **Strategy 1: Dockerfile (Priority)**
  - If a `Dockerfile` exists in the root, build it and use it as the execution environment.
  - Useful for projects with custom dependencies.
- **Strategy 2: Auto-Detect (Zero Config)**
  - If no `Dockerfile`, detect the language and use a pre-defined lightweight image.
  - **Swift**: `swift run` (swift:5.9-alpine)
  - **Node.js**: `npm start` or `node index.js` (node:20-alpine)
  - **Python**: `python3 main.py` (python:3.11-alpine)
  - **Java**: `javac *.java && java Main` (openjdk:21-alpine)
  - **Go**: `go run .` (golang:1.21-alpine)
- **Custom Command**: Allow users to edit the run command (optional for v1).

### 3. Docker Integration
- Use `docker exec` to run commands inside the container.
- Stream output (stdout/stderr) back to the UI.
- Handle process termination (Stop button).

## 🏗 Architecture

### `ExecutionService`
- Manages the execution lifecycle.
- Connects to `DockerService` to run commands.
- Publishes output streams to `AppState`.

### `OutputView`
- A scrollable text view at the bottom of the editor.
- Supports ANSI color codes (optional, but good for readability).

## 📅 Plan
1. **Phase 1**: UI Implementation (Toolbar, Bottom Panel)
2. **Phase 2**: `ExecutionService` & Docker Integration
3. **Phase 3**: Language Detection & Testing
