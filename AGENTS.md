# AGENTS.md

This file is the operational guide for coding agents working in this repository.
Follow repository-specific behavior first, then general best practices.

## Project Snapshot

- Project type: Swift Package Manager executable app (`Zero`) with tests.
- Language/toolchain: Swift 5.9+ (repo target), currently builds on newer Swift too.
- Platform target: macOS 14+.
- Main code: `Sources/Zero/`
- Tests: `Tests/ZeroTests/`
- Packaging script: `scripts/build_dmg.sh`

## Source of Truth for Commands

Primary command references found in:

- `Package.swift`
- `README.md`
- `scripts/build_dmg.sh`

No CI workflow files were found in `.github/workflows/`.
No Makefile/justfile/Taskfile was found.

## Build, Run, and Test Commands

Run from repository root: `/Users/seungwon/Documents/Zero`

### Build

- Debug build: `swift build`
- Release build: `swift build -c release`
- Release build (explicit arch example): `swift build -c release --arch arm64`

### Run App

- Run app from SwiftPM: `swift run`

### Test

- Full test suite: `swift test`
- Verbose test output: `swift test -v`

### Single Test Execution (Important)

Use SwiftPM filter syntax:

- Run one test class: `swift test --filter CommandRunnerTests`
- Run one test method: `swift test --filter CommandRunnerTests/testExecuteEcho`
- Another method example: `swift test --filter AppStateTests/testLoadMore`

Notes:

- `--filter` is substring/regex-like matching; keep names specific to avoid extra matches.
- The filter string should match XCTest symbols as `TestClass/testMethod`.
- A concrete invocation has been validated in this repo:
  `swift test --filter CommandRunnerTests/testExecuteEcho`

### DMG Packaging

- Build and package DMG: `./scripts/build_dmg.sh`

Packaging caveats:

- Script auto-detects host arch (`arm64`/`x86_64`) and builds matching release output.
- Script defaults icon source to `Sources/Zero/Resources/AppIcon.iconset/icon_1024x1024.png` and can package without a custom icon when unavailable.
- Optional overrides are available via env vars: `ZERO_DMG_ARCH`, `ZERO_DMG_BUILD_DIR`, `ZERO_ICON_SOURCE`, `ZERO_DMG_DRY_RUN`.
- Script writes `Zero.entitlements` during execution.

## Lint / Formatting / Static Analysis

No dedicated linter/formatter config was found:

- No `.swiftlint.yml`
- No `.swiftformat`
- No `.editorconfig`

Agent guidance:

- Keep style consistent with neighboring files.
- Prefer small, targeted edits.
- Do not introduce a new formatter/linter unless explicitly requested.

## Code Organization

Top-level code structure under `Sources/Zero/`:

- `Views/` - SwiftUI UI screens and components.
- `Services/` - side effects, APIs, Docker, execution orchestration.
- `Models/` - Codable domain entities.
- `Core/` - process/command primitives.
- `Utils/` and `Helpers/` - utility wrappers and presentation helpers.
- `Constants.swift` - nested constants namespaces.

Tests mirror service/state behavior in `Tests/ZeroTests/`.

## Style Conventions (Observed)

### Imports

- Import only what the file needs.
- Common ordering: Apple/system modules first, third-party modules after.
- Avoid duplicate imports (one file currently has duplicate `import SwiftUI`; do not copy that pattern).

### Naming

- Types: UpperCamelCase (`AppState`, `GitHubService`, `SessionManager`).
- Variables/functions/properties: lowerCamelCase.
- Constants: grouped in nested enums (`Constants.Docker.baseImage`).
- Service-like objects use explicit suffixes (`*Service`, `*Manager`, `*Orchestrator`).

### Types and Modeling

- Prefer `struct` for models (`Repository`, `Organization`, `Session`).
- Use protocol-based abstraction for side-effect boundaries (`DockerServiceProtocol`, `CommandRunning`).
- Use explicit property types where clarity matters in stateful classes.

### SwiftUI and Concurrency

- `AppState` is `@MainActor` and `ObservableObject`; follow this pattern for shared UI state.
- Use `@Published` for observable mutable state.
- Use `Task {}` to bridge UI events to async work.
- Update UI-bound state on `MainActor` when called from async/background code.

### Error Handling

- Prefer `do/try/catch` over silent failure.
- Surface meaningful error text (`error.localizedDescription`) in UI/state.
- In services, throw typed/domain errors where possible.
- Avoid empty `catch` blocks.

### Testing Style

- Use XCTest with `@testable import Zero`.
- Test names use `test...` with descriptive suffixes.
- Many tests follow `// Given`, `// When`, `// Then` sections.
- Use lightweight mocks/fakes by conforming to protocols or subclassing services.
- For focused iteration, run single tests with `swift test --filter ...`.

## Architectural Patterns to Preserve

- Keep orchestration logic in services, not in views.
- Keep view code mostly declarative; push imperative side effects into helpers/services.
- Keep request construction separate from fetch/parse when practical (`createFetch...Request` pattern).
- Keep persistence and external I/O behind dedicated manager/service types.

## Agent Execution Guidelines for This Repo

- Read related files before editing; this codebase is small but stateful.
- Prefer minimal changes that match current architecture.
- Do not mix broad refactors into bug fixes.
- When adding new features, add/update tests in `Tests/ZeroTests/` when feasible.
- If introducing new commands/docs, update this file when behavior changes.

## Cursor / Copilot Rules

Checked for additional instruction files:

- `.cursorrules`: not found
- `.cursor/rules/`: not found
- `.github/copilot-instructions.md`: not found

No extra Cursor/Copilot rule overlays are currently present.
