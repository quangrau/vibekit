#!/usr/bin/env bash
# generate-drill.sh — Generate an exercise drill scenario from a project profile
#
# Usage: bash scripts/generate-drill.sh '<profile_json>' [domain] [difficulty]
#   domain:     cost|data|secrets|access|availability|code|recovery|random
#   difficulty: beginner|intermediate|advanced (default: beginner)
#
# Output: Scenario structure to stdout. The agent should flesh out the narrative
#         with stack-specific details, real error messages, and resolution commands.

set -euo pipefail

PROFILE="$1"
DOMAIN="${2:-random}"
DIFFICULTY="${3:-beginner}"

# Parse profile
parse() {
    python3 -c "
import json, sys
p = json.loads(sys.argv[1])
keys = sys.argv[2].split('.')
v = p
for k in keys:
    if isinstance(v, dict):
        v = v.get(k, '')
    else:
        v = ''
v = v if v is not None else ''
print(v if not isinstance(v, (list, dict, bool)) else json.dumps(v))
" "$PROFILE" "$1" 2>/dev/null || echo ""
}

FRAMEWORK=$(parse "framework")
HOSTING=$(parse "hosting")
DATABASE=$(parse "database")
AUTH=$(parse "auth")
AI_APIS=$(parse "ai_apis")
PAYMENTS=$(parse "payments")

# Map difficulty to inject count
case "$DIFFICULTY" in
    beginner)     INJECT_COUNT=2; TIME_EST="15 minutes" ;;
    intermediate) INJECT_COUNT=3; TIME_EST="20 minutes" ;;
    advanced)     INJECT_COUNT=4; TIME_EST="30 minutes" ;;
    *)            INJECT_COUNT=2; TIME_EST="15 minutes"; DIFFICULTY="beginner" ;;
esac

# Random domain selection weighted by detected risks
if [[ "$DOMAIN" == "random" ]]; then
    domains=()
    
    # Weight by what's actually in the stack
    domains+=("secrets")  # always relevant
    
    if [[ "$AI_APIS" != "[]" && -n "$AI_APIS" ]]; then
        domains+=("cost" "cost")  # double weight if AI APIs present
    fi
    if [[ "$DATABASE" != "none" && "$DATABASE" != "unknown" ]]; then
        domains+=("data" "access")
    fi
    if [[ "$HOSTING" != "unknown" ]]; then
        domains+=("availability")
    fi
    domains+=("code" "recovery")
    
    # Pick random from weighted list
    DOMAIN=${domains[$((RANDOM % ${#domains[@]}))]}
fi

# Map domain to full name and emoji
case "$DOMAIN" in
    cost)         DOMAIN_FULL="Cost & Billing"; DOMAIN_EMOJI="💸"; BIGTECH_CONCEPT="DDoS mitigation, cost anomaly detection, billing alerts" ;;
    data)         DOMAIN_FULL="Data Loss"; DOMAIN_EMOJI="🗑️"; BIGTECH_CONCEPT="Database disaster recovery, RPO/RTO, backup testing" ;;
    secrets)      DOMAIN_FULL="Secrets & Credentials"; DOMAIN_EMOJI="🔐"; BIGTECH_CONCEPT="Secret rotation, vault management, blast radius mapping" ;;
    access)       DOMAIN_FULL="Access Control"; DOMAIN_EMOJI="🔓"; BIGTECH_CONCEPT="IAM, RBAC, principle of least privilege" ;;
    availability) DOMAIN_FULL="Availability"; DOMAIN_EMOJI="🚫"; BIGTECH_CONCEPT="SLOs/SLIs, graceful degradation, incident communication" ;;
    code)         DOMAIN_FULL="Code Vulnerabilities"; DOMAIN_EMOJI="🤖"; BIGTECH_CONCEPT="SAST/DAST, OWASP Top 10, dependency management" ;;
    recovery)     DOMAIN_FULL="Recoverability"; DOMAIN_EMOJI="🔄"; BIGTECH_CONCEPT="BCP (ISO 22301), infrastructure as code, rebuild drills" ;;
    *)            DOMAIN_FULL="General"; DOMAIN_EMOJI="⚠️"; BIGTECH_CONCEPT="Incident response" ;;
