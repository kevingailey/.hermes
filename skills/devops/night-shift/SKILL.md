---
name: night-shift
description: "Process PRD and story files overnight — autonomous implementation from spec to working code, no user supervision."
version: 1.4.0
---

# Night Shift

## Overview

Drop a PRD or user story into `docs/stories/` before bed. Wake up to working code, committed and tested. Runs fully autonomously — no interactive questions, no user supervision. Designed as a cron job during off-hours when you're not consuming API tokens.

**Core principle:** Write the spec, go to sleep, review the diff in the morning.

**All artifacts live in the project repo under `docs/` — git-tracked, no `~/.hermes/` pollution.**

## How It Works

```
You (evening)              Night Shift (overnight)          You (morning)
     │                              │                             │
     ├─ Write PRD/story ──────────► │                             │
     │  to docs/stories/            │                             │
     │                              ├─ Parse requirements         │
     │                              ├─ Scout codebase             │
     │                              ├─ Create implementation plan │
     │                              ├─ Execute via subagents      │
     │                              │  (TDD + 2-stage review)     │
     │                              ├─ Run tests                  │
     │                              ├─ Commit                     │
     │                              ├─ Archive to done/           │
     │                              ├─ Deliver summary ─────────►│
     │                              │                             ├─ Review diff
     │                              │                             ├─ Approve/amend
```

## Input File Formats

Drop markdown files into `<project-root>/docs/stories/`. Two formats accepted:

### Full PRD

```markdown
# PRD: Feature Name

## Goal
One sentence describing what this builds and why.

## Tags
bugfix, playback, critical

## Requirements
- Bullet list of functional requirements
- Each should be testable

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Technical Context
Optional: architecture preferences, constraints, libraries to use, files to modify.
```

### User Story (shorter)

```markdown
# Story: Feature Name

As a [role], I want to [capability] so that [benefit].

## Tags
bugfix, playback, critical

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Notes
Optional implementation details or constraints.
```

### Tags (optional)

A `## Tags` section may appear in either format. It contains a single comma-separated list of tags on one line:

```markdown
## Tags
bugfix, playback, critical
```

Rules:
- Optional — stories without a `## Tags` section are processed normally.
- Comma-separated, single line. Whitespace around tags is trimmed.
- Metadata only — tags do not affect processing, filtering, or ordering. They are recorded in the night-shift summary and delivery message for grouping and review.
- If present, the parser extracts the tags and includes them in the per-story summary block. If absent, the summary reports `Tags: (none)`.

## Story Templates

Copy-paste starter files live in this skill's `templates/` directory:
- `templates/story.md` — user story format (preferred for most work)
- `templates/prd.md` — full PRD format (for larger features)
- `templates/bug-to-story.md` — converting a bug report into a night-shift story (references the original bug file by path; do not duplicate the bug report content)

**For the full authoring workflow** (toolchain verification, housekeeping, parse-safety checklist, commit-before-run), load the `night-shift-stories` skill. It references these templates by path and wraps them in a phased authoring process. This skill defines the formats; `night-shift-stories` defines how to produce a committed, parse-safe file.

## References

- `references/story-authoring-guide.md` — full formatting rules for agents writing stories (formats, rules, bug conversion, toolchain warning). Read this before authoring or converting stories.
- `references/test-fixtures-verify.md` — 17-fixture test suite that exercises every parsing, tagging, toolchain-detection, and edge-case path. Run with `scripts/run-nightshift-tests.sh`.

## Directory Structure

All under `<project-root>/docs/`:

```
docs/
├── prds/              # PRDs from project-manager
│   └── <slug>-prd.md
├── stories/           # Story files from dev-lead (input for night-shift)
│   ├── <slug>-01-register.md
│   ├── <slug>-02-login.md
│   ├── done/          # Processed successfully (summary appended to original file)
│   └── failed/        # Processing failed (error details appended to original file)
├── plans/             # Implementation plans (from writing-plans skill)
│   └── <date>-<feature>.md
└── night-shift-summary.md  # Written after each run (overwrite, not append)
```

The project root is determined by:
1. The `--workdir` of the cron job (for automated runs)
2. The current working directory (for interactive sessions)
3. The `$PROJECT_ROOT` environment variable if set

## Processing Pipeline

For each file in `docs/stories/` (top-level only, not in `done/` or `failed/`), process in order:

