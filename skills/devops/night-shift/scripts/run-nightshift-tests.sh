#!/usr/bin/env bash
# run-nightshift-tests.sh — Run night-shift pipeline test fixtures and verify results
#
# Stages fixture stories into docs/stories/, triggers night-shift, then verifies
# that each fixture landed in done/ or failed/ as expected and the summary shows
# correct tags / error indicators.
#
# Usage:
#   ./run-nightshift-tests.sh                # run all fixtures (except TEST-13)
#   ./run-nightshift-tests.sh --with-toolchain  # include TEST-13 (requires working toolchain)
#   ./run-nightshift-tests.sh --dry-run        # stage fixtures, show plan, don't trigger
#   ./run-nightshift-tests.sh --cleanup       # remove scratch files, no run
#   ./run-nightshift-tests.sh --verify         # verify results after night-shift completed
#
# Prerequisites:
#   - Fixture files in docs/stories/test-fixtures/ (TEST-01 through TEST-17)
#   - Night-shift cron job created (set NIGHTSHIFT_JOB_ID below)
#   - git repo at project root
#
set -euo pipefail

#=== CONFIG — adjust per project ===
PROJECT_ROOT="${PROJECT_ROOT:-/home/code/kgx}"
STORIES_DIR="$PROJECT_ROOT/docs/stories"
FIXTURES_DIR="$STORIES_DIR/test-fixtures"
NIGHTSHIFT_JOB_ID="${NIGHTSHIFT_JOB_ID:-87b3c300736e}"
SUMMARY_FILE="$PROJECT_ROOT/docs/night-shift-summary.md"
#===================================

BACKUP_DIR="$STORIES_DIR/.test-backup-$$"
INCLUDE_TOOLCHAIN=0
DRY_RUN=0
CLEANUP_ONLY=0
VERIFY_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --with-toolchain) INCLUDE_TOOLCHAIN=1 ;;
    --dry-run)        DRY_RUN=1 ;;
    --cleanup)        CLEANUP_ONLY=1 ;;
    --verify)         VERIFY_ONLY=1 ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

cd "$PROJECT_ROOT"

# --- Cleanup-only mode ---
if [ "$CLEANUP_ONLY" -eq 1 ]; then
  echo "=== Cleanup mode ==="
  rm -f Sources/DifferntTV/Fixtures/Test*.swift
  rmdir Sources/DifferntTV/Fixtures 2>/dev/null || true
  echo "Scratch files removed."
  exit 0
fi

# --- Verify-only mode (run after night-shift completed) ---
if [ "$VERIFY_ONLY" -eq 1 ]; then
  echo "=== Verification mode ==="
  if [ ! -f "$SUMMARY_FILE" ]; then
    echo "ERROR: No summary file found at $SUMMARY_FILE"
    echo "Night-shift may not have run yet."
    exit 1
  fi
  echo "Summary file: $SUMMARY_FILE"
  echo ""
  echo "Expected outcomes (see references/test-fixtures-verify.md for full checklist):"
  echo "  TEST-01,02:     done/  Tags: (none)"
  echo "  TEST-03,04,05:  failed/ (parse error, empty, no AC)"
  echo "  TEST-06:        done/  Tags: fixture, tags-test, unit"
  echo "  TEST-07:        done/  Tags: fixture, tags-test, prd"
  echo "  TEST-08,09:     done/  Tags: (none)"
  echo "  TEST-10:        done/ or failed/  summary references BUG-006"
  echo "  TEST-11:        done/ or failed/  summary references BUG-001"
  echo "  TEST-12:        done/  AC flagged unverifiable (missing toolchain)"
  echo "  TEST-14:        failed/ (frontmatter parse error)"
  echo "  TEST-15:        done/  (ambiguous AC)"
  echo "  TEST-16:        done/  (pre-checked AC noted)"
  echo "  TEST-17:        failed/ (non-markdown)"
  echo ""
  echo "Done files:"
  ls "$STORIES_DIR/done"/TEST-* 2>/dev/null || echo "  (none)"
  echo "Failed files:"
  ls "$STORIES_DIR/failed"/TEST-* 2>/dev/null || echo "  (none)"
  echo ""
  echo "Summary excerpt (TEST lines):"
  grep -i "test-" "$SUMMARY_FILE" || echo "  (no TEST entries found in summary)"
  exit 0
