# Dual-Agent Approval Gate

## Purpose

Use two parallel review agents as a hard merge gate.
Merge is allowed only when both agents return `APPROVE`.

## Required Review Agents

1. UI agent: UI behavior test + design validation
2. Code agent: code review + reliability/verification

## Gate Rule

- `APPROVE + APPROVE` -> merge allowed
- `APPROVE + WITHDRAW` -> no merge
- `WITHDRAW + APPROVE` -> no merge
- `WITHDRAW + WITHDRAW` -> no merge

## Standard Workflow

1. Run both review agents in parallel on the same commit range.
2. Collect both outputs with explicit verdict labels.
3. Classify findings into:
   - `Critical` (must fix before merge)
   - `Important` (fix before merge unless explicitly waived)
   - `Minor` (follow-up allowed)
4. If either agent returns `WITHDRAW`, fix findings and rerun both agents.
5. Merge only after both agents return `APPROVE` and CI is green.

## Required Evidence Before Merge

- Both review outputs preserved in task logs.
- Latest CI checks green for the PR head.
- Verification commands executed on latest head:
  - `swift test`
  - file-level `lsp_diagnostics` for changed Swift files

## Operational Policy (All Future Tasks)

Apply this gate to all non-trivial implementation tasks and all PR merges.
For trivial one-file changes, the gate can be skipped only when explicitly requested by the user.

## PR Decision Template

Use this template when reporting decision:

```text
Dual-Agent Gate Result
- UI Review: APPROVE|WITHDRAW
- Code Review: APPROVE|WITHDRAW
- CI: PASS|FAIL
- Decision: MERGE|NO MERGE
- Blocking Findings:
  1) ...
  2) ...
```
