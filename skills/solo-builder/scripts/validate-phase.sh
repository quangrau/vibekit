#!/bin/bash
# Phase Validation Script for Solo Builder
# Gate script: validates a phase is complete before moving to the next one
# Usage: validate-phase.sh <phase_directory>
# Example: validate-phase.sh docs/phase_2_core_features

PHASE_DIR="$1"

if [ -z "$PHASE_DIR" ]; then
    echo "Usage: validate-phase.sh <phase_directory>"
    echo "Example: validate-phase.sh docs/phase_1_setup"
    exit 1
fi

if [ ! -d "$PHASE_DIR" ]; then
    echo "FAIL: Directory '$PHASE_DIR' does not exist."
    exit 1
fi

PHASE_NAME=$(basename "$PHASE_DIR")
ERRORS=0

echo "=== Validating: $PHASE_NAME ==="
echo ""

# Check 1: IMPLEMENTATION.md exists and all tasks complete
echo "Check 1: Implementation tasks..."
if [ ! -f "${PHASE_DIR}/IMPLEMENTATION.md" ]; then
    echo "  FAIL: IMPLEMENTATION.md not found"
    ERRORS=$((ERRORS + 1))
else
    TOTAL=$(grep -c '^\s*- \[' "${PHASE_DIR}/IMPLEMENTATION.md" 2>/dev/null || echo "0")
    DONE=$(grep -c '^\s*- \[x\]' "${PHASE_DIR}/IMPLEMENTATION.md" 2>/dev/null || echo "0")
    REMAINING=$((TOTAL - DONE))

    if [ "$TOTAL" -eq 0 ]; then
        echo "  WARN: No tasks found in IMPLEMENTATION.md"
    elif [ "$REMAINING" -gt 0 ]; then
        echo "  FAIL: $REMAINING/$TOTAL tasks incomplete"
        # Show incomplete tasks
        grep '^\s*- \[ \]' "${PHASE_DIR}/IMPLEMENTATION.md" | while read -r task; do
            echo "    - $task"
        done
        ERRORS=$((ERRORS + 1))
    else
        echo "  PASS: All $TOTAL tasks completed"
    fi
fi

# Check 2: TEST_PLAN.md exists
echo ""
echo "Check 2: Test plan exists..."
if [ ! -f "${PHASE_DIR}/TEST_PLAN.md" ]; then
    echo "  FAIL: TEST_PLAN.md not found"
    ERRORS=$((ERRORS + 1))
else
    echo "  PASS: TEST_PLAN.md exists"
fi

# Check 3: All tests in TEST_PLAN.md are marked as passed
echo ""
echo "Check 3: Test results..."
if [ -f "${PHASE_DIR}/TEST_PLAN.md" ]; then
    FAIL_COUNT=$(grep -ci '| FAIL' "${PHASE_DIR}/TEST_PLAN.md" 2>/dev/null || echo "0")
    PENDING_COUNT=$(grep -ci '| PENDING' "${PHASE_DIR}/TEST_PLAN.md" 2>/dev/null || echo "0")
    PASS_COUNT=$(grep -ci '| PASS' "${PHASE_DIR}/TEST_PLAN.md" 2>/dev/null || echo "0")

    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo "  FAIL: $FAIL_COUNT test(s) marked as FAIL"
        ERRORS=$((ERRORS + 1))
    fi

    if [ "$PENDING_COUNT" -gt 0 ]; then
        echo "  FAIL: $PENDING_COUNT test(s) still PENDING"
        ERRORS=$((ERRORS + 1))
    fi

    if [ "$PASS_COUNT" -gt 0 ] && [ "$FAIL_COUNT" -eq 0 ] && [ "$PENDING_COUNT" -eq 0 ]; then
        echo "  PASS: All $PASS_COUNT tests passed"
    elif [ "$PASS_COUNT" -eq 0 ] && [ "$FAIL_COUNT" -eq 0 ] && [ "$PENDING_COUNT" -eq 0 ]; then
        echo "  WARN: No test results found in TEST_PLAN.md"
    fi
else
    echo "  SKIP: No TEST_PLAN.md to check"
fi

# Check 4: SPEC.md exists
echo ""
echo "Check 4: Phase spec exists..."
if [ ! -f "${PHASE_DIR}/SPEC.md" ]; then
    echo "  WARN: SPEC.md not found (expected for phase documentation)"
else
    echo "  PASS: SPEC.md exists"
fi

# Final result
echo ""
echo "=== Validation Result ==="
if [ "$ERRORS" -eq 0 ]; then
    echo "PASS: $PHASE_NAME is complete. Ready to proceed to next phase."
    exit 0
else
    echo "FAIL: $PHASE_NAME has $ERRORS issue(s) to resolve before moving on."
    exit 1
fi
