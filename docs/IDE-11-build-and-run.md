# IDE-11: Build & Run System

## 🎯 Goal
Implement a build and execution system that allows users to run their code inside the Docker container and see the output in real-time.

## 📋 Requirements

### 1. UI Changes
- **Toolbar**: Add a "Run" button (▶️) and "Stop" button (⏹️).
- **Bottom Panel**: Add a collapsible "Terminal" or "Output" view to display stdout/stderr.
- **Status Bar**: Show "Running...", "Build Succeeded", or "Failed" status.

### 2. Execution Logic
- **Language Detection**: Automatically detect the run command based on the project structure.
  - Swift: `swift run`
  - Node.js: `npm start` or `node index.js`
  - Python: `python3 main.py`
  - Java: `javac *.java && java Main`
  - Go: `go run .`
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
