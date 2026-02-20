#!/usr/bin/env bash
# generate-checklist.sh — Generate a security/resilience checklist from a project profile
#
# Usage: bash scripts/generate-checklist.sh '<profile_json>'
# Output: Structured checklist data to stdout (markdown-ready)
#
# The agent should read this output and enhance it with:
# - Stack-specific fix code (SQL, middleware, config)
# - Links to relevant documentation
# - Enterprise lesson context

set -euo pipefail

PROFILE="$1"

# Parse profile fields using python3 (more reliable than jq for embedded JSON)
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

parse_bool() {
    python3 -c "
import json, sys
p = json.loads(sys.argv[1])
keys = sys.argv[2].split('.')
v = p
for k in keys:
    if isinstance(v, dict):
        v = v.get(k, False)
    else:
        v = False
print('true' if v else 'false')
" "$PROFILE" "$1" 2>/dev/null || echo "false"
}

parse_int() {
    python3 -c "
import json, sys
p = json.loads(sys.argv[1])
keys = sys.argv[2].split('.')
v = p
for k in keys:
    if isinstance(v, dict):
        v = v.get(k, 0)
    else:
        v = 0
print(int(v) if v else 0)
" "$PROFILE" "$1" 2>/dev/null || echo "0"
}

FRAMEWORK=$(parse "framework")
HOSTING=$(parse "hosting")
DATABASE=$(parse "database")
AUTH=$(parse "auth")
PAYMENTS=$(parse "payments")
AI_APIS=$(parse "ai_apis")
CI_CD=$(parse "ci_cd")
MONITORING=$(parse "monitoring")
FILE_STORAGE=$(parse "file_storage")

ENV_GITIGNORED=$(parse_bool "env_files.gitignored")
CSP_CONFIGURED=$(parse_bool "security.csp_configured")
CORS_CONFIGURED=$(parse_bool "security.cors_configured")
MIDDLEWARE_EXISTS=$(parse_bool "security.middleware_exists")
RLS_MISSING=$(parse_int "security.rls_missing_tables")
RLS_ENABLED=$(parse_int "security.rls_enabled_tables")

SENSITIVE_VARS=$(parse "secrets_exposure.potentially_sensitive_client_vars")
WARNINGS=$(parse "warnings")

HAS_AI=false
if [[ "$AI_APIS" != "[]" && -n "$AI_APIS" ]]; then HAS_AI=true; fi

HAS_PAYMENTS=false
if [[ "$PAYMENTS" != "none" && -n "$PAYMENTS" ]]; then HAS_PAYMENTS=true; fi

# ─────────────────────────────────────────────────
# Generate checklist items per domain
# ─────────────────────────────────────────────────

cat <<'HEADER'
# 🛡️ Web App Security & Resilience Checklist

Generated from project profile analysis.
Items are ordered by severity: 🔴 CRITICAL → 🟠 IMPORTANT → 🟡 RECOMMENDED

---

HEADER

# ══════════════════════════════════════
# 🔴 CRITICAL
# ══════════════════════════════════════

echo "## 🔴 CRITICAL — Fix This Week"
echo ""

CRITICAL_COUNT=0

# --- Secrets ---
if [[ "$ENV_GITIGNORED" == "false" ]]; then
    echo "### ❌ Environment files may not be in .gitignore"
    echo "**Domain**: 🔐 Secrets & Credentials"
    echo "**Risk**: .env files committed to git expose all secrets (API keys, DB passwords)"
    echo "**Fix**: Add to .gitignore: \`.env*\` and \`!.env.example\`. Then remove from git history."
    echo "**Big-tech context**: Teams use secret vaults (HashiCorp Vault, AWS Secrets Manager). At indie scale, .gitignore is your first line of defense."
    echo "**Effort**: ⚡ Quick (2 minutes)"
    echo ""
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
fi

