# Changelog

All notable changes to this skill will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-02-07

### Added
- Per-phase model selection: sonnet sub-agents for research, test planning, and test execution
- Model Strategy section documenting step-to-model mapping
- Step 1.1c: Setup Sub-Agent Files (Claude Code only) with three agent definitions
- Sub-agent files: `phase-researcher.md`, `test-planner.md`, `test-runner.md` (created during project setup)
- Sub-agent reference table in CLAUDE.md template for context recovery
- Rule 6 (Model Optimization) under Autonomous Execution Rules

### Changed
- Step 3.1 now delegates to `phase-researcher` sub-agent (sonnet) with Gemini fallback
- Step 3.4 now delegates to `test-planner` sub-agent (sonnet) with Gemini fallback
- Step 3.6 now delegates to `test-runner` sub-agent (sonnet) with Gemini fallback
- Step 4.5 now delegates to `test-runner` sub-agent (sonnet) with Gemini fallback
- Rule 24 (Sub-Agent Briefing) updated to reference named sub-agents
- Rules renumbered 7-24 (previously 6-23) to accommodate new rule 6

## [2.0.0] - 2026-02-07

### Changed
- Renamed skill from `vibe-builder` to `solo-builder`
- Replaced monolithic `PRD.md` with lean `docs/MASTER_PLAN.md`
- Split implementation plan into per-phase `docs/phase_N/SPEC.md` + `IMPLEMENTATION.md`
- Moved testing to per-phase cycle (test after each phase, not at end)
- Restructured from 6-phase to 4-phase workflow with per-phase build loop

### Added
- Sub-agent deep research before each phase implementation (RESEARCH.md per phase)
- Per-phase TEST_PLAN.md with structured input/output tables (happy/failure/edge cases)
- `scripts/phase-tracker.sh` — cross-phase progress reporting
- `scripts/pre-compact-backup.sh` — state backup before context compaction
- `scripts/validate-phase.sh` — quality gate between phases
- PreCompact hook for context recovery
- Phase isolation rule: only load current phase docs into context
- Inter-phase dependency tracking in MASTER_PLAN.md

### Removed
- Monolithic `PRD.md` (replaced by MASTER_PLAN.md + phase specs)
- Monolithic `IMPLEMENTATION_PLAN.md` (replaced by per-phase files)
- Single `TEST_PLAN.md` at end (replaced by per-phase test plans)
- Default UI/E2E testing (now opt-in only when Human requests)

## [1.0.0] - 2025-xx-xx

### Added
- Initial vibe-builder skill with 6-phase workflow
- Deep research with WebSearch
- PRD.md and IMPLEMENTATION_PLAN.md generation
- Docker-first infrastructure
- Context recovery hooks
- AI tool detection (Claude Code / Gemini)