esac

# Difficulty label
case "$DIFFICULTY" in
    beginner)     DIFF_EMOJI="🟢" ;;
    intermediate) DIFF_EMOJI="🟠" ;;
    advanced)     DIFF_EMOJI="🔴" ;;
esac

# ─────────────────────────────────────────────────
# Output scenario structure
# ─────────────────────────────────────────────────

cat <<EOF
══════════════════════════════════════════════════════════
  EXERCISE DRILL — [AGENT: Generate a vivid scenario title]
  Category: $DOMAIN_EMOJI $DOMAIN_FULL
  Difficulty: $DIFF_EMOJI ${DIFFICULTY^}
  Estimated time: $TIME_EST
  Big-tech concept: $BIGTECH_CONCEPT
══════════════════════════════════════════════════════════

## 🎯 YOUR ROLES

In a big-tech drill, these are separate people. You're all of them:
- **Incident Commander**: Decides priorities, calls stop if impact exceeds limits
- **Service Owner**: Knows the system, executes playbook, monitors SLIs
- **On-Call Engineer**: Detects, triages, fixes
- **Comms Lead**: Keeps users informed

Practice wearing each hat deliberately — don't just "fix stuff."

---

## 📋 PHASE 1: BEFORE (Prep — 3 minutes)

Before reading the scenario injects, answer these honestly:

**Review your playbook:**
- Do you have a documented SOP for this type of incident? (Even a README section counts)
- Do you know the exact steps to [AGENT: insert domain-relevant action, e.g. "rotate a secret" / "restore a database" / "redirect traffic"]?

**Confirm monitoring:**
- What dashboard or tool would alert you to this incident?
- What are your key SLIs? (availability, error rate, latency, cost)
- Are alerts actually configured, or would you find out from a user?

**Know your stop conditions:**
- At what point is the damage unacceptable? Define your limits NOW:
  - Error rate: ____% (e.g., >5% of requests failing)
  - Cost: \$____ (e.g., >\$50 in unexpected charges)
  - Data: ____ rows/records at risk
  - Downtime: ____ minutes maximum
- If any limit is breached during response, your #1 priority is: stop the bleeding, not find the root cause.

**Stakeholder awareness:**
- Who needs to know? (Users via status page? Co-founder? Upstream dependency owners?)
- What channel will you use? (Discord, Twitter, email, status page)

*(Take 3 minutes. Write your answers. Then proceed to the scenario.)*

---

## 📋 PHASE 2: DURING (The Scenario)

EOF

# Generate inject prompts based on domain + difficulty

# First, output the background
cat <<EOF
### Background

[AGENT: Write 3-5 sentences setting the scene. Use these project details:]
- Framework: $FRAMEWORK
- Hosting: $HOSTING
- Database: $DATABASE
- Auth: $AUTH
- AI APIs: $AI_APIS
- Payments: $PAYMENTS

[Mention user count, time of day, what the developer was doing when the
incident started. Ground it in the actual stack.]

---

EOF

generate_inject() {
    local num=$1
    local timestamp=$2
    local instruction=$3
    local pause_questions=$4
    
    cat <<EOF

## ⏱️ INJECT $num — $timestamp

[AGENT: Write the inject narrative here. $instruction]

### ❓ PAUSE AND THINK ($( [[ $num -le 2 ]] && echo "2 minutes" || echo "3 minutes" ))
$pause_questions

*(Write down your answers before scrolling to the next inject.)*

---

EOF
}

case "$DOMAIN" in
    cost)
        generate_inject 1 "Monday, 8:12 AM" \
            "The developer receives an email alert or checks a dashboard and sees unexpected charges or usage spikes. For the $HOSTING + $AI_APIS stack, describe the specific alert (billing email, dashboard reading, usage graph). Make the numbers specific but not yet catastrophic." \
            "- What could be causing the spike?
