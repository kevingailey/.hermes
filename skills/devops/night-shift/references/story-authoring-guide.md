# Story Authoring Guide

How to write stories that night-shift parses correctly. This is the agent-facing
version of the project-level `docs/HOWTO-WRITE-STORIES.md`.

## Two accepted formats

### User Story (preferred for most work)

```markdown
# Story: Feature Name

As a [role], I want to [capability] so that [benefit].

## Tags
bugfix, playback, critical

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Notes
Optional: implementation details, dependencies, constraints.
```

### Full PRD (for larger features)

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

## Rules

1. **One feature per file.** Multiple features = one plan = harder to review partial results.
2. **Required intent signal.** The file must have either `## Goal` (PRD) or a user-story
   sentence ("As a… I want… so that…"). Without one, the parser fails and the file
   moves to `docs/stories/failed/`.
3. **Acceptance Criteria with `- [ ]` checkboxes is the contract.** Night-shift checks
   each box against what it built. Vague or missing AC = unverifiable work = it claims
   success you can't confirm.
4. **Technical Context / Notes steers the implementation.** Be specific: exact file paths,
   protocol names, library URLs, patterns to follow. The more concrete, the better.
5. **Tags are optional** — comma-separated, one line. Metadata only; recorded in the
   summary for grouping. Absent tags report as `(none)`.
6. **Filename order = processing order.** Prefix with a number if order matters
   (`differnttv-01-scaffold.md` before `differnttv-11-playback.md`).
7. **Commit before the cron run.** Night-shift checks out the latest commit —
   uncommitted story files are invisible.

## Converting bug reports to stories

Bug reports (table header + Description + Evidence + Fix) are NOT in story format
and night-shift will not parse them reliably. Convert them:

```markdown
# Story: Fix BUG-001 — TVProgram Identifiable conformance

As a developer, I want GuideGridView to compile so that the project builds.

## Tags
bugfix, critical, build-blocker

## Acceptance Criteria
- [ ] `ForEach(programs)` in GuideGridView.swift:104 uses an explicit `id:` key path
- [ ] `xtool dev build` passes
- [ ] No new compiler warnings introduced

## Technical Context
- Bug report: docs/stories/BUG-001.md (do not delete — this story references it)
- File: Sources/DifferntTV/Views/Guide/GuideGridView.swift:104
- GuideRowView.swift:48 already does it correctly: `ForEach(programs.prefix(5), id: \.startTime)`

## Notes
- This is a compile blocker. Fix before other BUG-00x stories that touch SwiftUI.
```

Key differences from the bug report:
- Title says "Story:" not "BUG-"
- User-story sentence replaces Description/Evidence
- Acceptance criteria are testable checkboxes, not prose
- Technical context points to the bug report by path — don't duplicate it
- Leave the original bug report outside `docs/stories/` (e.g. `docs/bugs/`)

## Toolchain warning

Before writing stories with compile-check ACs (`xtool dev build passes`,
`swift build passes`, etc.), confirm the toolchain works in the execution
environment. If it doesn't, night-shift writes code blind, claims ACs met,
and you discover failures at the next real build. Either fix the toolchain
first or mark compile-check ACs as unverifiable in the story's Notes.