if [[ "$SENSITIVE_VARS" != "[]" && -n "$SENSITIVE_VARS" && "$SENSITIVE_VARS" != "\"[]\"" ]]; then
    echo "### ❌ Potentially sensitive client-side environment variables"
    echo "**Domain**: 🔐 Secrets & Credentials"
    echo "**Detected**: $SENSITIVE_VARS"
    echo "**Risk**: Variables prefixed NEXT_PUBLIC_ or VITE_ are embedded in the browser bundle — visible to anyone. If these contain API keys or secrets, they're exposed."
    echo "**Fix**: Move sensitive values to server-side only env vars (no NEXT_PUBLIC_ prefix). Access them only in API routes or server components."
    echo "**Big-tech context**: The principle of least privilege — browser code should only have access to public-safe values."
    echo "**Effort**: 🔧 Moderate (15-30 minutes to refactor)"
    echo ""
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
fi

# --- Access Control ---
if [[ $RLS_MISSING -gt 0 ]]; then
    echo "### ❌ $RLS_MISSING database tables may be missing Row Level Security"
    echo "**Domain**: 🔓 Access Control"
    echo "**Risk**: Without RLS, anyone with the Supabase anon key (which is in your client code by design) can read/write ALL data in unprotected tables."
    echo "**Fix**: Enable RLS on every table and create appropriate policies. [Agent: generate SQL for detected tables]"
    echo "**Big-tech context**: This is equivalent to having no IAM policies on an AWS resource. At Google, every data store has access controls — RLS is your equivalent."
    echo "**Effort**: 🔧 Moderate (15 minutes per table)"
    echo ""
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
fi

# --- AI Cost ---
if [[ "$HAS_AI" == "true" ]]; then
    echo "### ⚠️ AI API usage — verify spend limits are set"
    echo "**Domain**: 💸 Cost & Billing"
    echo "**Detected APIs**: $AI_APIS"
    echo "**Risk**: Leaked or abused API keys can generate thousands in charges overnight. OpenAI, Anthropic, etc. bill by usage with no automatic cap unless you set one."
    echo "**Fix**: Set hard monthly budget limits on every AI provider dashboard. Add rate limiting to API routes that call AI services."
    echo "**Big-tech context**: Google SRE teams set billing alerts and automatic shutoffs. The principle: set limits BEFORE an incident, not during one."
    echo "**Effort**: ⚡ Quick (5 minutes per provider)"
    echo ""
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
fi

echo ""

# ══════════════════════════════════════
# 🟠 IMPORTANT
# ══════════════════════════════════════

echo "## 🟠 IMPORTANT — Fix This Month"
echo ""

IMPORTANT_COUNT=0

# --- Middleware / Auth ---
if [[ "$MIDDLEWARE_EXISTS" == "false" ]] && [[ "$FRAMEWORK" == "next.js" || "$FRAMEWORK" == "nuxt" || "$FRAMEWORK" == "sveltekit" ]]; then
    echo "### ⚠️ No middleware detected — routes may lack auth protection"
    echo "**Domain**: 🔓 Access Control"
    echo "**Risk**: Without middleware, API routes and pages may be accessible without authentication. Client-side auth checks alone are bypassable."
    echo "**Fix**: Create middleware.ts to verify auth tokens on protected routes. [Agent: generate middleware for $FRAMEWORK]"
    echo "**Big-tech context**: Defense in depth — authentication must be enforced server-side, not just in the browser. Every request should be verified."
    echo "**Effort**: 🔧 Moderate (30 minutes)"
    echo ""
    IMPORTANT_COUNT=$((IMPORTANT_COUNT + 1))
fi

# --- CSP ---
if [[ "$CSP_CONFIGURED" == "false" ]]; then
    echo "### ⚠️ No Content-Security-Policy headers detected"
    echo "**Domain**: 🤖 Code Vulnerabilities"
    echo "**Risk**: Without CSP, XSS attacks can load external scripts, exfiltrate data, and hijack sessions. CSP is a critical defense-in-depth layer."
    echo "**Fix**: Add CSP headers in your framework config or middleware. Start with a report-only policy to avoid breaking things. [Agent: generate CSP config for $FRAMEWORK on $HOSTING]"
    echo "**Big-tech context**: CSP is mandatory at every major tech company. It's one of the OWASP Top 10 mitigations."
    echo "**Effort**: 🔧 Moderate (30-60 minutes including testing)"
    echo ""
    IMPORTANT_COUNT=$((IMPORTANT_COUNT + 1))