fi

# --- Preflight ---
if [ ! -d "$FIXTURES_DIR" ]; then
  echo "ERROR: Fixtures directory not found: $FIXTURES_DIR"
  echo "Create test fixtures first (see references/test-fixtures-verify.md)"
  exit 1
fi

FIXTURE_COUNT=$(find "$FIXTURES_DIR" -maxdepth 1 -type f \( -name 'TEST-*.md' -o -name 'TEST-*.txt' \) | wc -l)
if [ "$FIXTURE_COUNT" -lt 16 ]; then
  echo "ERROR: Expected 16+ fixture files, found $FIXTURE_COUNT"
  find "$FIXTURES_DIR" -maxdepth 1 -type f -name 'TEST-*'
  exit 1
fi

echo "=== Night-Shift Test Suite ==="
echo "Fixtures found: $FIXTURE_COUNT"
echo "Project root:   $PROJECT_ROOT"
echo "Job ID:         $NIGHTSHIFT_JOB_ID"
echo ""

# --- Backup existing top-level stories ---
echo "[1/4] Backing up existing stories..."
mkdir -p "$BACKUP_DIR"
find "$STORIES_DIR" -maxdepth 1 -type f -name '*.md' -exec mv {} "$BACKUP_DIR/" \;
echo "Backed up $(find "$BACKUP_DIR" -maxdepth 1 -type f | wc -l) files to $BACKUP_DIR"

# --- Copy fixtures to top level ---
echo ""
echo "[2/4] Copying fixtures to docs/stories/..."
for f in "$FIXTURES_DIR"/TEST-*.md "$FIXTURES_DIR"/TEST-*.txt; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  if [[ "$base" == "TEST-13"* ]] && [ "$INCLUDE_TOOLCHAIN" -eq 0 ]; then
    echo "  SKIP $base (use --with-toolchain to include)"
    continue
  fi
  cp "$f" "$STORIES_DIR/$base"
  echo "  COPIED $base"
done

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  echo "[DRY RUN] Fixtures staged. Not committing or triggering night-shift."
  echo "Top-level files now in docs/stories/:"
  find "$STORIES_DIR" -maxdepth 1 -type f -name 'TEST-*' -printf '  %f\n' | sort
  echo ""
  echo "Run without --dry-run to execute."
  # Restore originals
  rm -f "$STORIES_DIR"/TEST-*.md "$STORIES_DIR"/TEST-*.txt
  mv "$BACKUP_DIR"/*.md "$STORIES_DIR/" 2>/dev/null || true
  rmdir "$BACKUP_DIR" 2>/dev/null || true
  echo "(Originals restored from backup)"
  exit 0
fi

# --- Commit fixtures ---
echo ""
echo "[3/4] Committing fixtures..."
git add docs/stories/TEST-*.md docs/stories/TEST-*.txt 2>/dev/null || true
if git diff --cached --quiet; then
  echo "No changes to commit (fixtures may already be committed)."
else
  git commit -m "test: add night-shift fixture stories"
  echo "Committed."
fi

# --- Trigger night-shift ---
echo ""
echo "[4/4] Triggering night-shift (cron run $NIGHTSHIFT_JOB_ID)..."
echo "This may take several minutes."
hermes cron run "$NIGHTSHIFT_JOB_ID" || {
  echo "ERROR: Failed to trigger night-shift. Restore stories with:"
  echo "  cp $BACKUP_DIR/*.md $STORIES_DIR/"
  exit 1
}

echo ""
echo "Night-shift triggered. Wait for completion, then run:"
echo "  ./run-nightshift-tests.sh --verify"
echo ""
echo "Backup of original stories: $BACKUP_DIR"
echo "Summary will be written to: $SUMMARY_FILE"
