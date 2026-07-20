---
name: code-review
description: "Pre-commit security scan, quality gates, auto-fix, and parallel 3-agent cleanup of code changes."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [code-review, security, verification, quality, pre-commit, auto-fix, cleanup, refactor, simplify]
    consolidated_from: [requesting-code-review, simplify-code]
---

# Code Review — Verification & Cleanup

Two complementary review workflows: **pre-commit verification** (security scan, quality gates, independent reviewer) and **post-implementation cleanup** (parallel 3-agent simplify pass).

---

## Workflow 1: Pre-Commit Verification

Run before `git commit` or `git push`. Security scan, baseline tests, independent reviewer subagent, and auto-fix loop.

**This vs. GitHub PR review:** This verifies YOUR changes before committing. `github-cli` (section 4) reviews OTHER people's PRs on GitHub.

### Step 1 — Get the Diff

```bash
git diff --cached
# If empty, try: git diff, then git diff HEAD~1 HEAD
# If >15k chars: split by file
```

### Step 2 — Static Security Scan

```bash
# Hardcoded secrets
git diff --cached | grep "^+" | grep -iE "(api_key|secret|password|token|passwd)\s*=\s*['\"][^'\"]{6,}['\"]"
# Shell injection
git diff --cached | grep "^+" | grep -E "os\.system\(|subprocess.*shell=True"
# Dangerous eval/exec
git diff --cached | grep "^+" | grep -E "\beval\(|\bexec\("
# Unsafe deserialization
git diff --cached | grep "^+" | grep -E "pickle\.loads?\("
# SQL injection
git diff --cached | grep "^+" | grep -E "execute\(f\"|\.format\(.*SELECT|\.format\(.*INSERT"
```

### Step 3 — Baseline Tests and Linting

Run the project's test framework and linter. Capture failure count BEFORE your changes (stash, run, pop). Only NEW failures block the commit.

```bash
# Python
python -m pytest --tb=no -q 2>&1 | tail -5
which ruff && ruff check . 2>&1 | tail -10
# Node
npm test -- --passWithNoTests 2>&1 | tail -5
# Rust / Go
cargo test 2>&1 | tail -5
go test ./... 2>&1 | tail -5
```

### Step 4 — Self-Review Checklist

- [ ] No hardcoded secrets, API keys, or credentials
- [ ] Input validation on user-provided data
- [ ] SQL queries use parameterized statements
- [ ] File operations validate paths (no traversal)
- [ ] External calls have error handling
- [ ] No debug print/console.log left behind
- [ ] No commented-out code
- [ ] New code has tests (if test suite exists)

### Step 5 — Independent Reviewer Subagent

Call `delegate_task` with the diff and static scan results. The reviewer gets ONLY the diff — no shared context. Fail-closed: unparseable response = fail.

```python
delegate_task(
    goal="""You are an independent code reviewer. Review the git diff and return ONLY valid JSON.
FAIL-CLOSED RULES:
- security_concerns non-empty -> passed must be false
- logic_errors non-empty -> passed must be false

<static_scan_results>[INSERT FINDINGS FROM STEP 2]</static_scan_results>
<code_changes>[INSERT GIT DIFF OUTPUT]</code_changes>

Return ONLY: {"passed": bool, "security_concerns": [], "logic_errors": [], "suggestions": [], "summary": "..."}""",
    context="Independent code review. Return only JSON verdict.",
    toolsets=["terminal"])
```

### Step 6 — Evaluate Results

All passed → Step 8 (commit). Any failures → Step 7 (auto-fix).

### Step 7 — Auto-Fix Loop (max 2 cycles)

Spawn a THIRD agent context to fix ONLY the reported issues:

```python
delegate_task(
    goal="Fix ONLY the specific issues listed. Do NOT refactor, rename, or change anything else.\nIssues:\n[INSERT security_concerns AND logic_errors]\n\nCurrent diff for context:\n[INSERT GIT DIFF]",
    context="Fix only the reported issues. Do not change anything else.",
    toolsets=["terminal", "file"])
```

After fix, re-run Steps 1-6. Passed → commit. Failed and attempts < 2 → repeat. Failed after 2 → escalate to user.

### Step 8 — Commit

```bash
git add -A && git commit -m "[verified] <description>"
```

---

## Workflow 2: Simplify Code (Parallel 3-Agent Cleanup)

Review recent code changes with three focused reviewers running in parallel, aggregate findings, and apply fixes.

**When to use:** User says "simplify", "review my changes", "clean up my changes", "/simplify".

**Do NOT auto-run after every edit.** Only when explicitly asked. Costs three subagents' worth of tokens.

### Phase 1 — Identify the Changes

```bash
git diff                    # default: uncommitted working-tree changes
git diff HEAD               # include staged
git diff HEAD~1             # last commit
git diff main...HEAD        # this branch
git diff --staged            # staged changes only
git diff -- src/foo.py      # specific file(s)
```

If diff >2000 changed lines, warn about token cost and offer to scope down.

### Phase 2 — Launch Three Reviewers in Parallel

Use `delegate_task` batch mode — all three in one `tasks` array.

**Reviewer 1 — Code Reuse:** Find code that duplicates functionality already in the codebase. Search utility modules and adjacent files for existing functions the new code could call instead.

**Reviewer 2 — Code Quality:** Find redundant state, parameter sprawl, copy-paste-with-variation, leaky abstractions, stringly-typed code where constants/enums exist.

**Reviewer 3 — Efficiency:** Find unnecessary work (redundant computation, repeated file reads, N+1 patterns), missed concurrency, hot-path bloat, TOCTOU anti-patterns, memory issues, overly broad reads.

Each reviewer:
- Searches the existing codebase for evidence (don't reason from diff alone)
- Reports as: `file:line → problem → suggested fix`
- Ranks: `high` / `medium` / `low` confidence
- Skips nits and style-only churn

### Phase 3 — Aggregate and Apply

1. **Merge** findings, deduping overlap
2. **Discard** false positives (you have the most context)
3. **Resolve conflicts** — correctness > user's stated focus > readability > micro-perf
4. **Apply** fixes directly with `patch`/`write_file` (unless dry run requested)
5. **Verify** — run targeted tests for touched files
6. **Summarize** — applied fixes by category, skipped findings and why

### Pitfalls

- Don't fan out wider than ~3 reviewers
- Give the WHOLE diff to each reviewer (cross-file issues hide in fragments)
- Reviewers must search, not guess — findings without `file:line` evidence are noise
- Apply ≠ rewrite — keep edits scoped to what the diff touched
- Respect project conventions (AGENTS.md / CLAUDE.md / linter config)

---

## Quick Reference

| Action | Workflow | When |
|--------|----------|------|
| Security scan + quality gate + reviewer | Pre-commit verification | Before `git commit` / `git push` |
| Parallel 3-agent cleanup | Simplify code | After implementation, on request |
| Both in sequence | Verify then simplify | After complex changes |

**Integration with other skills:**
- **test-driven-development:** Pre-commit verification checks that TDD discipline was followed
- **systematic-debugging:** Use debugging when pre-commit review finds an issue you don't understand
- **writing-plans:** Verification validates implementation matches plan requirements