- Where would you check first?
- Is this ongoing right now or did it already happen?"
        
        if [[ $INJECT_COUNT -ge 3 ]]; then
            generate_inject 2 "Monday, 8:25 AM" \
                "The situation is worse than initially thought. Either: the cost is still climbing (active abuse), OR a second cost vector is discovered (e.g., bandwidth AND API calls). Show specific numbers from the provider dashboard. Mention user-facing impact if any." \
                "- Which fire do you fight first?
- Can you stop the bleeding without taking the app offline?
- Who else might be affected?"
            
            generate_inject 3 "Monday, 9:15 AM" \
                "A user or external signal adds pressure. Maybe a user tweets about the app being slow, or a second billing alert arrives, or you discover the attack vector. The root cause becomes clearer but the damage scope is uncertain." \
                "- Now that you know the cause, what's your remediation order?
- How do you communicate with affected users?
- What would have prevented this entirely?"
        else
            generate_inject 2 "Monday, 8:30 AM" \
                "More information arrives that clarifies the root cause. The developer can now see what happened and needs to act. Show the specific evidence (log entry, dashboard metric, billing line item). Make the fix clear but the blast radius assessment important." \
                "- What's the root cause?
- What's the immediate fix?
- What needs to change to prevent this from recurring?"
        fi
        ;;
    
    data)
        generate_inject 1 "Saturday, 2:15 PM" \
            "The developer discovers data is missing, corrupted, or inaccessible. For $DATABASE: this could be a paused project, a failed migration, an accidental DELETE, or a provider outage. Show the specific error message or dashboard state." \
            "- Is the data gone permanently or temporarily unavailable?
- Do you have a backup? When was the last one?
- What's the blast radius — which users and features are affected?"
        
        if [[ $INJECT_COUNT -ge 3 ]]; then
            generate_inject 2 "Saturday, 2:30 PM" \
                "The situation worsens: either the data loss is larger than initially thought, or the recovery path is blocked (backup doesn't exist, backup is corrupt, provider support is slow). Users are noticing." \
                "- What's your fallback plan if the primary recovery fails?
- How do you tell your users what happened?
- What data can you reconstruct vs what's permanently lost?"
            
            generate_inject 3 "Saturday, 3:45 PM" \
                "A cascading effect: some other part of the app depends on the lost data and is now failing. Or: the 'fix' introduces a new problem. The clock is ticking on user trust." \
                "- How do you prioritize: restore data vs keep app running vs communicate?
- What's your RTO (Recovery Time Objective) — how fast MUST you recover?
- What's your RPO (Recovery Point Objective) — how much data loss is acceptable?"
        else
            generate_inject 2 "Saturday, 2:45 PM" \
                "More information: the scope of the data loss becomes clear. Show what's recoverable and what isn't. A user has noticed and is reaching out." \
                "- What can you recover and what's lost?
- What do you tell the user who reached out?
- What's the first thing you set up after this to prevent recurrence?"
        fi
        ;;
    
    secrets)
        generate_inject 1 "Wednesday, 11:30 PM" \
            "The developer receives an alert (GitHub secret scanning, email from provider, or discovers it themselves) that a secret has been exposed. For the $FRAMEWORK + $DATABASE stack: specify which secret and how it was exposed (public repo, client bundle, git history, accidental log)." \
            "- Is the secret actively being abused right now?
- What can someone do with this specific secret?
- What's the first thing you do — investigate or rotate?"
        
        if [[ $INJECT_COUNT -ge 3 ]]; then
            generate_inject 2 "Wednesday, 11:45 PM" \
                "Evidence of exploitation: the leaked secret has been used. Show specific evidence (API usage spike, unauthorized database queries, new user accounts created). The developer must assess blast radius." \
                "- Map the blast radius: what can this secret access?
