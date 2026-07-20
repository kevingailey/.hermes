---
name: dev-lead
description: "Take a PRD and decompose it into PR-sized, independently shippable stories — vertical slices, not horizontal layers."
version: 1.1.0
---

# Dev Lead — PRD Decomposition

## Overview

Take a product requirements document and break it into PR-sized stories. Each story is a vertical slice — independently shippable, testable, and small enough to implement in a single night-shift run. Outputs are written to `<project-root>/docs/stories/` so they're in the repo and git-tracked.

**Core principle:** A PRD describes the whole mountain. A story is one switchback you can climb in a day.

## Input

A PRD file (markdown). Can be anywhere — pass the path.

Expected sections:
- **Goal** — what this builds and why
- **Requirements** — functional requirements (bullet list)
- **Acceptance Criteria** — how you'll know it's done
- **Technical Context** — architecture, constraints, patterns (optional but helpful)

If the file doesn't have these sections, the skill will extract them from whatever structure it has.

## Output

A directory of story files, one per PR-sized slice. Written to `<project-root>/docs/stories/`.

The project root is determined by:
1. The `--workdir` of the cron job (for night-shift runs)
2. The current working directory (for interactive sessions)
3. The `$PROJECT_ROOT` environment variable if set

Naming convention: `<project-slug>-<NN>-<kebab-name>.md`

Example for a "User Authentication" PRD:
```
docs/stories/user-auth-01-register.md
docs/stories/user-auth-02-login.md
docs/stories/user-auth-03-password-reset.md
docs/stories/user-auth-04-session-management.md
```

Each story file contains:
- A user story header (`As a... I want to... so that...`)
- Acceptance criteria scoped to that slice
- Technical context relevant to that slice
- Dependencies on other stories (if any)

## Decomposition Process

### Phase 1: Read & Understand

Read the full PRD. Identify:
- The user roles involved
- The core capability being built
- The outcome/benefit
- All functional requirements
- Technical constraints

### Phase 2: Identify Slice Boundaries

Walk the requirements and find natural split points. A slice is PR-sized when it:

1. **Delivers user-visible value** — not "create the database schema" but "user can see their dashboard"
2. **Is independently testable** — has its own acceptance criteria that don't depend on later slices
3. **Fits in ~2-5 implementation tasks** — if it needs more, split again
4. **Is a vertical slice** — touches all layers (data → logic → UI/API) for one capability, not one layer for all capabilities

**Signals that a story is too big (needs splitting):**
- "and" joining independent capabilities ("register AND log in AND reset password")
- Multiple user roles in one story
- Would take more than one night-shift run to implement
- Acceptance criteria list is longer than ~8 items
- The story description exceeds ~120 chars

### Phase 3: Apply SPIDR Splitting

Use the SPIDR axes to find the right split:

| Axis | Question | Example Split |
|------|----------|---------------|
| **Spike** | Is there an unknown that needs research first? | Research phase → implementation phase |
| **Paths** | Happy path vs. edge/error paths? | Happy path first, error handling follow-up |
| **Interfaces** | Multiple surfaces (web, API, CLI)? | API first, then web UI, then CLI |
| **Data** | Multiple data scopes? | Single-user first, then multi-tenant |
| **Rules** | Incremental business rules? | Basic validation first, complex policy later |

**Never split by technical layer** (schema → API → UI). That's horizontal planning — reject it.

### Phase 4: Order the Stories

Stories are ordered for sequential delivery:

1. **Foundation first** — any story that unblocks others (auth before dashboard, schema before queries)
2. **Happy path first** — the core capability working end-to-end
3. **Then edge cases** — error handling, validation, edge paths
4. **Then polish** — UX refinements, performance, observability

Each story file includes a `Depends on:` line referencing earlier stories by number.

### Phase 5: Write Story Files

For each slice, write a markdown file to `docs/stories/`:

```markdown
# Story: <short descriptive name>

As a <role>, I want to <capability>, so that <outcome>.

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Technical Context
- Files to touch: <paths>
- Patterns to follow: <existing patterns>
- Dependencies: <story N>

## Notes
<edge cases, gotchas, design decisions>
```

