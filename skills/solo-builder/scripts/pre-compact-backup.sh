#!/bin/bash
# Pre-Compact Backup Script for Solo Builder
# Saves phase state before context compaction so recovery script can restore it

# Check if we're in a Solo Builder project
if [ ! -f "docs/MASTER_PLAN.md" ]; then
    exit 0  # Not a Solo Builder project, skip
fi

# Find current phase (first non-completed)
CURRENT_PHASE=""
CURRENT_PHASE_NAME=""
for phase_dir in docs/phase_*/; do
    [ -d "$phase_dir" ] || continue
    dir_name=$(basename "$phase_dir")

    # Extract phase number from directory name (e.g., phase_1_setup -> 1)
    phase_num=$(echo "$dir_name" | sed 's/phase_\([0-9]*\).*/\1/')
    phase_label=$(echo "$dir_name" | sed 's/phase_[0-9]*_//')

    if [ -f "${phase_dir}IMPLEMENTATION.md" ]; then
        TOTAL=$(grep -c '^\s*- \[' "${phase_dir}IMPLEMENTATION.md" 2>/dev/null || echo "0")
        DONE=$(grep -c '^\s*- \[x\]' "${phase_dir}IMPLEMENTATION.md" 2>/dev/null || echo "0")

        # If not all tasks done, this is the current phase
        if [ "$TOTAL" -eq 0 ] || [ "$DONE" -lt "$TOTAL" ]; then
            CURRENT_PHASE="$phase_num"
            CURRENT_PHASE_NAME="$phase_label"
            COMPLETED_TASKS="$DONE"
            TOTAL_TASKS="$TOTAL"
            break
        fi
    else
        # No IMPLEMENTATION.md means phase hasn't started
        CURRENT_PHASE="$phase_num"
        CURRENT_PHASE_NAME="$phase_label"
        COMPLETED_TASKS="0"
        TOTAL_TASKS="0"
        break
    fi
done

# If all phases are done, mark last phase
if [ -z "$CURRENT_PHASE" ]; then
    CURRENT_PHASE="all_complete"
    CURRENT_PHASE_NAME="all_complete"
    COMPLETED_TASKS="0"
    TOTAL_TASKS="0"
fi

# Get timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check if there's a test plan for current phase
HAS_TEST_PLAN="false"
for phase_dir in docs/phase_${CURRENT_PHASE}_*/; do
    [ -d "$phase_dir" ] || continue
    if [ -f "${phase_dir}TEST_PLAN.md" ]; then
        HAS_TEST_PLAN="true"
    fi
done

# Save state to JSON
cat > docs/.phase-state.json << EOF
{
  "current_phase": $CURRENT_PHASE,
  "phase_name": "$CURRENT_PHASE_NAME",
  "completed_tasks": $COMPLETED_TASKS,
  "total_tasks": $TOTAL_TASKS,
  "has_test_plan": $HAS_TEST_PLAN,
  "timestamp": "$TIMESTAMP"
}
EOF

echo "Solo Builder: Phase state saved to docs/.phase-state.json"
