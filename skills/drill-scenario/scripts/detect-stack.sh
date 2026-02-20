#!/usr/bin/env bash
# detect-stack.sh — Scan a web app project and output a JSON profile
# 
# Usage: bash scripts/detect-stack.sh /path/to/project
# Output: JSON profile to stdout
#
# The profile schema:
# {
#   "framework": "next.js|nuxt|sveltekit|remix|astro|cra|vite-react|vite-vue|vite-svelte|express|unknown",
#   "framework_version": "14.2.0",
#   "rendering": "ssr|spa|ssg|hybrid|unknown",
#   "typescript": true|false,
#   "hosting": "vercel|netlify|cloudflare|railway|render|fly|docker|unknown",
#   "database": "supabase|firebase|planetscale|neon|prisma-postgres|drizzle|mongodb|none|unknown",
#   "database_tier": "free|paid|unknown",
#   "auth": "supabase-auth|nextauth|lucia|clerk|firebase-auth|custom|none|unknown",
#   "payments": "stripe|lemonsqueezy|paddle|none|unknown",
#   "ai_apis": ["openai","anthropic","replicate",...],
#   "file_storage": "supabase-storage|s3|cloudflare-r2|firebase-storage|none|unknown",
#   "cdn_dns": "cloudflare|route53|vercel-dns|netlify-dns|none|unknown",
#   "ci_cd": "github-actions|gitlab-ci|none|unknown",
#   "monitoring": "sentry|datadog|betterstack|logrocket|none|unknown",
#   "api_routes_detected": true|false,
#   "api_route_count": 0,
#   "env_files": { "gitignored": true|false, "example_exists": true|false },
#   "secrets_exposure": {
#     "client_env_vars": ["NEXT_PUBLIC_SUPABASE_URL",...],
#     "potentially_sensitive_client_vars": ["NEXT_PUBLIC_STRIPE_KEY",...]
#   },
#   "security": {
#     "rls_enabled_tables": 0,
#     "rls_missing_tables": 0,
#     "csp_configured": true|false,
#     "cors_configured": true|false,
#     "middleware_exists": true|false
#   },
#   "backups": "configured|none|unknown",
#   "dependencies": { "total": 0, "dev": 0 },
#   "git": { "is_repo": true|false, "has_remote": true|false, "public": "unknown" },
#   "warnings": ["No .gitignore for .env files", ...]
# }

set -uo pipefail

PROJECT_DIR="${1:-.}"

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo '{"error": "Project directory not found: '"$PROJECT_DIR"'"}'
    exit 1
fi

cd "$PROJECT_DIR"

# --- Helper functions ---

file_exists() { [[ -f "$1" ]]; }
dir_exists() { [[ -d "$1" ]]; }
json_str() { echo "\"$1\""; }
pkg_has() { 
    # Check if a package exists in package.json dependencies or devDependencies
    if file_exists "package.json"; then
        grep -q "\"$1\"" package.json 2>/dev/null
    else
        return 1
    fi
}

# --- Framework Detection ---

FRAMEWORK="unknown"
FRAMEWORK_VERSION=""
RENDERING="unknown"
TYPESCRIPT=false

if file_exists "package.json"; then
    if pkg_has "next"; then
        FRAMEWORK="next.js"
        FRAMEWORK_VERSION=$(grep -o '"next": *"[^"]*"' package.json | grep -o '[0-9][^"]*' | head -1)
        RENDERING="ssr"
        # Check for static export
        if file_exists "next.config.js" && grep -q "output.*export" next.config.js 2>/dev/null; then
            RENDERING="ssg"
        elif file_exists "next.config.mjs" && grep -q "output.*export" next.config.mjs 2>/dev/null; then
            RENDERING="ssg"
        elif file_exists "next.config.ts" && grep -q "output.*export" next.config.ts 2>/dev/null; then
            RENDERING="ssg"
        fi
    elif pkg_has "nuxt"; then
        FRAMEWORK="nuxt"
        FRAMEWORK_VERSION=$(grep -o '"nuxt": *"[^"]*"' package.json | grep -o '[0-9][^"]*' | head -1)
        RENDERING="ssr"
    elif pkg_has "@sveltejs/kit"; then
        FRAMEWORK="sveltekit"
        FRAMEWORK_VERSION=$(grep -o '"@sveltejs/kit": *"[^"]*"' package.json | grep -o '[0-9][^"]*' | head -1)
        RENDERING="ssr"
    elif pkg_has "@remix-run/react"; then
        FRAMEWORK="remix"
        RENDERING="ssr"
    elif pkg_has "astro"; then
        FRAMEWORK="astro"
        RENDERING="ssg"
    elif pkg_has "react-scripts"; then
        FRAMEWORK="cra"
        RENDERING="spa"
    elif pkg_has "vite"; then
        if pkg_has "react"; then FRAMEWORK="vite-react"
        elif pkg_has "vue"; then FRAMEWORK="vite-vue"
        elif pkg_has "svelte"; then FRAMEWORK="vite-svelte"
        else FRAMEWORK="vite"; fi
        RENDERING="spa"
    elif pkg_has "express" || pkg_has "fastify" || pkg_has "hono"; then
        FRAMEWORK="api-server"
        RENDERING="api-only"
    fi