### Phase 1: Parse & Scout
- Parse the PRD/story into structured requirements and acceptance criteria
- Scout the codebase: project structure, existing patterns, relevant files
- Identify which files will need to change
- If the file can't be parsed, move to `docs/stories/failed/` with the parse error and continue to next file

### Phase 2: Plan
- Create a detailed implementation plan following the **writing-plans** skill
- Tasks are bite-sized (2-5 min each), TDD where applicable
- Save plan to `docs/plans/` for traceability
- If planning fails, move to `docs/stories/failed/` with the error and continue

### Phase 3: Execute
- Dispatch subagents per task via **subagent-driven-development**
- Two-stage review per task: spec compliance FIRST, code quality SECOND
- Each task committed atomically
- If a task fails, note it but continue to next task (partial progress preserved)

### Phase 4: Verify
- Run the project's test suite
- Check acceptance criteria against what was built
- If tests fail, the implementation is still committed (partial work preserved) — note in report

### Phase 5: Archive
- Append a summary block to the original story file
- Move to `docs/stories/done/` on success, `docs/stories/failed/` on failure
- Summary includes: what was built, commits, test results, acceptance criteria status, any issues

## Cron Job Setup

```bash
# Create the directory structure once (in your project root)
mkdir -p docs/{prds,stories/{done,failed},plans}

# Create the cron job (runs at 2 AM daily — adjust to your off-hours)
hermes cron create \
  --name "night-shift" \
  --schedule "0 2 * * *" \
  --skill night-shift \
  --prompt "Process all PRD/story files in docs/stories/ (top-level only, not in done/ or failed/). Follow the night-shift skill workflow. Report what was built, what failed, and why. If the stories directory is empty, exit silently with no delivery." \
  --workdir /home/code/kgx \
  --deliver origin
```

**Schedule tips:**
- `0 2 * * *` — daily at 2 AM (default)
- `0 3 * * 1-5` — weekdays at 3 AM only
- `0 1,3 * * *` — twice nightly (for heavy workloads)
- Adjust the `--workdir` to your project root

**Toolset recommendation** (reduces token overhead):
The cron job needs `terminal`, `file`, and `delegation` toolsets. If the plan phase needs web research, also include `web`. Set via `--enabled-toolsets terminal,file,delegation,web`.

## Error Handling

| Situation | Behavior |
|-----------|----------|
| Empty stories dir | Silent exit — no delivery, no notification |
| Empty stories dir + uncommitted working-tree changes | Commit pending verified work before exiting. Check `git status` for modified/tracked files. If changes match previously-verified fixes (e.g., bug-hunt resolutions confirmed in a prior session), commit them atomically with a descriptive message. Relocate any summary/HOWTO docs left at `docs/stories/` top level to `docs/` (one level up) — night-shift would otherwise try to parse them on the next run. Write a housekeeping summary to `docs/night-shift-summary.md` and deliver it. |
| Parse failure | Move to `docs/stories/failed/` with error. Continue to next file |
| Plan failure | Move to `docs/stories/failed/` with error. Continue |
| Execution failure (task) | Skip task, continue remaining tasks. Note in report |
| Test failure | Still committed. Move to `docs/stories/done/` with test output in report |
| All files fail | Deliver failure report with details |
| Lock file exists | Abort — previous run still active. Report in delivery |

## Safety Properties

- **Atomic commits per task** — never lose partial work if a task fails
- **One file at a time** — no parallel processing, no merge conflicts from concurrent writes
- **Lock file** — prevents concurrent cron runs from colliding
- **Committed even on failure** — you can inspect and fix in the morning
- **No destructive operations** — never deletes story files, only moves them to `done/` or `failed/`

## Reporting