Ensure `docs/stories/` exists (create it if not).

## Dependency Graph

After writing all story files, output a dependency graph showing the execution order and parallelization opportunities. This helps the user review the decomposition and helps night-shift understand which stories can run concurrently.

Format as an ASCII tree or table:

```
01 Scaffold
 └─ 02 Source Protocol
     ├─ 03 Synthetic EPG ─────────────────────────┐
     ├─ 04 HDHomeRun ──┐                           │
     ├─ 05 Jellyfin ───┤                           │
     ├─ 06 M3U ────────┤                           │
     └─ 07 Xtream ─────┘                           │
        08 Settings ◄──┘                           │
         ├─ 09 Guide Grid ◄────────────────────────┤
         │  10 Guide List ◄────────────────────────┤
         │   ├─ 11 Playback ◄──────────────────────┘
         │   ├─ 12 Favorites
         │   ├─ 13 Hide Channels
         │   │   └─ 14 Search ◄── 03
         │   └─ 16 Empty/Offline
         └─ 15 iCloud Sync ◄── 12, 13
```

Note which stories can run in parallel (e.g., "Stories 04-07 can run in parallel — all depend only on 02").

## Verification

After writing all stories, verify:
- [ ] Every requirement from the PRD is covered by at least one story
- [ ] No story is a horizontal layer (all are vertical slices)
- [ ] Each story has ≥1 acceptance criterion
- [ ] Stories are ordered for sequential delivery
- [ ] Dependencies are documented
- [ ] Each story fits in a single night-shift run (~2-5 implementation tasks)

## Integration with night-shift

The output files live in `docs/stories/` in the project repo. The night-shift cron job reads from `docs/stories/` (not `~/.hermes/night-shift/inbox/`). After writing stories, offer to commit them:

```bash
git add docs/stories/
git commit -m "docs: add stories for <feature>"
```

Then night-shift picks them up on its next run.

**Downstream skills:**
- `night-shift-stories` — load this when refining individual story files or
  converting bug reports. It enforces parse-safety, toolchain-AC verifiability,
  and the housekeeping pass that keeps `docs/stories/` clean. Dev-lead
  decomposes; night-shift-stories polishes per-file.
- `qa-night-shift` — after night-shift implements, QA reviews and files
  `qa-NN-<slug>.md` defect stories back into `docs/stories/`. The loop is:
  dev-lead → night-shift → qa-night-shift → night-shift (fixes) → qa-night-shift.

## Example

**PRD input:**
```markdown
# PRD: User Authentication System

## Goal
Users can register, log in, log out, and reset their password.

## Requirements
- Email/password registration
- Email/password login
- Password hashing with bcrypt
- Session management with JWT
- Password reset via email link
- Rate limiting on login attempts
- Account lockout after 5 failed attempts
```

**Output stories:**

`docs/stories/user-auth-01-register.md` — As a new user, I want to register with email and password, so that I can create an account.
`docs/stories/user-auth-02-login.md` — As a registered user, I want to log in with email and password, so that I can access my account.
`docs/stories/user-auth-03-password-reset.md` — As a registered user, I want to reset my password via email, so that I can regain access if I forget it.
`docs/stories/user-auth-04-rate-limit-lockout.md` — As a system, I want to rate-limit login attempts and lock accounts after 5 failures, so that brute-force attacks are mitigated.

## Tips

- **One PRD → multiple stories.** A good PRD decomposes into 3-8 stories. If you get 1, the PRD is too small or you're not splitting enough. If you get 15+, the stories are too granular.
- **Stories are for night-shift.** Each story should be implementable in one autonomous run. If a story needs interactive decisions, it's too vague — add more Technical Context.
- **Dependencies are advisory.** Story 2 might technically depend on Story 1, but if Story 1 is already implemented, Story 2 can run independently. The dependency field is for ordering, not blocking.
- **Review the output.** Read through the stories before dropping them into inbox. A bad split wastes a night-shift run.