fi

# TypeScript
if file_exists "tsconfig.json"; then TYPESCRIPT=true; fi

# --- Hosting Detection ---

HOSTING="unknown"
if file_exists "vercel.json" || file_exists ".vercel/project.json"; then HOSTING="vercel"
elif file_exists "netlify.toml"; then HOSTING="netlify"
elif file_exists "wrangler.toml" || file_exists "wrangler.jsonc"; then HOSTING="cloudflare"
elif file_exists "fly.toml"; then HOSTING="fly"
elif file_exists "railway.json" || file_exists "railway.toml"; then HOSTING="railway"
elif file_exists "render.yaml"; then HOSTING="render"
elif file_exists "Dockerfile" || file_exists "docker-compose.yml"; then HOSTING="docker"
fi

# --- Database Detection ---

DATABASE="unknown"
DATABASE_TIER="unknown"
if dir_exists "supabase" || pkg_has "@supabase/supabase-js"; then
    DATABASE="supabase"
elif file_exists "firebase.json" || file_exists ".firebaserc" || pkg_has "firebase"; then
    DATABASE="firebase"
elif file_exists "schema.prisma" || file_exists "prisma/schema.prisma"; then
    DATABASE="prisma"
    # Try to detect provider from schema
    SCHEMA_FILE=""
    if file_exists "schema.prisma"; then SCHEMA_FILE="schema.prisma"
    elif file_exists "prisma/schema.prisma"; then SCHEMA_FILE="prisma/schema.prisma"; fi
    if [[ -n "$SCHEMA_FILE" ]]; then
        if grep -q "planetscale" "$SCHEMA_FILE" 2>/dev/null; then DATABASE="planetscale"
        elif grep -q "neon" "$SCHEMA_FILE" 2>/dev/null; then DATABASE="neon"
        elif grep -q "postgresql" "$SCHEMA_FILE" 2>/dev/null; then DATABASE="prisma-postgres"
        elif grep -q "mysql" "$SCHEMA_FILE" 2>/dev/null; then DATABASE="prisma-mysql"
        fi
    fi
elif pkg_has "drizzle-orm"; then
    DATABASE="drizzle"
elif pkg_has "mongoose" || pkg_has "mongodb"; then
    DATABASE="mongodb"
fi

# --- Auth Detection ---

AUTH="unknown"
if pkg_has "@supabase/auth-helpers-nextjs" || pkg_has "@supabase/ssr"; then AUTH="supabase-auth"
elif pkg_has "next-auth" || pkg_has "@auth/core"; then AUTH="nextauth"
elif pkg_has "lucia"; then AUTH="lucia"
elif pkg_has "@clerk/nextjs" || pkg_has "@clerk/clerk-js"; then AUTH="clerk"
elif pkg_has "firebase"; then AUTH="firebase-auth"
fi

# --- Payments ---

PAYMENTS="none"
if pkg_has "stripe" || pkg_has "@stripe/stripe-js"; then PAYMENTS="stripe"
elif pkg_has "@lemonsqueezy/lemonsqueezy.js"; then PAYMENTS="lemonsqueezy"
fi

# --- AI / External APIs ---

