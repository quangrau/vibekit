#!/bin/bash
# Phase Tracker Script for Solo Builder
# Reports current phase progress across all phases

# Check if docs directory exists
if [ ! -d "docs" ]; then
    echo "No docs/ directory found. Not a Solo Builder project."
    exit 1
fi

if [ ! -f "docs/MASTER_PLAN.md" ]; then
    echo "No docs/MASTER_PLAN.md found."
    exit 1
fi

echo "=== PHASE PROGRESS TRACKER ==="
echo ""

ACTIVE_PHASE=""
TOTAL_PHASES=0
COMPLETED_PHASES=0

# Iterate through phase directories in order
for phase_dir in docs/phase_*/; do
    [ -d "$phase_dir" ] || continue
    phase_name=$(basename "$phase_dir")
    TOTAL_PHASES=$((TOTAL_PHASES + 1))

    # Implementation progress
    IMPL_TOTAL=0
    IMPL_DONE=0
    if [ -f "${phase_dir}IMPLEMENTATION.md" ]; then
        IMPL_TOTAL=$(grep -c '^\s*- \[' "${phase_dir}IMPLEMENTATION.md" 2>/dev/null || echo "0")
        IMPL_DONE=$(grep -c '^\s*- \[x\]' "${phase_dir}IMPLEMENTATION.md" 2>/dev/null || echo "0")
    fi

    # Test progress
    TEST_STATUS="No test plan"
    if [ -f "${phase_dir}TEST_PLAN.md" ]; then
        TEST_TOTAL=$(grep -c '| .* | .* |' "${phase_dir}TEST_PLAN.md" 2>/dev/null || echo "0")
        TEST_PASS=$(grep -ci '| PASS' "${phase_dir}TEST_PLAN.md" 2>/dev/null || echo "0")
        TEST_FAIL=$(grep -ci '| FAIL' "${phase_dir}TEST_PLAN.md" 2>/dev/null || echo "0")
        TEST_PENDING=$(grep -ci '| PENDING' "${phase_dir}TEST_PLAN.md" 2>/dev/null || echo "0")

        if [ "$TEST_PENDING" -gt 0 ]; then
            TEST_STATUS="PENDING ($TEST_PASS pass, $TEST_FAIL fail, $TEST_PENDING pending)"
        elif [ "$TEST_FAIL" -gt 0 ]; then
            TEST_STATUS="FAILING ($TEST_PASS pass, $TEST_FAIL fail)"
        elif [ "$TEST_PASS" -gt 0 ]; then
            TEST_STATUS="ALL PASS ($TEST_PASS tests)"
        else
            TEST_STATUS="Test plan exists, no results yet"
        fi
    fi

    # Research status
    RESEARCH_STATUS="Not started"
    if [ -f "${phase_dir}RESEARCH.md" ]; then
        RESEARCH_STATUS="Complete"
    fi

    # Determine phase status
    PHASE_STATUS="pending"
    if [ "$IMPL_TOTAL" -gt 0 ] && [ "$IMPL_DONE" -eq "$IMPL_TOTAL" ] && [ -f "${phase_dir}TEST_PLAN.md" ]; then
        TEST_FAIL_COUNT=$(grep -ci '| FAIL' "${phase_dir}TEST_PLAN.md" 2>/dev/null || echo "0")
        TEST_PENDING_COUNT=$(grep -ci '| PENDING' "${phase_dir}TEST_PLAN.md" 2>/dev/null || echo "0")
        if [ "$TEST_FAIL_COUNT" -eq 0 ] && [ "$TEST_PENDING_COUNT" -eq 0 ]; then
            PHASE_STATUS="completed"
            COMPLETED_PHASES=$((COMPLETED_PHASES + 1))
        else
            PHASE_STATUS="testing"
        fi
    elif [ "$IMPL_DONE" -gt 0 ]; then
        PHASE_STATUS="in_progress"
    fi

    # Identify active phase
    MARKER=""
    if [ "$PHASE_STATUS" != "completed" ] && [ -z "$ACTIVE_PHASE" ]; then
        ACTIVE_PHASE="$phase_name"
        MARKER=" <-- ACTIVE"
    fi

    # Print phase summary
    echo "[$phase_name] Status: $PHASE_STATUS$MARKER"
    echo "  Implementation: $IMPL_DONE/$IMPL_TOTAL tasks"
    echo "  Research: $RESEARCH_STATUS"
    echo "  Tests: $TEST_STATUS"
    echo ""
done

# Summary
echo "--- Summary ---"
echo "Total phases: $TOTAL_PHASES"
echo "Completed: $COMPLETED_PHASES/$TOTAL_PHASES"
if [ -n "$ACTIVE_PHASE" ]; then
    echo "Active phase: $ACTIVE_PHASE"
else
    if [ "$TOTAL_PHASES" -gt 0 ]; then
        echo "All phases completed!"
    fi
fi
echo "=== END PHASE TRACKER ==="
