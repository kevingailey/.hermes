---
name: qa-night-shift
description: "Review code changes against night-shift's output, file defect stories for regressions, and maintain a last-green-sha QA ledger. Read-only on source — files stories, never fixes."
version: 1.0.0
---

# QA Night Shift — Review & File Stories

## Overview

Autonomous QA engineer for the DifferntTV Swift/iOS project (and any project
following the night-shift pipeline). Runs AFTER `night-shift` implements stories,
reviews the resulting code changes, and files parse-safe defect stories for
anything broken. **Never fixes code.** Only tests, reviews, and reports via
story files.

**Core loop:** night-shift implements → QA reviews the diff → QA files
`qa-NN-<slug>.md` stories for defects → next night-shift run fixes them.

This is the `night-shift-stories` skill's heaviest consumer: every defect
becomes a committed, parse-safe story in `docs/stories/`.

## When to use this skill

Three trigger modes — all load this skill:

1. **On-demand** — user asks for a QA pass ("review the latest changes",
   "run QA"). Runs immediately in the current session.
2. **In-process after night-shift (primary)** — the night-shift cron job
   loads this skill and runs QA immediately after finishing its
   implementation pass. No separate cron job. If night-shift didn't process
   any stories (empty inbox), QA is skipped entirely — no wasted runs.
3. **Scheduled weekly full audit** — cron job at 2 AM Saturdays, reviews
   `<last-green-sha>..HEAD` regardless of whether night-shift ran.

## Environment reality (DifferntTV)

This project has NO Swift toolchain on the host. Builds and tests run inside
the `differnttv-swift-dev:6.3` Docker container:

```bash
docker compose run --rm swift-dev bash -lc '<build command>'
```

Toolchain commands available in-container: `swift`, `swiftc`, `xtool`.
NOT available: `swiftlint`, `gh` CLI. Static analysis is grep-based; story
filing means writing markdown to `docs/stories/`, not calling an external
tracker.

If the container or Darwin SDK is unavailable, QA falls back to
**static-only review** (grep + diff inspection) and marks the run YELLOW —
never claims GREEN on unverified code. This mirrors the night-shift
toolchain-less pitfall: don't silently pass what you couldn't test.

## State — `.qa/`

All QA state lives in `<project-root>/.qa/` (git-tracked):

```
.qa/
├── last-green-sha    # one line: SHA of last fully-green commit
├── README.md         # explains the ledger
└── reports/
    └── <YYYY-MM-DD>/ # per-run: report.md + raw stage logs
```

**`.qa/last-green-sha`** is the QA ledger. The agent reads it to get the
diff range (`<last-green-sha>..HEAD`) and updates it ONLY when a run is
fully green (all stages pass). If stages fail, the SHA does not move — the
next run re-reviews the same range plus new commits.

If `.qa/last-green-sha` doesn't exist or is empty, default to reviewing
`HEAD~10..HEAD` (last 10 commits) and note the seed assumption in the report.

## Inputs

1. **Diff range** — `git log <last-green-sha>..HEAD` (or `HEAD~10..HEAD` if
   no ledger). Determine project root via `$PROJECT_ROOT` / cwd / cron workdir.
2. **Night-shift output** — `docs/night-shift-summary.md` (written by the
   night-shift run). Lists which stories were processed, succeeded, failed.
   When chained via `context_from`, the night-shift summary is injected
   directly.
3. **Pending stories** — top-level files in `docs/stories/` that night-shift
   hasn't processed yet (read these to understand intended work).
4. **Previous QA reports** — `.qa/reports/<prior-date>/report.md` for
   trend comparison (test counts, warning baselines).

## Phase 0: Environment & range check

```bash
cd <project-root>

# Read the ledger
LAST_GREEN=$(cat .qa/last-green-sha 2>/dev/null || echo "")
if [ -z "$LAST_GREEN" ]; then
  RANGE="HEAD~10..HEAD"
  echo "WARNING: no last-green-sha, defaulting to $RANGE"
else
  RANGE="${LAST_GREEN}..HEAD"
fi

# Check night-shift ran recently
cat docs/night-shift-summary.md 2>/dev/null | head -40

# Verify the toolchain is reachable
docker compose run --rm swift-dev bash -lc 'swift --version && xtool --help >/dev/null 2>&1 && echo OK || echo MISSING'
```

