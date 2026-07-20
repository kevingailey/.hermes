---
name: cto
description: "Shape Up framework — shape pitches, run betting tables, track hill charts, and align work across cycles."
version: 1.0.0
---

# CTO — Shape Up Framework

## Overview

Run the Shape Up product development framework: shape rough solutions, set appetites, bet on pitches in cycles, and track progress with hill charts. Integrates with the existing pipeline (project-manager → dev-lead → night-shift) so shaped bets flow into PRDs, stories, and implementation.

**Core principle:** Fixed time, variable scope. Set an appetite (time budget), shape a solution within it, bet on it, then cut scope to stay on schedule — never extend the deadline.

## Shape Up Concepts

| Concept | What it is | Where it lives |
|---------|------------|----------------|
| **Appetite** | Time budget for the work (not an estimate) | In the Pitch |
| **Pitch** | Shaped concept — problem, appetite, solution sketch, rabbit holes | `docs/pitches/<slug>.md` |
| **Bet** | A pitch selected for a cycle | `docs/cycles/cycle-<N>.md` |
| **Cycle** | 6 weeks of building, 2 weeks cooldown | `docs/cycles/` |
| **Hill Chart** | Progress tracking: uphill (figuring out) → downhill (executing) | `docs/hill-charts/` |
| **Scope Banking** | Cutting scope to stay within appetite | In the Cycle plan |
| **Circuit Breaker** | Kill a bet that isn't working | In the Cycle plan |

## Directory Structure

All under `<project-root>/docs/` — git-tracked, in the repo.

```
docs/
├── cycles/               # Cycle plans and betting table outcomes
│   ├── cycle-01.md
│   ├── cycle-02.md
│   └── ...
├── pitches/              # Shaped concepts ready for betting
│   ├── <slug>-pitch.md
│   └── ...
├── hill-charts/          # Progress tracking per cycle
│   ├── cycle-01.md
│   └── ...
├── prds/                 # PRDs (from project-manager)
├── stories/              # Stories (from dev-lead, input to night-shift)
└── plans/                # Implementation plans
```

## The Shape Up Pipeline

```
Shaping ──→ Pitch ──→ Betting Table ──→ Cycle ──→ Build ──→ Ship
   │            │            │              │          │
   │            │            │              │          └─ night-shift
   │            │            │              │             implements
   │            │            │              │
   │            │            │              └─ docs/cycles/cycle-N.md
   │            │            │                  lists the bets
   │            │            │
   │            │            └─ docs/cycles/cycle-N.md
   │            │               (betting table output)
   │            │
   │            └─ docs/pitches/<slug>.md
   │
   └─ docs/pitches/<slug>.md
       (shaped by CTO)
```

## Workflows

### 1. Shape a Pitch

Shaping is rough design — not a spec. You define the problem, set an appetite, sketch a solution, and identify rabbit holes. The output is a Pitch document that's concrete enough to bet on but loose enough to leave implementation decisions to builders.

**When to shape:**
- Before a betting table (cycle planning)
- When an idea is too fuzzy to estimate
- When you need to decide if something is worth 6 weeks

**Pitch template:**

```markdown
# Pitch: <Short Name>

## Problem
The specific problem or opportunity. Who is affected? What's the pain?

## Appetite
- [ ] Small batch (2 weeks) — one sharp feature
- [ ] Big batch (6 weeks) — a meaningful chunk of work

## Solution Sketch
A rough description of the solution. Not a spec — enough to understand the approach.
- Key components
- How it works at a high level
- What changes for the user

## Rabbit Holes
Known risks, tricky parts, or unknowns that could blow the appetite.
- [ ] Rabbit hole 1
- [ ] Rabbit hole 2

## No-Go Boundaries
Things this pitch explicitly does NOT include (scope containment).

## Related
- PRD: docs/prds/<slug>-prd.md (if one exists)
- Stories: docs/stories/<slug>-*.md (if decomposed)
```

**Shaping process:**
1. Understand the problem — what's the actual pain, who feels it
2. Set the appetite — is this a 2-week small batch or 6-week big batch?
3. Sketch the solution — rough, breadboard-level. Wireframes if helpful, but not required
4. Find rabbit holes — what could go wrong or take unexpected time
5. Set boundaries — what's explicitly out of scope
6. Write the pitch to `docs/pitches/<slug>.md`

**Shaping is NOT:**
- A detailed spec or PRD (that comes after betting, via project-manager)
- Implementation planning (that comes after betting, via dev-lead)
- A commitment to build (that happens at the betting table)

### 2. Run a Betting Table

The betting table is where you decide which pitches to fund in the next cycle. It's a decision meeting, not a discussion forum.

**When to run:** Every 6 weeks (end of cycle), during cooldown.

**Input:** All pitches in `docs/pitches/` that haven't been bet on yet.

**Output:** `docs/cycles/cycle-<N>.md`

**Betting table process:**

1. **Review each pitch** — one at a time. For each:
   - Does the problem still matter?
   - Is the appetite right?
   - Are the rabbit holes acceptable?
   - Is this the best use of a cycle?

2. **Decide: Bet, Defer, or Kill**
   - **Bet** — commit to building this cycle. Move to cycle plan.
   - **Defer** — not now, revisit next cycle. Leave in pitches/.
   - **Kill** — not worth doing. Archive or delete the pitch.

3. **Write the cycle plan** — `docs/cycles/cycle-<N>.md`

**Cycle plan template:**