fi

# --- Monitoring ---
if [[ "$MONITORING" == "none" ]]; then
    echo "### ⚠️ No error monitoring or observability detected"
    echo "**Domain**: 🚫 Availability"
    echo "**Risk**: Without monitoring, you learn about outages from angry users, not alerts. Mean Time to Detect (MTTD) is infinite."
    echo "**Fix**: Add Sentry (free tier covers most indie projects) or BetterStack uptime monitoring. Takes 10 minutes to set up."
    echo "**Big-tech context**: Google SRE defines SLIs (Service Level Indicators) and SLOs (Service Level Objectives). At indie scale: at minimum, know when your app is down before your users tell you."
    echo "**Effort**: 🔧 Moderate (15 minutes for basic setup)"
    echo ""
    IMPORTANT_COUNT=$((IMPORTANT_COUNT + 1))
fi

# --- CI/CD ---
if [[ "$CI_CD" == "none" ]]; then
    echo "### ⚠️ No CI/CD pipeline detected"
    echo "**Domain**: 🤖 Code Vulnerabilities"
    echo "**Risk**: Without CI, there's no automated testing, linting, or security scanning before deploy. Bad code goes straight to production."
    echo "**Fix**: Add a basic GitHub Actions workflow with lint, type-check, and npm audit. [Agent: generate workflow for $FRAMEWORK]"
    echo "**Big-tech context**: Every big-tech company runs SAST/DAST in CI. At indie scale: even a basic lint + type-check pipeline catches serious bugs before deploy."
    echo "**Effort**: 🔧 Moderate (30 minutes)"
    echo ""
    IMPORTANT_COUNT=$((IMPORTANT_COUNT + 1))
fi

# --- Database backups ---
if [[ "$DATABASE" == "supabase" ]]; then
    echo "### ⚠️ Supabase database — verify backup strategy"
    echo "**Domain**: 🗑️ Data Loss"
    echo "**Risk**: Supabase free tier has no automatic backups. Projects pause after 7 days of inactivity and may become unrecoverable after ~90 days. Even on Pro, have you tested a restore?"
    echo "**Fix**: Set up a weekly pg_dump via cron or GitHub Action. Test restoring it at least once. [Agent: generate backup script]"
    echo "**Big-tech context**: ISO 22301 requires tested backup and recovery procedures. Google's DiRT program regularly tests 'what if we lost this database?' You should too."
    echo "**Effort**: 🔧 Moderate (30 minutes for initial setup)"
    echo ""
    IMPORTANT_COUNT=$((IMPORTANT_COUNT + 1))
fi

# --- Hosting spend ---
if [[ "$HOSTING" == "vercel" ]]; then
    echo "### ⚠️ Vercel hosting — verify spend management is enabled"
    echo "**Domain**: 💸 Cost & Billing"
    echo "**Risk**: DDoS or traffic spikes can burn through bandwidth. Hobby plan has limits; Pro plan has overage billing. Set spend alerts."
    echo "**Fix**: Go to Vercel Dashboard → Settings → Billing → enable Spend Management with a hard cap."
    echo "**Big-tech context**: AWS, GCP all have billing alerts and budget caps. The principle: set financial circuit breakers before you need them."
    echo "**Effort**: ⚡ Quick (2 minutes)"
    echo ""
    IMPORTANT_COUNT=$((IMPORTANT_COUNT + 1))
fi

echo ""

# ══════════════════════════════════════
# 🟡 RECOMMENDED
# ══════════════════════════════════════

echo "## 🟡 RECOMMENDED — When You Have Time"
echo ""

