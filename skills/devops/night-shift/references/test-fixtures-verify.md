# Night-Shift Test Fixture Verification Checklist

Test fixtures exercise every parsing, tagging, toolchain-detection, and
edge-case path in the night-shift pipeline. Run via
`scripts/run-nightshift-tests.sh` in the skill directory.

## Fixture inventory (17 files)

Place these in `<project>/docs/stories/test-fixtures/` (not scanned by
night-shift — only top-level files in `docs/stories/` are processed).

### A. Format parsing (5)

| ID | Fixture | Expected |
|----|---------|----------|
| TEST-01 | Well-formed user story | done/, AC 2/2, Tags: (none) |
| TEST-02 | Well-formed PRD | done/, AC 2/2, Tags: (none) |
| TEST-03 | Bug-report format (table, no Goal/story) | failed/, parse error |
| TEST-04 | Empty file (0 bytes) | failed/, empty file error |
| TEST-05 | Title only (`# Story: Foo`) | failed/, no AC / no body |

### B. Tags (4)

| ID | Fixture | Expected |
|----|---------|----------|
| TEST-06 | User story with `Tags: fixture, tags-test, unit` | done/, summary shows those tags |
| TEST-07 | PRD with `Tags: fixture, tags-test, prd` | done/, summary shows those tags |
| TEST-08 | User story with empty `## Tags` section | done/, Tags: (none) |
| TEST-09 | User story with no Tags section | done/, Tags: (none) |

### C. Bug conversion (2)

| ID | Fixture | Expected |
|----|---------|----------|
| TEST-10 | Story referencing bug report by path | done/ or failed/, summary references BUG-006 |
| TEST-11 | BUG-001 converted per template | done/ or failed/, summary references BUG-001 |

### D. Toolchain detection (2)

| ID | Fixture | Expected |
|----|---------|----------|
| TEST-12 | `xtool dev build passes` AC, no toolchain | done/, AC flagged unverifiable |
| TEST-13 | `xtool dev build passes` AC, toolchain present | done/, AC verified (skip if no toolchain) |

### E. Edge cases (4)

| ID | Fixture | Expected |
|----|---------|----------|
| TEST-14 | Malformed YAML frontmatter | failed/, parse error |
| TEST-15 | Duplicate `## Acceptance Criteria` sections | done/, summary notes ambiguity |
| TEST-16 | Pre-checked AC (`- [x]`) | done/, summary notes pre-checked |
| TEST-17 | Non-markdown file (`.txt`) | failed/, parse error |

## Pass/fail criteria

A test PASSES when:
- File landed in the expected directory (done/ or failed/)
- Summary contains expected fields/tags/error indicators

A test FAILS when:
- File in wrong directory
- Tags missing or wrong in summary
- Should-fail fixture ended up in done/ with no error
- Should-pass fixture ended up in failed/
- TEST-12 silently passes `xtool dev build` AC without flagging missing toolchain

## Cleanup

After verification, remove scratch files created by fixtures:
```bash
rm -f Sources/DifferntTV/Fixtures/Test*.swift
rmdir Sources/DifferntTV/Fixtures 2>/dev/null || true
```

The run script (`--cleanup` mode) handles this automatically.