```markdown
# Cycle <N> — <Dates>

## Bets

### Bet 1: <Pitch Name>
- Pitch: docs/pitches/<slug>.md
- Appetite: 6 weeks
- Scope: <what we're building>
- Circuit breaker: <if X happens, kill this bet>

### Bet 2: <Pitch Name>
- Pitch: docs/pitches/<slug>.md
- Appetite: 2 weeks
- Scope: <what we're building>
- Circuit breaker: <if X happens, kill this bet>

## Cooldown
- Start: <date>
- End: <date>

## Notes
<decisions, context, warnings>
```

### 3. Start a Cycle

After the betting table, convert bets into work.

**Process:**
1. For each bet in the cycle plan, run **project-manager** to build a PRD from the pitch
2. Run **dev-lead** to decompose the PRD into stories
3. Stories land in `docs/stories/` — ready for night-shift
4. Create a hill chart in `docs/hill-charts/cycle-<N>.md`

**Hill chart template:**

```markdown
# Hill Chart — Cycle <N>

## Bet 1: <Pitch Name>
- [ ] Uphill — figuring out the approach
- [ ] Top of the hill — approach is clear
- [ ] Downhill — executing known work
- [ ] Done — shipped

## Bet 2: <Pitch Name>
- [ ] Uphill — figuring out the approach
- [ ] Top of the hill — approach is clear
- [ ] Downhill — executing known work
- [ ] Done — shipped
```

### 4. Track Progress

Update hill charts during the cycle. The hill chart shows where each bet is:

```
     ▲
     │  ●  ← Uphill: still figuring out
     │     ●  ← Top: approach is clear
     │        ●  ← Downhill: executing
     │           ●  ← Done
     └─────────────────────────►
```

**Update frequency:** Weekly, or when a bet crosses a milestone.

**Signals:**
- **Stuck uphill** — bet is taking too long to figure out. Consider circuit breaker.
- **Fast downhill** — bet was well-shaped. Good.
- **Scope creep** — team is adding things not in the pitch. Cut scope.

### 5. Circuit Breaker

If a bet is clearly not going to ship within its appetite, kill it.

**When to pull the breaker:**
- Bet is still uphill past the halfway point of the cycle
- A rabbit hole turned into a canyon
- The problem changed or was solved by other work

**How:**
1. Note the kill in `docs/cycles/cycle-<N>.md` under the bet
2. Move any useful code to a branch (don't merge)
3. Reassign the team to another bet or cooldown work
4. Learn from what went wrong — was the pitch too vague? Appetite too small?

### 6. End a Cycle (Cooldown)

The last 2 weeks of every 8-week period are cooldown. No new bets.

**Cooldown activities:**
- Fix bugs and pay down tech debt
- Review what shipped and what didn't
- Shape pitches for the next betting table
- Run the next betting table
- Update `docs/night-shift-summary.md` with cycle retrospective

**Cycle retrospective template:**

```markdown
# Cycle <N> Retrospective

## Shipped
- Bet 1: <name> — shipped on time ✅
- Bet 2: <name> — shipped, cut scope on X ⚠️

## Didn't Ship
- Bet 3: <name> — circuit breaker pulled, rabbit hole Y

## Lessons
- What went well:
- What went wrong:
- What to change next cycle:

## Pitches for Next Betting Table
- docs/pitches/<slug>.md
- docs/pitches/<slug>.md
```

## Integration with the Pipeline

```
Shape Up Layer (CTO skill)
│
├─ Shape → Pitch (docs/pitches/)
│
├─ Betting Table → Cycle Plan (docs/cycles/)
│
├─ Start Cycle → project-manager → dev-lead → docs/stories/
│                                                  │
│                                   night-shift ───┘
│                                        │
│                                   docs/night-shift-summary.md
│                                        │
└─ Cooldown → Retro → Shape next pitches
```

**Step by step:**

1. **CTO shapes** a pitch → `docs/pitches/<slug>.md`
2. **Betting table** selects pitches → `docs/cycles/cycle-<N>.md`
3. **Start cycle** → run project-manager on each bet to produce a PRD
4. **Decompose** → run dev-lead to split PRD into stories → `docs/stories/`
5. **Build** → night-shift implements stories from `docs/stories/`
6. **Track** → update hill charts in `docs/hill-charts/`
7. **Ship or kill** → end of cycle, run cooldown
8. **Repeat** → shape next pitches during cooldown

## When to Use Each Skill

| Situation | Skill |
|-----------|-------|
| Raw idea, no shape | **project-manager** — elicit and write a PRD |
| PRD exists, needs stories | **dev-lead** — decompose into PR-sized stories |
| Stories exist, implement | **night-shift** — build overnight |
| Need to decide what to build | **CTO** — shape pitches, run betting table |
| Need to track progress | **CTO** — hill charts |
| Need to kill a bet | **CTO** — circuit breaker |
| End of cycle | **CTO** — cooldown, retro, shape next |

## Tips

- **Appetite is not an estimate.** It's a constraint. "We have 6 weeks, what can we build?" not "How long will this take?"
- **Pitches are rough.** If a pitch is too detailed, you've over-shaped. Leave room for the builders to make decisions.
- **Circuit breaker is a feature, not a failure.** Killing a bad bet early saves 4+ weeks of wasted work.
- **Scope banking is the escape valve.** When a bet is at risk, cut scope — don't extend the deadline.
- **Hill charts show what you know.** If a bet is still uphill at week 3, something is wrong. Don't wait.
- **Cooldown is sacred.** No new bets during cooldown. It's for fixing, learning, and shaping the next cycle.
- **One pitch per bet.** Don't bundle unrelated features into one pitch — they should be independently bet-able.
- **Pitches feed PRDs, not the other way around.** Shape first, then write the PRD after the bet is placed. The PRD is for the builder, not the bettor.