After processing all files, write a summary to `docs/night-shift-summary.md` (overwrite, don't append). This file is git-tracked so you can review what happened in the morning alongside the diff.

The summary file format:

```markdown
# Night Shift — 2026-07-17

## Summary
- Processed: 2 files
- Succeeded: 1
- Failed: 1

## ✅ Feature: User email verification
- Tags: auth, backend
- Commits: abc1234, abc1235
- Tests: 12 passed, 0 failed
- AC: 3/3 met

## ❌ Feature: Password reset flow
- Tags: auth, backend
- Error: Plan phase failed — API rate limit hit
- Partial work: password-reset branch has WIP commits
```

The delivery message (sent to the user) includes the same information:

```
Night Shift Report — 2026-07-17

✅ Feature: User email verification
   Tags: auth, backend
   Commits: abc1234, abc1235
   Tests: 12 passed, 0 failed
   AC: 3/3 met

❌ Feature: Password reset flow
   Tags: auth, backend
   Error: Plan phase failed — API rate limit hit
   Partial work: password-reset branch has WIP commits

📁 1 file skipped (empty)
```

## Pitfalls

### Toolchain-less environments (CRITICAL)

When the execution environment lacks the project's language toolchain (e.g., no Swift compiler for iOS projects, no Rust toolchain for Rust projects), night-shift will write code blind — no compilation, no test execution. This has happened and produced 16 stories of plausible-looking but untested code.

**What goes wrong:**
- Code is committed with "passes" acceptance criteria that were never verified
- Subagents invent non-existent APIs and product types (e.g., `.iOSApplication` in SwiftPM — doesn't exist in standard SwiftPM, only in xtool's fork)
- Build errors are discovered later when a human finally compiles on a real toolchain

**Mitigation:**
1. **Detect toolchain availability in Phase 1 (Scout).** Before executing any stories, check if the project's build command works (e.g., `swift build --version`, `cargo --version`, `npm --version`). If the toolchain is missing, note it prominently in the summary.
2. **Flag untestable acceptance criteria.** In the summary, explicitly mark which stories had `xtool dev build passes` or similar criteria that could not be verified. Don't silently pass them.
3. **Don't invent APIs.** If unsure about a framework's API surface, use the web toolset to look it up, or note the uncertainty in the code comments and summary.
4. **Prefer standard over custom.** When writing Package.swift, build configs, etc., use standard SwiftPM types. Don't invent product types like `.iOSApplication` — xtool reads `xtool.yml` for iOS-specific bundling, the Package.swift should use standard `.library`.

### Stories must be committed before the cron run

The cron job checks out the latest commit. If stories are added to `docs/stories/` but not committed, the job won't see them.

### Non-story files in docs/stories/ get parsed (and usually fail)

Night-shift processes **every** top-level markdown file in `docs/stories/` regardless of filename — no skip list, no filename filter. A HOWTO, README, or bug report left at top level will be treated as a story. Bug reports (table header + Description + Evidence + Fix, no `## Goal` or user-story sentence) either get mangled into pseudo-requirements or punted to `docs/stories/failed/` with a parse error. This has happened in production — 26 BUG-00x.md files were sitting in `docs/stories/` and would all have been picked up.

Rules:
- Keep documentation files (HOWTOs, guides, READMEs) in `docs/`, NOT `docs/stories/`. Night-shift only scans `docs/stories/` top-level.
- Bug reports must be converted to story format before dropping into `docs/stories/`. Pattern: create a new `# Story:` file that references the bug report by path in Technical Context rather than duplicating it. Leave the original bug report in `docs/` or a `docs/bugs/` folder — not in `docs/stories/`.
- A HOWTO-WRITE-STORIES.md guide placed in `docs/` (one level up from `docs/stories/`) is the safe location for story-authoring guidance for agents.

## See also

- `night-shift-stories` skill — the authoring workflow that produces
  committed, parse-safe story files using this skill's templates. Load it
  when writing or converting stories.
- `qa-night-shift` skill — autonomous QA review that files defect stories
  (as `qa-NN-<slug>.md`) back into `docs/stories/` for night-shift to fix.
  Closes the implement → review → fix loop.
- `dev-lead` skill — PRD decomposition into vertical-slice story files.

## Tips

- **One feature per file.** Multiple features in one file = one plan = harder to review partial results.
- **Be specific in Technical Context.** The more you tell it about which files to touch and which patterns to follow, the better the output.
- **Review the diff in the morning.** Night Shift is autonomous but not perfect — always review before deploying.
- **Test the setup first.** Drop a small story in `docs/stories/` and run `hermes cron run <job-id>` to verify the pipeline works end-to-end before trusting it overnight. For a full pipeline test, use the 17-fixture suite in `scripts/run-nightshift-tests.sh` (see `references/test-fixtures-verify.md`).
- **Commit stories before night-shift runs.** Run `git add docs/stories/ && git commit -m "docs: add stories for <feature>"` before bed.
- **Ensure the toolchain is available.** If the project's build tool (swift, cargo, npm, etc.) isn't installed in the execution environment, night-shift will write code blind. Install the toolchain or set up a Docker dev container before the first run.