- Are other secrets compromised through this one?
- What's the order of operations to lock down?"
            
            generate_inject 3 "Thursday, 12:30 AM" \
                "A second compromised credential is discovered, or the attacker has pivoted to another service using information from the first breach. The developer faces a full account security audit at midnight." \
                "- How do you verify nothing else is compromised?
- Do you need to notify your users?
- What systemic change prevents this class of vulnerability?"
        else
            generate_inject 2 "Thursday, 12:00 AM" \
                "The developer has rotated the key and must now assess: was it used? Check provider dashboards for unauthorized activity. Show what the logs reveal." \
                "- Was the secret used while it was exposed?
- Do you need to take any further action (notify users, audit data)?
- What do you change in your workflow to prevent this?"
        fi
        ;;
    
    access)
        generate_inject 1 "Tuesday, 4:20 PM" \
            "A user reports they can see or modify data they shouldn't have access to. For the $DATABASE + $AUTH stack: this could be missing RLS, an IDOR vulnerability, a broken auth check, or an overly permissive storage bucket. Show the user's report." \
            "- Can you reproduce this? How would you verify the vulnerability?
- Is this one broken page or a systemic issue?
- Is anyone actively exploiting this?"
        
        if [[ $INJECT_COUNT -ge 3 ]]; then
            generate_inject 2 "Tuesday, 4:40 PM" \
                "The vulnerability is worse than initially reported. Testing reveals it affects more endpoints or data than the initial report suggested. Show specific evidence of the broader scope." \
                "- How do you fix this without breaking the app for legitimate users?
- Do you take the app offline while fixing, or fix live?
- How do you check if anyone already exploited this?"
            
            generate_inject 3 "Tuesday, 5:30 PM" \
                "External pressure: a security researcher has found the same issue and is threatening public disclosure in 72 hours. Or: you discover the vulnerability has existed since launch, and user data may have been accessed." \
                "- How do you respond to the security researcher?
- Do you need to notify affected users?
- What's your remediation + communication plan?"
        else
            generate_inject 2 "Tuesday, 4:45 PM" \
                "You've confirmed the vulnerability. Show the technical details (which endpoints, which database queries, what data is exposed). The fix is clear but must be deployed quickly." \
                "- What's the exact fix needed?
- How do you test that the fix works without regression?
- What else should you audit while you're in there?"
        fi
        ;;
    
    availability)
        generate_inject 1 "Friday, 6:00 PM" \
            "The app is down or degraded. For the $FRAMEWORK on $HOSTING stack: this could be a platform outage, DNS issue, serverless limit hit, or deployment failure. Show what the developer sees when they check." \
            "- Is this your app's fault or an upstream provider issue?
- Where do you check to find out? (Status pages, logs, dashboard)
- What can your users see right now?"
        
        if [[ $INJECT_COUNT -ge 3 ]]; then
            generate_inject 2 "Friday, 6:20 PM" \
                "The root cause is partially identified but not easily fixable. Either: it's an upstream outage (you can't fix the provider), OR it's a configuration issue that's not obvious. Users are vocal." \
                "- What do you communicate to users and through what channel?
- Is there anything you can do to partially restore service?
- How long can this stay broken before serious consequences?"
            
            generate_inject 3 "Friday, 7:30 PM" \
                "A cascade: because of the primary outage, a secondary system is affected (scheduled jobs failed, webhooks backed up, cached data is stale). The outage duration is becoming a trust issue." \
                "- How do you handle the secondary effects?
- What's your failover plan — can you switch to an alternative?
- What architecture change would make you resilient to this?"
        else
            generate_inject 2 "Friday, 6:30 PM" \
                "The root cause is identified. Show the developer the specific issue and what needs to be done. A user has reached out asking what's happening." \
                "- What's the fix and how long will it take?