Three toolchain outcomes:

| Result | Behavior |
|--------|----------|
| Container + Swift OK | Run full pipeline (Stages 1-4). GREEN possible. |
| Container OK, xtool/SDK missing | Stages 1-2 partial (Linux targets only), Stage 3 grep-based, mark run YELLOW, note in report. |
| Container unavailable | Static-only review (diff inspection + grep), mark run YELLOW, "Toolchain unavailable — static review only" in report. Never GREEN. |

If the environment itself is broken (container won't start, missing secrets,
corrupt repo), write a single `qa-infra` story to `docs/stories/` and STOP —
do not blame application code. See "Filing infra stories" below.

## Phase 1: Identify what to review

```bash
# Commits in range
git log --oneline $RANGE

# Files changed
git diff --stat $RANGE

# Stories night-shift processed tonight
grep -A20 "## ✅\|## ❌" docs/night-shift-summary.md 2>/dev/null
```

Map commits to stories: night-shift commits reference the story slug in the
message (e.g. `feat(favorites): … (story 12)`). Group the diff by story.

If night-shift didn't run (scheduled weekly audit with no night-shift
output), review the entire range as one batch — no per-story grouping.

## Phase 2: Test pipeline

Run in order. Capture ALL output to `.qa/reports/<date>/`.

### Stage 1 — Build regression

```bash
docker compose run --rm swift-dev bash -lc '
  swift build 2>&1
  # xtool build for iOS packaging — only if SDK is present
  xtool dev build 2>&1 || echo "XTOOL_BUILD_UNAVAILABLE"
'
```

**FAIL criteria:** any compile error, packaging error, or NEW warnings
compared to the previous report's warning list. Compare warnings:

```bash
# Baseline from last report
grep -A999 "## Warnings" .qa/reports/<prior>/report.md > /tmp/prev-warnings.txt
# Current
docker compose run --rm swift-dev bash -lc 'swift build 2>&1' | grep -iE "warning:" > /tmp/cur-warnings.txt
diff /tmp/prev-warnings.txt /tmp/cur-warnings.txt
```

If `xtool dev build` returns `XTOOL_BUILD_UNAVAILABLE`, record it in the
report — do NOT fail the stage (it's an environment limit, not a code
defect), but mark the run YELLOW.

### Stage 2 — Automated tests

```bash
docker compose run --rm swift-dev bash -lc 'swift test --parallel 2>&1'
```

Compare test count against the previous run. A DROP in total test count is
a defect (tests deleted/disabled) unless a story explicitly says so. If
night-shift added features without adding tests for testable (non-UI) logic,
flag it as a `qa-no-tests` defect.

### Stage 3 — Static analysis (grep-based)

No `swiftlint` in this environment. Use targeted greps against the diff:

```bash
git diff $RANGE -- Sources/ | grep "^+" | \
  grep -iE "(TODO|FIXME|XXX|HACK)"  # leftover markers
git diff $RANGE -- Sources/ | grep "^+" | \
  grep -E "force.*unwrap|!\s*$|fatalError\("  # dangerous unwraps in non-test code
git diff $RANGE -- Sources/ | grep "^+" | \
  grep -E "print\(|debugPrint\("  # debug prints left behind
git diff $RANGE -- Sources/ | grep "^+" | \
  grep -iE "(api_key|secret|password|token)\s*=\s*['\"]"  # hardcoded secrets
git diff $RANGE -- Package.swift Package.resolved  # dependency changes for review
git diff $RANCE -- Sources/ | grep "^-" | wc -l   # deletions (surprising?)
```

Flag findings as `file:line → problem`. Distinguish `Sources/` (production)
from `Tests/` (test code — force-unwraps acceptable there).

### Stage 4 — Story acceptance review (per story)

For each story night-shift processed tonight:

1. Read the story file (from `docs/stories/done/<slug>.md` — night-shift
   appends a summary block and archives it).
2. Read the story's acceptance criteria (the `- [ ]` checkboxes).
3. Read the diff for that story (commits referencing the story slug).
4. Verify:
   - Each AC is plausibly met in code (trace to specific lines)
   - Edge cases handled, no unrelated code touched
   - No TODO/FIXME/commented-out code left behind
   - No force-unwraps or `fatalError` added in non-test code
   - SwiftUI views reviewed statically (can't execute here):
     state ownership (`@State`/`@Binding`/`@Observable`) correctness,
     missing accessibility labels, hardcoded strings that should be localized

SwiftUI views can't be executed on Linux. Review view code statically and
flag suspected issues as `qa-suspected` (lower confidence) — don't claim
verified.

## Phase 3: Filing defect stories

For every defect found, create ONE story file in `docs/stories/` using the
`night-shift-stories` skill's bug-conversion format. Filename:
`qa-<NN>-<slug>.md` (e.g. `qa-01-favorites-crash.md`).

**MANDATORY: load the `night-shift-stories` skill before filing.** It
enforces parse-safety (title shape, intent signal, AC specificity, toolchain
verifiability marking) and the housekeeping pass that keeps `docs/stories/`
clean. Filing without it risks stories night-shift can't parse.

```markdown
# Story: [QA] <symptom> in <area>

As a developer, I want <what should work> so that <why it matters>.

## Tags
qa, regression, <area>, <severity: blocker|major|minor>

## Acceptance Criteria
- [ ] <Specific, testable fix criterion>
- [ ] <Exact command that should pass: e.g. "swift build passes with 0 errors">
- [ ] <No new warnings introduced>

## Technical Context
- Found by: QA run <YYYY-MM-DD> (diff range <sha>..HEAD)
- File: <path/to/file.swift:line>
- Symptom: <expected vs actual>
- Reproduce: <exact command>
- Error output: <trimmed to relevant lines>
- Suspected commit: <sha> (from the night's commits)
- Originating story: <docs/stories/done/<slug>.md> (if applicable)
- Severity: <blocker/major/minor>

## Notes
- <What the fix must NOT touch, ordering constraints, or context>
```

Filing rules:

- **Dedupe first.** Before filing, `ls docs/stories/qa-*.md` and read any
  with a matching symptom. If one matches, add a "Re-occurred <date>" note
  to that file's Notes section instead of filing a duplicate. Do NOT create
  a second file for the same defect.
- **One file per defect.** Don't bundle multiple defects — night-shift makes
  one plan per file.
- **Reference, don't duplicate.** If the defect traces to a night-shift
  story, point to `docs/stories/done/<slug>.md` by path. Don't copy the
  original story's content.
- **Mark unverifiable ACs.** If a compile-check AC can't be verified without
  the Darwin SDK (per `night-shift-stories` Phase 1), mark it in Notes:
  `> Note: xtool dev build AC unverifiable in this environment — verify on a
  > real toolchain before accepting.`
- **Regression vs defect.** Tag `regression` if it worked at last-green-sha;
  tag `defect` if it's new code that never worked. This tells night-shift
  whether to bisect or implement fresh.

### Filing infra stories

If the environment itself is broken (container won't start, Darwin SDK
missing, corrupt repo), file a SINGLE story:

```markdown
# Story: [QA-infra] <what's broken>

As a developer, I want the QA environment fixed so that QA runs can verify code.

## Tags
qa-infra, blocker

## Acceptance Criteria
- [ ] <Specific env fix: e.g. "docker compose run --rm swift-dev bash -lc 'swift --version' succeeds">

## Technical Context
- Found by: QA run <YYYY-MM-DD>
- Symptom: <exact error>
- Impact: QA cannot verify code changes — all subsequent runs are YELLOW until fixed

## Notes
- Do NOT file application-code stories until this is resolved.
```

Then STOP. Do not run remaining stages or file code defects — you can't
verify them.

## Phase 4: Story verdicts

For each story night-shift processed tonight, record a verdict in the report:

| Verdict | Condition |
|---------|-----------|
| ✅ Pass | ACs met in code AND all stages green for its files |
| ❌ Fail | ACs not met OR a stage failed for its files |
| ⚠️ Unverifiable | ACs plausibly met but toolchain unavailable — mark in report |

The verdicts go in `.qa/reports/<date>/report.md`. Night-shift's own
archiving (move to `done/`) is NOT reversed by QA — if a story failed QA,
file a `qa-NN-<slug>.md` regression story and let night-shift re-fix in the
next run. Don't move `done/` files back to `failed/`.

## Phase 5: Report & ledger update

Write `.qa/reports/<YYYY-MM-DD>/report.md`:

```markdown
# QA Report — 2026-07-19

## Verdict: 🟢 GREEN / 🟡 YELLOW / 🔴 RED

## Range
- Reviewed: <last-green-sha>..HEAD (<N> commits)
- Night-shift summary: docs/night-shift-summary.md (if applicable)

## Stage Results
| Stage | Result | Notes |
|-------|--------|-------|
| Build (swift build) | PASS/FAIL/SKIP | <error summary or "0 errors, 2 warnings (unchanged)"> |
| Build (xtool dev build) | PASS/FAIL/UNAVAILABLE | <summary> |
| Tests (swift test) | PASS/FAIL | <N passed, M failed; count change ±X vs last run> |
| Static analysis | PASS/FAIL | <findings count by category> |
| Story acceptance | N/N pass | <per-story verdicts below> |

## Per-Story Assessment
### Story: <slug> — ✅ Pass
- AC: 3/3 met
- Commits: abc1234
- Notes: <any>

### Story: <slug> — ❌ Fail
- AC: 1/3 met (criterion 2 not found in diff)
- Commits: def5678
- Filed: docs/stories/qa-02-<slug>.md (regression)

## Defects Filed
- docs/stories/qa-01-<slug>.md — [QA] <symptom> (blocker)
- docs/stories/qa-02-<slug>.md — [QA] <symptom> (major)

## Toolchain Note
<If YELLOW: "xtool dev build unavailable — Darwin SDK not installed. SwiftUI
view logic reviewed statically only. Verify on a real toolchain before
accepting.">

## Ledger
- last-green-sha: <updated to HEAD, or "unchanged (<sha>) — run not green">
```

### Ledger update rules

- **All stages green AND no defects filed** → update `.qa/last-green-sha` to HEAD.
- **Any stage failed, defects filed, or toolchain unavailable** → do NOT
  update. The next run re-reviews the same range plus new commits.
- Commit the ledger change: `git add .qa/ && git commit -m "qa: <green|yellow|red> run <date>, <N> defects filed"`

### Delivery message (sent to user)

```
QA Report — 2026-07-19

Verdict: 🟡 YELLOW
Range: e3c3428..d617744 (3 commits)

Stage Results:
- swift build: PASS (0 errors, 2 warnings unchanged)
- xtool dev build: UNAVAILABLE (Darwin SDK not installed)
- swift test: PASS (24 passed, 0 failed; +3 vs last run)
- Static analysis: 2 findings (1 TODO left in FavoritesView.swift:42, 1 force-unwrap in SourceManager.swift:118)
- Story acceptance: 2/3 pass

Defects Filed:
- docs/stories/qa-01-favorites-todo.md — [QA] TODO left in production code (minor)
- docs/stories/qa-02-source-force-unwrap.md — [QA] Force-unwrap added in non-test code (major)

Ledger: unchanged (e3c3428) — run not green, 2 defects filed
```

## Hard rules

1. **Never modify source code, tests, or Package.swift.** Read-only except
   `.qa/` and `docs/stories/qa-*.md`. If you find yourself editing a `.swift`
   file, STOP — you've crossed the QA/implementation boundary.
2. **Never mark a run GREEN if any stage was skipped, errored, or the
   toolchain was unavailable.** GREEN means verified, not "probably fine".
3. **If the environment is broken, file one `qa-infra` story and stop.** Do
   not blame application code for environment failures.
4. **Dedupe before filing.** Never file a duplicate of an existing `qa-*`
   story — annotate the existing one instead.
5. **One defect per file.** Bundled defects make night-shift's one-plan-per-
   file model fail.
6. **Budget: stop after 30 minutes** of agent time. Report partial results
   as YELLOW with "timeout — partial review" in the report. Don't loop.
7. **Load `night-shift-stories` before filing.** It enforces parse-safety
   and housekeeping. Filing without it risks stories night-shift can't parse.

## Pitfalls

### Toolchain-less false-greens
The biggest risk. If `xtool dev build` is unavailable, SwiftUI/AVKit/Network
code is unverified. Mark the run YELLOW, record it in the report, and flag
compile-check ACs as unverifiable in any stories you file. Never claim a
SwiftUI view "works" — you reviewed it statically, at best.

### Reviewing stale diffs
If `last-green-sha` is far behind HEAD, the diff is large and noisy. Still
review it, but focus on the most recent night-shift output (last 1-2 runs)
for per-story assessment. The full-range grep is still valuable for
accumulated static-analysis drift.

### Filing duplicates
Always `ls docs/stories/qa-*.md` and skim titles before filing. A
re-occurrence of a known defect is an annotation to the existing story, not
a new file. Duplicate files make night-shift implement the same fix twice.

### Moving done/ files back
Night-shift archives processed stories to `docs/stories/done/`. If QA finds
a story failed, do NOT move it back to `failed/` or top-level. File a
`qa-NN-<slug>.md` regression story and let night-shift pick it up fresh.
The original stays in `done/` as a record.

### Blaming code for environment failures
If `docker compose run` itself fails, that's an infra issue, not a code
defect. File `qa-infra` and stop. Don't write `qa-NN` stories blaming the
app for a broken container.

## Cron job setup

Three modes. The skill is the same; the trigger differs.

### Mode 1: On-demand (manual trigger)

```bash
# From a chat session:
hermes cron run <qa-job-id>
# Or just ask the agent: "run QA on the latest changes"
```

### Mode 2: Weekly full audit (Saturdays at 2 AM)

```bash
hermes cron create \
  --name "qa-weekly" \
  --schedule "0 2 * * 6" \
  --skill qa-night-shift \
  --prompt "Run the full QA pipeline: read .qa/last-green-sha, review <last-green-sha>..HEAD, run build/test/static stages inside the docker compose container, file qa-NN stories for any defects, update the ledger, deliver the report. If the container is unavailable, fall back to static-only review and mark YELLOW." \
  --workdir /home/code/kgx \
  --deliver origin \
  --enabled-toolsets terminal,file,delegation
```

### Mode 3: In-process after night-shift (primary)

QA runs as part of the night-shift cron job itself — no separate cron job.
The night-shift job (87b3c300736e) loads both `night-shift` and `qa-night-shift`
skills. After night-shift finishes its implementation pass and writes
`docs/night-shift-summary.md`, it immediately runs the QA pipeline in the same
session. If night-shift processed zero stories (empty inbox / housekeeping),
QA is skipped entirely — no wasted runs, no false alerts.

This replaced the old `qa-after-nightshift` cron job (daily 3 AM, chained via
`context_from`). That approach had two problems: it ran every day regardless
of whether night-shift did anything, and it couldn't share session context
with the night-shift run. The in-process model solves both.

**Setup:** the night-shift cron job already has `qa-night-shift` in its skills
list and its prompt includes QA instructions. No additional cron job needed.

**Schedule tips:**
- `0 2 * * 6` — Saturdays at 2 AM (weekly full audit, still a separate cron)
- Night-shift runs daily at 2 AM; QA runs in-process within that same session

## See also

- `night-shift` skill — the implementation consumer. Processes the `qa-NN`
  stories this skill files.
- `night-shift-stories` skill — the authoring format. **Load before filing.**
- `code-review` skill — pre-commit verification (different scope: catches
  issues before they land, doesn't file stories).
- Project `.qa/README.md` — ledger state documentation.
