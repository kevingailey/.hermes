---
name: project-manager
description: "Take multimodal input (text, images, screenshots, diagrams) and build structured PRDs through Socratic questioning."
version: 1.2.0
---

# Project Manager — PRD Elicitation

## Overview

Take raw, fuzzy input — a paragraph, a screenshot of a whiteboard, a napkin sketch, a competitor's UI, a voice memo transcript, a bug report thread — and turn it into a structured PRD through Socratic questioning. The output is a PRD ready for dev-lead decomposition.

**Core principle:** The user has the vision. You have the structure. Together you build the spec.

## Input

Anything the user provides. Common forms:

| Type | How to handle |
|------|---------------|
| **Text description** | Read, extract key points, identify gaps |
| **Screenshot / image** | Describe what you see, ask clarifying questions about intent |
| **Whiteboard photo** | Identify components, flows, relationships. Ask about missing pieces |
| **UI mockup / wireframe** | Describe layout, identify user actions, ask about states (empty, error, loading) |
| **Competitor reference** | Ask what they like and what they'd change |
| **Bug report / feature request** | Extract the problem, the expected behavior, the context |
| **Voice memo transcript** | Treat as raw text — extract signal, identify ambiguity |
| **Diagram / flowchart** | Trace the paths, identify decision points, ask about error paths |
| **Multiple inputs** | Cross-reference, find contradictions, merge into one coherent picture |

## Output

Two output formats, chosen by the user:

### Project Spec (broader — use when starting a new project)

Written to `<project-root>/docs/project_spec.md`. A project spec captures the full vision: what, why, goals, and success criteria. It comes before a PRD in the pipeline.

```markdown
# Project Spec: <Project Name>

## Overview
One paragraph describing what this builds and why.

## Summary
Detailed description of the project — features, scope, user experience.

## Goals
- Goal 1
- Goal 2

## Success Criteria
- [ ] Criterion 1 (each should be testable)
- [ ] Criterion 2

## Requirements
Functional requirements organized by feature area.

## Technical Context
Architecture preferences, constraints, libraries, patterns, existing code to modify.

## Out of Scope
Things explicitly not part of this project (to prevent scope creep).

## Open Questions
Things that need decisions but weren't resolved during elicitation.
```

### PRD (focused — use for a specific feature or phase)

Written to `<project-root>/docs/prds/<project-slug>-prd.md`. A PRD is more focused than a project spec — it's what dev-lead consumes to decompose into stories.

```markdown
# PRD: <Project Name>

## Goal
One sentence describing what this builds and why.

## Requirements
- Bullet list of functional requirements
- Each should be testable

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Technical Context
Architecture preferences, constraints, libraries, patterns, existing code to modify.

## Out of Scope
Things explicitly not part of this PRD (to prevent scope creep).

## Open Questions
Things that need decisions but weren't resolved during elicitation.
```

This format is directly compatible with the **dev-lead** skill's input format.

**Which to use:** If the user says "project spec", "spec", "overview", or is starting a new project, write a project_spec.md. If they say "PRD", "requirements doc", or are specifying a feature within an existing project, write a PRD. When in doubt, ask.

The project root is determined by:
1. The `--workdir` of the cron job (for night-shift runs)
2. The current working directory (for interactive sessions)
3. The `$PROJECT_ROOT` environment variable if set

## Elicitation Process

### Phase 1: Absorb

Take in whatever the user provides. Don't ask questions yet. Process:

1. **If text** — read it, identify the core idea, user roles, capabilities, outcomes
2. **If image/screenshot** — describe what you see in detail. Identify UI elements, flows, data relationships. Note what's unclear or ambiguous
3. **If diagram** — trace the flow, identify components and their relationships, note missing connections
4. **If multiple inputs** — cross-reference them. Note contradictions, overlaps, and gaps

Then state your understanding concisely. "Here's what I'm seeing..." This confirms you processed their input and gives them a chance to correct before you start questioning.

### Phase 2: Question

Use the **clarify** tool for Socratic questioning. It supports both multiple-choice (up to 4 options) and open-ended modes. Present concrete options to react to — interpretations, specific examples, or concrete choices that reveal priorities. When the user wants to explain freely, use open-ended mode (no choices array).

**Question strategy:** Batch independent questions if possible, but most elicitation questions depend on prior answers — ask sequentially. Use multiple-choice when you have specific interpretations to offer. Use open-ended when you need them to describe something in their own words.