- What do you tell the user who reached out?
- What monitoring would have caught this earlier?"
        fi
        ;;
    
    code)
        generate_inject 1 "Thursday, 3:00 PM" \
            "A vulnerability is discovered in the codebase. For the $FRAMEWORK stack: this could be XSS, SQL injection, an exposed debug endpoint, a critical npm vulnerability, or CSRF. Show how it was discovered (user report, npm audit, security scan)." \
            "- How severe is this? What's the worst-case exploitation?
- Is this being actively exploited?
- How was this introduced? (AI-generated code? Unreviewed dependency?)"
        
        if [[ $INJECT_COUNT -ge 3 ]]; then
            generate_inject 2 "Thursday, 3:20 PM" \
                "Testing reveals the vulnerability is exploitable and may have been exploited. Show evidence (suspicious log entries, unexpected data patterns). A second related vulnerability is found." \
                "- Do you fix and deploy immediately or audit more first?
- What's the blast radius of exploitation?
- Do you need to invalidate user sessions?"
            
            generate_inject 3 "Thursday, 4:00 PM" \
                "The scope expands: the vulnerability class affects multiple parts of the app (e.g., XSS in bio field means XSS might exist in every user-input field). Systematic fix needed, not just a patch." \
                "- How do you systematically audit for this vulnerability class?
- What automated scanning would catch this in CI?
- Do you need to notify users if their data was at risk?"
        else
            generate_inject 2 "Thursday, 3:30 PM" \
                "The vulnerability details are confirmed. Show the technical specifics and the evidence of scope. The fix is known but requires care not to break functionality." \
                "- What's the fix?
- How do you verify it's fixed without regression?
- What do you add to CI to catch this class of bug going forward?"
        fi
        ;;
    
    recovery)
        generate_inject 1 "Sunday, 10:00 AM" \
            "A major service is unavailable: hosting account suspended, database provider deleted your project, or your laptop (with the only copy of env vars) is stolen/broken. For the $FRAMEWORK + $HOSTING + $DATABASE stack: which loss scenario is most realistic?" \
            "- What do you still have access to?
- Can you deploy from what's in your git repo alone?
- What's missing that you need to recover?"
        
        if [[ $INJECT_COUNT -ge 3 ]]; then
            generate_inject 2 "Sunday, 10:30 AM" \
                "The rebuild is harder than expected: some critical piece isn't documented or version-controlled. An env var is missing, a migration doesn't match production, or a service config was only in the provider dashboard." \
                "- What's blocking the rebuild?
- Is there any way to recover the missing piece?
- What would you document differently going forward?"
            
            generate_inject 3 "Sunday, 12:00 PM" \
                "You've partially recovered but some functionality is broken or data is stale. Users are experiencing degraded service. The question shifts from 'can I rebuild' to 'how fast and how completely.'" \
                "- What's your RTO right now — how long until full recovery?
- Can you prioritize which features to restore first?
- What's your permanent fix to make this a 30-minute recovery next time?"
        else
            generate_inject 2 "Sunday, 11:00 AM" \
                "You've taken stock of what you have. Show the gap between what's needed and what's available. Frame the recovery steps clearly." \
                "- What's your step-by-step rebuild plan?
- How long will this take?
- What do you set up after recovery to make next time easier?"
        fi
        ;;
esac

# ──────────────────────────────────────
# Resolution and grading sections
# ──────────────────────────────────────

cat <<'EOF'

## ✅ RESOLUTION WALKTHROUGH

[AGENT: Write a complete resolution guide with these sections.
Every step should include actual commands, URLs, or code for the detected stack.]

### Immediate (first 10 minutes)
1. [Most urgent action with exact command/step]
2. [Second action]

### Short-term (next hour)
3. [Stabilization]
4. [Communication to users]

### Prevention (this week)
5. [Setup to prevent recurrence]
6. [Monitoring/alerting to detect earlier]

---

## 📋 PHASE 3: AFTER (Review & Follow-Up)

This is where most solo devs stop — but big-tech teams consider the "after" phase
the most valuable part of any drill. It's where lasting improvement happens.

