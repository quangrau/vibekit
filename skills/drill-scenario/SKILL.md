---
name: drill-scenario
description: >
  Generate disaster drill scenarios and security checklists for web application projects
  (SPA, SSR, full-stack web apps). Focused on solo/indie developers using free-tier
  infrastructure (Vercel, Supabase, Cloudflare, Netlify, Railway, etc.). Bridges big-tech
  best practices (NIST, Google SRE DiRT, ISO 22301) to indie scale. Use when the user
  mentions drills, disaster recovery, security audit, incident simulation, project health
  check, resilience testing, backup strategies, secret rotation, or incident response for
  web projects. Not for mobile apps, desktop software, CLI tools, or games.
---

# Drill Scenario Generator

Disaster drill scenarios and security checklists for indie web apps.
Teaches big-tech resilience principles through indie-scale practice.

**Scope**: Web applications only (SPA, SSR, full-stack). Not mobile, desktop, CLI, or games.

## Workflow

### Step 1: Detect Agent Model
Run `scripts/detect-agent.sh` to identify which AI coding tool is executing this skill.
Returns `CLAUDE`, `GEMINI`, `TRAE`, or `UNKNOWN`.

```bash
AGENT=$(bash scripts/detect-agent.sh)
```

Then read the agent-specific context file to understand project rules:
- CLAUDE → CLAUDE.md
- GEMINI → GEMINI.md
- TRAE → AGENTS.md
- UNKNOWN → ask the human to provide any relevant docs before continuing

### Step 2: Detect Project Stack
If the user has uploaded project files or you have access to a project directory,
run the stack detection script pointing at the project root:

```bash
bash scripts/detect-stack.sh /path/to/project
```

This outputs a JSON profile to stdout. Save it for the next step.
If no project files are available, ask the user 3-5 quick questions (stack, hosting,
database, users, backups) and build the JSON profile manually matching the schema
in `scripts/detect-stack.sh`.

### Step 3: Choose Mode
Present two options:

**📋 CHECKLIST** — "Am I prepared?" Proactive audit with prioritized fixes.
Best for: first-time use, new projects, pre-launch, quarterly review.

**🔥 EXERCISE DRILL** — "Can I handle it?" Simulated incident in three phases:
- **Before**: Prep your playbook, confirm monitoring, define stop conditions
- **During**: Scenario injects with pause-and-think prompts
- **After**: Observation log, blameless post-mortem, follow-up TODOs with deadlines
Best for: after basics are solid, building muscle memory, testing response speed.
Solo devs play all roles: incident commander, service owner, on-call, comms lead.

Recommend Checklist first if the user has never done this.

### Step 4: Generate Output

**For Checklist mode:**
```bash
bash scripts/generate-checklist.sh '<profile_json>'
```

Read the output. It contains the raw checklist structure. Format it into a clean
markdown document and present to the user. Add stack-specific fix code that the
script couldn't generate (actual SQL, middleware, config — use your knowledge of
the detected framework).

**For Exercise Drill mode:**
```bash
bash scripts/generate-drill.sh '<profile_json>' [domain] [difficulty]
```
- `domain`: cost|data|secrets|access|availability|code|recovery|random
- `difficulty`: beginner|intermediate|advanced (default: beginner)

Read the output. It contains the scenario structure with injects. Flesh out the
narrative — make it vivid, specific to the user's stack, with real error messages
and dashboard names. Add the resolution walkthrough with actual commands.

### Step 5: Follow Up
After presenting the output:
- For Checklist: offer to generate fix code for the top critical items
- For Drill: emphasize Phase 3 (After) — the TODOs and playbook updates are the
  real deliverable, not just surviving the scenario. Offer to help write the playbook
  or generate the monitoring/alerting configs identified as missing.
- Suggest a quarterly rhythm: 1 Checklist + 2 Drills per quarter
- Track: which domains have been drilled, which TODOs are still open

## Reference Files
The `references/` directory contains supplemental content the agent can read for
deeper scenario ideas or additional checklist items beyond what the scripts generate:
- `references/risk-domains.md` — All 7 risk domains with extra scenario seeds and
  checklist item libraries. Read this if you need more variety or the script output
  doesn't cover the user's specific situation.