echo "### 💡 Document your deployment process"
echo "**Domain**: 🔄 Recoverability"
echo "**Question**: Could you redeploy your app from scratch in under 2 hours if your hosting account was suspended?"
echo "**Fix**: Write a 'Disaster Recovery' section in your README with: env vars needed, services to configure, deploy steps."
echo "**Big-tech context**: ISO 22301 mandates documented and tested business continuity plans. Your README is your BCP."
echo "**Effort**: 🔧 Moderate (30 minutes)"
echo ""

if [[ "$HAS_PAYMENTS" == "true" ]]; then
    echo "### 💡 Verify payment webhook security"
    echo "**Domain**: 🔓 Access Control"
    echo "**Risk**: If Stripe webhooks aren't verified with signature checking, anyone can fake payment events."
    echo "**Fix**: Verify webhook signatures server-side using Stripe's constructEvent(). [Agent: generate verification code]"
    echo "**Effort**: 🔧 Moderate (15 minutes)"
    echo ""
fi

echo "### 💡 Run npm audit and enable Dependabot"
echo "**Domain**: 🤖 Code Vulnerabilities"
echo "**Fix**: Run \`npm audit\` now. Enable GitHub Dependabot (Settings → Security → Dependabot alerts)."
echo "**Big-tech context**: Big-tech teams maintain SBOMs (Software Bill of Materials) and monitor CVEs. Dependabot is your free version of that."
echo "**Effort**: ⚡ Quick (5 minutes)"
echo ""

echo "### 💡 Test your git history for leaked secrets"
echo "**Domain**: 🔐 Secrets & Credentials"
echo "**Fix**: Run \`npx trufflehog git file://. --only-verified\` or use GitHub's built-in secret scanning (free for public repos)."
echo "**Big-tech context**: Secrets persist in git history even after deletion from current code. Big-tech runs automated secret scanning in CI."
echo "**Effort**: ⚡ Quick (5 minutes to scan, longer if secrets are found)"
echo ""

echo "---"
echo ""

# ══════════════════════════════════════
# SCORING
# ══════════════════════════════════════

echo "## 📊 Readiness Scoring"
echo ""
echo "Rate each domain 0-10 based on the checklist results above."
echo "The agent should fill these scores based on detected status:"
echo ""
echo '```'
echo "Secrets Management:  ░░░░░░░░░░  ?/10"
echo "Data Protection:     ░░░░░░░░░░  ?/10"
echo "Access Control:      ░░░░░░░░░░  ?/10"
echo "Cost Protection:     ░░░░░░░░░░  ?/10"
echo "Availability:        ░░░░░░░░░░  ?/10"
echo "Code Security:       ░░░░░░░░░░  ?/10"
echo "Recoverability:      ░░░░░░░░░░  ?/10"
echo "─────────────────────────────────"
echo "Overall Readiness:   ░░░░░░░░░░  ?/10"
echo '```'
echo ""
echo "**Score guide**: 0-2 = minimal protection, 3-4 = some basics, 5-6 = reasonable foundation, 7-8 = well-protected, 9-10 = big-tech-grade for this scale."
echo ""

# ══════════════════════════════════════
# NEXT STEPS
# ══════════════════════════════════════

echo "## ⚡ Recommended Action Order"
echo ""
echo "The agent should generate a prioritized list of the top 5 fixes, ordered by:"
echo "1. Severity (critical first)"
echo "2. Ease of implementation (quick wins first among same severity)"
echo ""
echo "Format:"
echo '```'
echo "1. [time] Action description (specific command or file to change)"
echo "2. [time] ..."
echo '```'
echo ""

echo "---"
echo ""
echo "**Profile used**: framework=$FRAMEWORK hosting=$HOSTING database=$DATABASE auth=$AUTH"
echo "**Critical items**: $CRITICAL_COUNT | **Important items**: $IMPORTANT_COUNT"
echo "**Warnings from scan**: $WARNINGS"
