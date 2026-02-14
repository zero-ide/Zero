# Design Consistency Pass 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align high-impact UI consistency gaps across repo selection, editor/output, and git history/stash flows while preserving existing architecture.

**Architecture:** Keep view-driven structure intact and apply focused, reversible changes in SwiftUI views plus minimal AppState feedback plumbing. Use one reusable inline error banner component to standardize error affordances. Favor UX consistency updates that do not require service-layer refactors.

**Tech Stack:** SwiftUI (macOS 14+), Swift Concurrency, XCTest (SwiftPM)

---

### Task 1: Add shared inline error banner component

**Files:**
- Create: `Sources/Zero/Views/InlineErrorBanner.swift`
- Modify: `Sources/Zero/Views/GitPanelView.swift`

**Step 1: Write the failing test**

```swift
func testInlineErrorBannerCompilesInViewHierarchy() {
    let view = InlineErrorBanner(message: "Error")
    XCTAssertNotNil(view)
}
```

Place test in `Tests/ZeroTests/BuildConfigurationViewTests.swift` as a temporary compile guard for shared view wiring.

**Step 2: Run test to verify it fails**

Run: `swift test --filter BuildConfigurationViewTests/testInlineErrorBannerCompilesInViewHierarchy`
Expected: FAIL (symbol not found before component creation).

**Step 3: Write minimal implementation**

```swift
struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
    }
}
```

Replace the custom error block in `GitPanelView` with this shared component.

**Step 4: Run test to verify it passes**

Run: `swift test --filter BuildConfigurationViewTests/testInlineErrorBannerCompilesInViewHierarchy`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/Zero/Views/InlineErrorBanner.swift Sources/Zero/Views/GitPanelView.swift Tests/ZeroTests/BuildConfigurationViewTests.swift
git commit -m "feat(ui): add shared inline error banner"
```

### Task 2: Surface repo/session feedback consistently in AppState + RepoList

**Files:**
- Modify: `Sources/Zero/Views/AppState.swift`
- Modify: `Sources/Zero/Views/RepoListView.swift`
- Test: `Tests/ZeroTests/AppStateTests.swift`

**Step 1: Write the failing test**

```swift
func testFetchRepositoriesSetsUserFacingErrorOnFailure() async {
    // configure mock service to throw and assert userFacingError is set
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppStateTests/testFetchRepositoriesSetsUserFacingErrorOnFailure`
Expected: FAIL (no user-facing error property/behavior yet).

**Step 3: Write minimal implementation**

- Add `@Published var userFacingError: String?` in `AppState`.
- Set this field in catch blocks for repo/org/session critical failures.
- Clear it on successful loads.
- In `RepoListView`, render `InlineErrorBanner` when `userFacingError` is non-empty.
- Add session-delete confirmation alert and icon accessibility labels/help.
- Add row tap affordance for `RepoRow` and `SessionRow` while preserving current buttons.

**Step 4: Run tests to verify it passes**

Run: `swift test --filter AppStateTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/Zero/Views/AppState.swift Sources/Zero/Views/RepoListView.swift Tests/ZeroTests/AppStateTests.swift
git commit -m "feat(repo): standardize repo/session feedback and destructive confirmation"
```

### Task 3: Standardize Git history/stash feedback and destructive flow

**Files:**
- Modify: `Sources/Zero/Views/GitHistoryView.swift`
- Modify: `Sources/Zero/Views/GitStashView.swift`

**Step 1: Write the failing test**

```swift
func testGitStashViewModelRetainsErrorMessageOnDropFailure() async {
    // setup failing GitService runner and assert errorMessage is populated
}
```

Add test in `Tests/ZeroTests/GitServiceTests.swift` using existing mock runner style where practical.

**Step 2: Run test to verify it fails**

Run: `swift test --filter GitServiceTests/testGitStashViewModelRetainsErrorMessageOnDropFailure`
Expected: FAIL.

**Step 3: Write minimal implementation**

- `GitHistoryView`: show `InlineErrorBanner` when `viewModel.errorMessage` exists.
- `GitStashView`: show loading indicator from `isLoading`, show `InlineErrorBanner`, add confirmation before Drop.
- Add visible per-row action menu button (`ellipsis.circle`) to improve stash action discoverability.

**Step 4: Run tests to verify it passes**

Run: `swift test --filter GitServiceTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/Zero/Views/GitHistoryView.swift Sources/Zero/Views/GitStashView.swift Tests/ZeroTests/GitServiceTests.swift
git commit -m "feat(git-ui): unify history/stash feedback and drop confirmation"
```

### Task 4: Align editor/output visual hierarchy

**Files:**
- Modify: `Sources/Zero/Views/EditorView.swift`
- Modify: `Sources/Zero/Views/OutputView.swift`

**Step 1: Write the failing test**

```swift
func testOutputViewCompilesWithHeadlineHeaderStyle() {
    let view = OutputView(executionService: ExecutionService(dockerService: DockerService()))
    XCTAssertNotNil(view)
}
```

Add to `Tests/ZeroTests/ExecutionServiceTests.swift` as compile guard.

**Step 2: Run test to verify it fails**

Run: `swift test --filter ExecutionServiceTests/testOutputViewCompilesWithHeadlineHeaderStyle`
Expected: FAIL before signature/usage update.

**Step 3: Write minimal implementation**

- Replace `EditorView` card hardcoded background (`Color.white`) with system-derived surface color.
- Update `OutputView` header typography from caption-bold to headline-level panel header style.
- Keep output controls and behavior unchanged.

**Step 4: Run test to verify it passes**

Run: `swift test --filter ExecutionServiceTests/testOutputViewCompilesWithHeadlineHeaderStyle`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/Zero/Views/EditorView.swift Sources/Zero/Views/OutputView.swift Tests/ZeroTests/ExecutionServiceTests.swift
git commit -m "style(editor): align editor and output panel visual hierarchy"
```

### Task 5: Verification + validation gates + PR

**Files:**
- Modify: `docs/workflows/dual-agent-approval-gate.md` (if process notes need update)

**Step 1: Run full verification**

Run: `swift test`
Expected: PASS (0 failures).

Run diagnostics:

`lsp_diagnostics` on:
- `Sources/Zero/Views/AppState.swift`
- `Sources/Zero/Views/RepoListView.swift`
- `Sources/Zero/Views/GitHistoryView.swift`
- `Sources/Zero/Views/GitStashView.swift`
- `Sources/Zero/Views/EditorView.swift`
- `Sources/Zero/Views/OutputView.swift`
- `Sources/Zero/Views/InlineErrorBanner.swift`

Expected: no new errors introduced.

**Step 2: Run validation workflow #2 (post-implementation local gate)**

- UI consistency reviewer agent (visual-engineering)
- UX interaction/state reviewer agent (visual-engineering)
- Code reliability reviewer agent (deep)

Expected: APPROVE/APPROVE/APPROVE or explicit blocker list.

**Step 3: Open PR and run validation workflow #3 (PR gate)**

- Push branch and create PR with summary + test evidence.
- Run three PR-level validators (UI, UX, reliability) against PR diff.
- Confirm CI checks are green.

**Step 4: Commit (docs only, if changed)**

```bash
git add docs/workflows/dual-agent-approval-gate.md
git commit -m "docs: record validation workflow updates for design consistency pass"
```