### 📝 Observation Log
Fill this in based on what you just practiced:

| Metric | Your Answer |
|---|---|
| Time to detect (when did you know?) | ____ minutes |
| Time to respond (when did you act?) | ____ minutes |
| Time to recover (when was it fixed?) | ____ minutes |
| Stop conditions breached? | Yes / No |
| Unexpected side effects? | _________________ |
| Manual steps that should be automated? | _________________ |
| Missing monitoring that would have helped? | _________________ |

### 🔍 Post-Mortem (Blameless)
Answer honestly — this is practice, not a test:
1. **What went well?** (What did you know, have ready, or do quickly?)
2. **What was slow or missing?** (Where did you fumble, guess, or not have a playbook?)
3. **What surprised you?** (Any blast radius, dependency, or side effect you didn't expect?)

### ✅ Follow-Up TODOs
The real output of a drill is not "I survived" — it's the list of things to fix.
Each TODO needs an **owner** (you) and a **deadline** (this week/this month).

| # | TODO | Deadline | Done? |
|---|---|---|---|
| 1 | _________________________________ | _______ | ☐ |
| 2 | _________________________________ | _______ | ☐ |
| 3 | _________________________________ | _______ | ☐ |

**Big-tech context**: At companies running DR drills, the follow-up TODOs are tracked
in a system with clear owners and deadlines. Gaps found in drills that aren't fixed
become the root cause of real incidents. The drill isn't complete until the TODOs are done.

### 📊 Update Your Playbook
Based on this drill, update (or create) your DR playbook:
- [ ] Is the runbook for this scenario documented? (Even a README section)
- [ ] Are the commands/steps you used saved somewhere you can find in a panic?
- [ ] Is your monitoring configured to catch this earlier next time?
- [ ] Did you discover any dependency or service you didn't know about?

---

## 🏢 THE BIG-TECH LESSON

[AGENT: Write 2-3 paragraphs covering:]
- What this incident type is called at big-tech companies
- How companies like Google, Meta, or Stripe handle it (reference DiRT, SRE, NIST, ISO, OWASP as appropriate)
- How big-tech drills work: central coordination, service owners as active operators,
  three-phase structure (before/during/after), stop conditions, blameless post-mortems
- The transferable principles that apply at any scale
- Specific terminology the developer just learned (MTTD, MTTR, RPO, RTO, blast radius,
  defense in depth, stop conditions, incident commander, blameless post-mortem, etc.)

---

## 📊 GRADE YOURSELF

**Preparation** (were you ready before the incident?)
- 🟢 Had a playbook and monitoring ready
- 🟡 Knew roughly what to do but no documented steps
- 🔴 Had no idea where to start

**Detection** (did you know it was happening?)
- 🟢 Before users noticed
- 🟡 When users complained
- 🔴 When you saw a bill / major damage

**Response** (how fast could you stop it?)
- 🟢 Under 15 minutes
- 🟡 Under 1 hour
- 🔴 Over 1 hour or "I didn't know how"

**Stop Conditions** (did you know your limits?)
- 🟢 Defined limits beforehand and monitored them
- 🟡 Had a vague sense but no specific thresholds
- 🔴 Didn't think about limits until damage was done

**Blast Radius Awareness** (did you know what was affected?)
- 🟢 Mapped it immediately
- 🟡 Figured it out during investigation
- 🔴 Still not sure what was affected

**Communication** (did users know what was happening?)
- 🟢 Proactive status update
- 🟡 Replied to individual complaints
- 🔴 Went silent

**Follow-Through** (did you capture improvements?)
- 🟢 Wrote TODOs with deadlines and updated playbook
- 🟡 Made mental notes
- 🔴 Moved on without capturing anything

---

EOF

echo "**Scenario metadata**: domain=$DOMAIN difficulty=$DIFFICULTY framework=$FRAMEWORK hosting=$HOSTING database=$DATABASE"
