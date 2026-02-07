#!/bin/bash
# Context Recovery Script for Solo Builder
# This script is triggered after context compaction to remind agent of workflow

# Check if we're in a Solo Builder project (has docs/MASTER_PLAN.md or legacy PRD.md)
if [ ! -f "docs/MASTER_PLAN.md" ] && [ ! -f "PRD.md" ]; then
    exit 0  # Not a Solo Builder project, skip
fi

echo "=== SOLO BUILDER CONTEXT RECOVERY ==="
echo ""
echo "Context was compacted. Re-reading critical files to stay on track."
echo ""

# Check for phase state backup (from pre-compact-backup.sh)
if [ -f "docs/.phase-state.json" ]; then
    echo "### Phase State (from pre-compact backup):"
    cat docs/.phase-state.json
    echo ""
    echo ""
fi

# Remind about workflow checkpoints
echo "### WORKFLOW CHECKPOINTS (MANDATORY - DO NOT SKIP!)"
echo "| After Step | Action |"
echo "| --- | --- |"
echo "| Phase 1 (Master Plan) complete | -> Present summary -> STOP for Human review |"
echo "| Phase 2 (Review) approved | -> Begin per-phase build cycle |"
echo "| Step 3.4 (Test Plan) created | -> STOP for Human review of test plan |"
echo "| Step 3.6 (Tests) complete | -> Validate phase -> Move to next phase |"
echo ""

# Check current progress from MASTER_PLAN.md
if [ -f "docs/MASTER_PLAN.md" ]; then
    echo "### Master Plan Phase Status:"

    # Find current phase (first non-completed phase)
    CURRENT_PHASE=""
    while IFS='|' read -r _ phase name goal status _; do
        phase=$(echo "$phase" | xargs)
        name=$(echo "$name" | xargs)
        status=$(echo "$status" | xargs)

        # Skip header/separator rows
        [[ "$phase" =~ ^-+$ ]] && continue
        [[ "$phase" == "Phase" ]] && continue
        [[ -z "$phase" ]] && continue

        if [[ "$status" != "completed" ]] && [[ -z "$CURRENT_PHASE" ]]; then
            CURRENT_PHASE="$phase"
            echo "  Phase $phase ($name): $status  <-- CURRENT"
        else
            echo "  Phase $phase ($name): $status"
        fi
    done < <(grep '^\s*|' docs/MASTER_PLAN.md | grep -v '^\s*| Phase |' | grep -v '^\s*| ---')

    echo ""
fi

# Run phase tracker if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/phase-tracker.sh" ]; then
    echo "### Phase Progress Details:"
    bash "$SCRIPT_DIR/phase-tracker.sh"
    echo ""
fi

# Scan phase directories for current progress
if [ -d "docs" ]; then
    for phase_dir in docs/phase_*/; do
        [ -d "$phase_dir" ] || continue
        phase_name=$(basename "$phase_dir")

        if [ -f "${phase_dir}IMPLEMENTATION.md" ]; then
            TOTAL=$(grep -c '^\s*- \[' "${phase_dir}IMPLEMENTATION.md" 2>/dev/null || echo "0")
            DONE=$(grep -c '^\s*- \[x\]' "${phase_dir}IMPLEMENTATION.md" 2>/dev/null || echo "0")

            if [ "$TOTAL" -gt 0 ]; then
                if [ "$DONE" -eq "$TOTAL" ]; then
                    echo "  $phase_name: Implementation $DONE/$TOTAL (COMPLETE)"
                else
                    echo "  $phase_name: Implementation $DONE/$TOTAL"
                fi
            fi
        fi

        if [ -f "${phase_dir}TEST_PLAN.md" ]; then
            TESTS_TOTAL=$(grep -c '^\s*|' "${phase_dir}TEST_PLAN.md" 2>/dev/null || echo "0")
            TESTS_PASS=$(grep -ci 'PASS' "${phase_dir}TEST_PLAN.md" 2>/dev/null || echo "0")
            echo "  $phase_name: Tests - $TESTS_PASS passed"
        fi
    done
    echo ""
fi

echo "### CRITICAL REMINDERS:"
echo "1. Re-read skill file: .claude/skills/solo-builder/SKILL.md"
echo "2. Re-read docs/MASTER_PLAN.md for project overview and current phase"
echo "3. Re-read ONLY the current phase's SPEC.md + IMPLEMENTATION.md"
echo "4. Do NOT load all phases into context (phase isolation rule)"
echo "5. Follow workflow strictly - especially checkpoints!"
echo ""
echo "=== END CONTEXT RECOVERY ==="