**Philosophy:**
- You are a thinking partner, not an interviewer
- Don't interrogate. Collaborate. Don't follow a script. Follow the thread.
- Start open. Let them dump their mental model. Don't interrupt with structure.
- Follow energy. Whatever they emphasized, dig into that.
- Challenge vagueness. "Good" means what? "Users" means who? "Simple" means how?
- Make the abstract concrete. "Walk me through using this." "What does that actually look like?"

**Key areas to clarify (mental checklist, not a script):**

| Area | Questions |
|------|-----------|
| **Goal** | What's the one thing this needs to do? What problem does it solve? |
| **Users** | Who uses this? Different roles? Different permissions? |
| **Capabilities** | What can each user do? What's the happy path? |
| **Edge cases** | What happens when something goes wrong? Empty states? Errors? |
| **Constraints** | Any technical requirements? Performance targets? Platform targets? |
| **Existing context** | Does this extend something existing? What patterns should it follow? |
| **Out of scope** | What are you explicitly NOT building right now? |

**Good clarify options:**
- Interpretations of what they might mean (e.g., "Sub-second response", "Handles large datasets", "Quick to build")
- Specific examples to confirm or deny
- Concrete choices that reveal priorities

**Bad clarify options:**
- Generic categories ("Technical", "Business", "Other")
- Leading options that presume an answer
- More than 4 options (the tool limit)

**When the user selects "Other" or wants to explain freely:** switch to open-ended clarify (omit choices array) and ask as plain text. Wait for their full response before resuming structured questions.

**Background research during elicitation:** If the user's answers reveal a research gap (e.g., "I'm open to other players but we need to research options"), dispatch a `delegate_task` subagent to research while you continue questioning on other topics. The research results will arrive asynchronously and you can incorporate them into the spec/PRD. This keeps the elicitation moving without blocking on research.

**Anti-patterns:**
- Checklist walking through domains regardless of what they said
- Canned questions that don't build on their answers
- Corporate speak ("stakeholders", "success criteria", "core value proposition")
- Interrogation — firing questions without building on answers
- Rushing to get to "the work"
- Shallow acceptance of vague answers
- Premature constraints — asking about tech stack before understanding the idea
- Asking about the user's technical experience — you build, they describe

### Phase 3: Converge

When you have enough clarity to write the spec/PRD, use clarify to offer proceeding:

> "I think I have enough to write the [project_spec / PRD]. Ready for me to draft it?"

Options:
- **"Draft it"** — write the document
- **"Keep exploring"** — they have more to share or you missed something
- **"Show me what you have"** — preview the structure before committing

Loop until they're satisfied. Summarize what you've gathered as part of the convergence — this lets the user verify your understanding before you commit to writing.

### Phase 4: Write

Write the document to the appropriate path:
- **Project spec** → `<project-root>/docs/project_spec.md`
- **PRD** → `<project-root>/docs/prds/<slug>-prd.md`

Ensure the directory exists (create it if not). After writing, offer next steps:

> "Saved to docs/project_spec.md. Want me to decompose it into stories with dev-lead?"

Or if a PRD:

> "PRD saved to docs/prds/<slug>-prd.md. Want me to decompose it into stories with dev-lead?"

## Handling Ambiguity

| Signal | Response |
|--------|----------|
| Vague capability ("it should be fast") | "Fast how? Sub-second response? Handles large datasets? Quick to build?" |
| Missing user role ("users can...") | "Who are these users? Different types?" |
| Undefined scope ("basic search") | "What fields are searchable? What's 'basic' vs 'advanced'?" |
| Missing error behavior | "What happens when it fails? Network error? Empty results?" |
| "Like X but better" | "What specifically about X do you like? What would you change?" |
| Image with unclear elements | "I see a box here — what is it? What does it do?" |

## Integration with dev-lead and night-shift

The full pipeline:

```
project-manager → dev-lead → night-shift
     │                │            │
     │                │            └─ implements stories overnight
     │                └─ breaks PRD into PR-sized stories
     └─ builds PRD from raw input
```

After writing a PRD, offer to run dev-lead on it. After dev-lead produces stories, they're in `docs/stories/` ready for night-shift.

## Tips

- **Images are clues, not specs.** A screenshot shows one state. Ask about the other states.
- **The first answer is rarely complete.** Follow up. "You mentioned X — tell me more about that."
- **Write down what they say, not what you infer.** If they say "simple dashboard", write "simple dashboard" in the PRD and flag it as vague. Don't expand it into features they didn't describe.
- **Out of scope is as important as in scope.** Explicitly noting what's NOT being built prevents the PRD from growing during implementation.
- **Open Questions section is honest.** If you couldn't resolve something, put it in the PRD. Better to flag it than to guess.