AI_APIS="[]"
apis=()
if pkg_has "openai"; then apis+=("openai"); fi
if pkg_has "@anthropic-ai/sdk"; then apis+=("anthropic"); fi
if pkg_has "replicate"; then apis+=("replicate"); fi
if pkg_has "@google/generative-ai"; then apis+=("google-ai"); fi
if pkg_has "ai" || pkg_has "@ai-sdk/openai"; then apis+=("vercel-ai-sdk"); fi
if [[ ${#apis[@]} -gt 0 ]]; then
    AI_APIS="[$(printf '"%s",' "${apis[@]}" | sed 's/,$//')]"
fi

# --- File Storage ---

FILE_STORAGE="none"
if pkg_has "@supabase/storage-js" || (dir_exists "supabase" && DATABASE="supabase"); then
    FILE_STORAGE="supabase-storage"
elif pkg_has "@aws-sdk/client-s3"; then FILE_STORAGE="s3"
elif pkg_has "@cloudflare/workers-types" && grep -rq "R2" . --include="*.ts" --include="*.js" 2>/dev/null; then
    FILE_STORAGE="cloudflare-r2"
fi

# --- CI/CD ---

CI_CD="none"
if dir_exists ".github/workflows"; then CI_CD="github-actions"
elif file_exists ".gitlab-ci.yml"; then CI_CD="gitlab-ci"
fi

# --- Monitoring ---

MONITORING="none"
if pkg_has "@sentry/nextjs" || pkg_has "@sentry/node"; then MONITORING="sentry"
elif pkg_has "dd-trace"; then MONITORING="datadog"
elif pkg_has "@logrocket/react"; then MONITORING="logrocket"
fi

# --- API Routes Detection ---

API_ROUTES=false
API_ROUTE_COUNT=0

# Next.js App Router
if dir_exists "app/api" || dir_exists "src/app/api"; then
    API_ROUTES=true
    API_ROUTE_COUNT=$(find app/api src/app/api -name "route.ts" -o -name "route.js" 2>/dev/null | wc -l | tr -d ' ')
fi
# Next.js Pages Router
if dir_exists "pages/api" || dir_exists "src/pages/api"; then
    API_ROUTES=true
    count=$(find pages/api src/pages/api -name "*.ts" -o -name "*.js" 2>/dev/null | wc -l | tr -d ' ')
    API_ROUTE_COUNT=$((API_ROUTE_COUNT + count))
fi
# SvelteKit
if dir_exists "src/routes" && find src/routes -name "+server.ts" -o -name "+server.js" 2>/dev/null | grep -q .; then
    API_ROUTES=true
    API_ROUTE_COUNT=$(find src/routes -name "+server.ts" -o -name "+server.js" 2>/dev/null | wc -l | tr -d ' ')
fi
# Nuxt
if dir_exists "server/api"; then
    API_ROUTES=true
    API_ROUTE_COUNT=$(find server/api -name "*.ts" -o -name "*.js" 2>/dev/null | wc -l | tr -d ' ')
fi

# --- Environment Files ---

ENV_GITIGNORED=false
ENV_EXAMPLE_EXISTS=false
if file_exists ".gitignore"; then
    if grep -qE "\.env\.local|\.env\.\*|\.env$" .gitignore 2>/dev/null; then
        ENV_GITIGNORED=true
    fi
fi
if file_exists ".env.example" || file_exists ".env.local.example"; then
    ENV_EXAMPLE_EXISTS=true
fi

# --- Client-Side Env Var Exposure ---

CLIENT_VARS="[]"
SENSITIVE_CLIENT_VARS="[]"
client_vars=()
sensitive_vars=()

# Scan for NEXT_PUBLIC_ and VITE_ vars in env files and code
for envfile in .env .env.local .env.example .env.development; do
    if file_exists "$envfile"; then
        while IFS= read -r line; do
            var=$(echo "$line" | grep -oE '^(NEXT_PUBLIC_|VITE_)[A-Z_]+' 2>/dev/null || true)
            if [[ -n "$var" ]]; then
                client_vars+=("$var")
                # Flag potentially sensitive ones
                if echo "$var" | grep -qiE "key|secret|token|password|private"; then
                    sensitive_vars+=("$var")
                fi
            fi
        done < "$envfile"
    fi
done

if [[ ${#client_vars[@]} -gt 0 ]]; then
    CLIENT_VARS="[$(printf '"%s",' "${client_vars[@]}" | sed 's/,$//')]"
else
    CLIENT_VARS="[]"
fi
if [[ ${#sensitive_vars[@]} -gt 0 ]]; then
    SENSITIVE_CLIENT_VARS="[$(printf '"%s",' "${sensitive_vars[@]}" | sed 's/,$//')]"
else
    SENSITIVE_CLIENT_VARS="[]"
fi

# --- Security Checks ---

RLS_ENABLED=0
RLS_MISSING=0
CSP_CONFIGURED=false
CORS_CONFIGURED=false
MIDDLEWARE_EXISTS=false

# Check Supabase RLS in migration files
if dir_exists "supabase/migrations"; then
    RLS_ENABLED=$(grep -rl "ENABLE ROW LEVEL SECURITY" supabase/migrations/ 2>/dev/null | wc -l | tr -d ' ')
    # Count CREATE TABLE statements and compare
    TABLES_CREATED=$(grep -rl "CREATE TABLE" supabase/migrations/ 2>/dev/null | wc -l | tr -d ' ')
    if [[ $TABLES_CREATED -gt $RLS_ENABLED ]]; then
        RLS_MISSING=$((TABLES_CREATED - RLS_ENABLED))
    fi
fi

# CSP check
if grep -rq "Content-Security-Policy" --include="*.ts" --include="*.js" --include="*.mjs" --include="*.toml" . 2>/dev/null; then
    CSP_CONFIGURED=true
fi
if file_exists "_headers" && grep -q "Content-Security-Policy" _headers 2>/dev/null; then
    CSP_CONFIGURED=true
fi

# CORS check
if grep -rq -E "Access-Control-Allow-Origin|cors" --include="*.ts" --include="*.js" . 2>/dev/null; then
    CORS_CONFIGURED=true
fi

# Middleware
if file_exists "middleware.ts" || file_exists "middleware.js" || file_exists "src/middleware.ts" || file_exists "src/middleware.js"; then
    MIDDLEWARE_EXISTS=true
fi

# --- Dependency Count ---

DEP_TOTAL=0
DEP_DEV=0
if file_exists "package.json"; then
    DEP_TOTAL=$(grep -c '"' package.json 2>/dev/null | head -1 || echo 0)
    # Rough count from dependencies block
    DEP_TOTAL=$(python3 -c "
import json, sys
try:
    d = json.load(open('package.json'))
    print(len(d.get('dependencies', {})))
except: print(0)
" 2>/dev/null || echo 0)
    DEP_DEV=$(python3 -c "
import json, sys
try:
    d = json.load(open('package.json'))
    print(len(d.get('devDependencies', {})))
except: print(0)
" 2>/dev/null || echo 0)
fi

# --- Git Info ---

IS_REPO=false
HAS_REMOTE=false
if dir_exists ".git"; then
    IS_REPO=true
    if git remote -v 2>/dev/null | grep -q .; then HAS_REMOTE=true; fi
fi

# --- Warnings ---

# --- Warnings ---

warn_items=()

if [[ "$ENV_GITIGNORED" == "false" ]] && (file_exists ".env" || file_exists ".env.local"); then
    warn_items+=('.env files exist but may not be in .gitignore')
fi
if [[ ${#sensitive_vars[@]} -gt 0 ]]; then
    warn_items+=('Potentially sensitive client-side env vars detected')
fi
if [[ $RLS_MISSING -gt 0 ]]; then
    warn_items+=("$RLS_MISSING tables may be missing RLS policies")
fi
if [[ "$CSP_CONFIGURED" == "false" ]]; then
    warn_items+=('No Content-Security-Policy headers detected')
fi
if [[ "$MIDDLEWARE_EXISTS" == "false" ]] && [[ "$FRAMEWORK" == "next.js" || "$FRAMEWORK" == "nuxt" || "$FRAMEWORK" == "sveltekit" ]]; then
    warn_items+=('No middleware.ts detected — no route-level auth protection')
fi
if [[ "$MONITORING" == "none" ]]; then
    warn_items+=('No error monitoring/observability detected')
fi
if [[ "$CI_CD" == "none" ]]; then
    warn_items+=('No CI/CD pipeline detected')
fi

if [[ ${#warn_items[@]} -gt 0 ]]; then
    WARNINGS="[$(printf '"%s",' "${warn_items[@]}" | sed 's/,$//')]"
else
    WARNINGS="[]"
fi

# --- Output JSON ---

cat <<EOF
{
  "framework": "$FRAMEWORK",
  "framework_version": "$FRAMEWORK_VERSION",
  "rendering": "$RENDERING",
  "typescript": $TYPESCRIPT,
  "hosting": "$HOSTING",
  "database": "$DATABASE",
  "database_tier": "$DATABASE_TIER",
  "auth": "$AUTH",
  "payments": "$PAYMENTS",
  "ai_apis": $AI_APIS,
  "file_storage": "$FILE_STORAGE",
  "cdn_dns": "unknown",
  "ci_cd": "$CI_CD",
  "monitoring": "$MONITORING",
  "api_routes_detected": $API_ROUTES,
  "api_route_count": $API_ROUTE_COUNT,
  "env_files": {
    "gitignored": $ENV_GITIGNORED,
    "example_exists": $ENV_EXAMPLE_EXISTS
  },
  "secrets_exposure": {
    "client_env_vars": $CLIENT_VARS,
    "potentially_sensitive_client_vars": $SENSITIVE_CLIENT_VARS
  },
  "security": {
    "rls_enabled_tables": $RLS_ENABLED,
    "rls_missing_tables": $RLS_MISSING,
    "csp_configured": $CSP_CONFIGURED,
    "cors_configured": $CORS_CONFIGURED,
    "middleware_exists": $MIDDLEWARE_EXISTS
  },
  "backups": "unknown",
  "dependencies": {
    "total": $DEP_TOTAL,
    "dev": $DEP_DEV
  },
  "git": {
    "is_repo": $IS_REPO,
    "has_remote": $HAS_REMOTE
  },
  "warnings": $WARNINGS
}
EOF
