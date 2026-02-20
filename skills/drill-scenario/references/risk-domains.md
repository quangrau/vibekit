# Risk Domains — Scenario Seed Library

Optional reference. Read this when you need more scenario variety beyond what
`generate-drill.sh` and `generate-checklist.sh` produce.

**Scope**: Web applications only (SPA, SSR, full-stack).

---

## 1. 💸 Cost & Billing
**Big-tech concept**: DDoS mitigation, cost anomaly detection, billing alerts, rate limiting.

**Extra scenario seeds**:
- Crypto mining bot discovers your unprotected serverless function and runs expensive compute
- Competitor scrapes your site aggressively, burning through Vercel bandwidth
- Your OpenAI-powered feature goes viral on TikTok — legitimate traffic but unsustainable cost
- Stripe webhook endpoint called in a loop by attacker, triggering rate-limited API calls downstream

**Extra checklist items**:
- Verify Cloudflare free-tier DDoS protection is active (if using Cloudflare)
- Check if Vercel Attack Challenge Mode is enabled or ready to enable
- Review serverless function timeout settings (long timeouts = higher cost per abuse)

---

## 2. 🗑️ Data Loss
**Big-tech concept**: RPO/RTO, backup testing, PITR, blue-green deployments, failover.

**Extra scenario seeds**:
- Drizzle migration generates wrong SQL — drops a column with user data
- Supabase applies an auto-update that changes auth schema, breaking your app's user queries
- You accidentally run a DELETE without a WHERE clause in the Supabase SQL editor
- Free-tier Supabase project paused during your vacation — 95 days idle, data at risk

**Extra checklist items**:
- Test restoring from your backup (have you ever actually done this?)
- If Supabase free tier: keep project active (ping endpoint via cron to prevent auto-pause)
- Verify migration files in git match production schema (drift detection)
- Know your RTO: how long to go from "database is gone" to "app is working"

---

## 3. 🔐 Secrets & Credentials
**Big-tech concept**: Secret vaults, rotation procedures, blast radius mapping, credential lifecycle.

**Extra scenario seeds**:
- GitHub Copilot suggests code that hardcodes your API key in a client component
- Your Supabase service_role key (full admin access) is accidentally used in client-side code
- Someone forks your public repo — your old .env.local is in commit history from 3 months ago
- A dependency update changes how env vars are loaded, accidentally exposing server vars to the client bundle

**Extra checklist items**:
- Map every secret: where stored → where used → how to rotate → blast radius if leaked
- Test rotation: can you rotate every key in under 5 minutes?
- Verify NEXT_PUBLIC_ / VITE_ vars contain ONLY public-safe values
- Check build logs for leaked secrets (Vercel build output is visible in dashboard)

---

## 4. 🔓 Access Control
**Big-tech concept**: IAM, RBAC, zero trust, least privilege, access reviews.

**Extra scenario seeds**:
- User changes their own user_id in a PATCH request and modifies another user's profile (IDOR)
- Supabase storage bucket is public — user uploads HTML files with JavaScript (stored XSS vector)
- Admin-only API route checks `isAdmin` from client-sent JWT claim instead of database role
- OAuth callback URL accepts wildcards, enabling open redirect attacks

**Extra checklist items**:
- Test: curl your API routes with a forged/missing auth token — what happens?
- Verify Supabase storage policies match your RLS policies in strictness
- Check for `dangerouslySetInnerHTML` / `v-html` rendering user content
- Review all `NEXT_PUBLIC_SUPABASE_ANON_KEY` usage — it should ONLY work with RLS

---

## 5. 🚫 Availability
**Big-tech concept**: SLOs/SLIs, graceful degradation, circuit breakers, incident communication.

**Extra scenario seeds**:
- Your app works fine but Supabase Auth is down — users can't log in but data is accessible
- SSL certificate expired on your custom domain — browsers show scary security warning
- Next.js ISR (Incremental Static Regeneration) serves stale data for 6 hours after a DB change
- CDN caches an authenticated page — logged-out users see another user's dashboard

**Extra checklist items**:
- Know all your upstream status pages: status.supabase.com, vercel.com/status, etc.
- Have a way to tell users what's happening (Discord, Twitter, status page like Instatus)
- Understand your CDN caching — are authenticated routes excluded from cache?
- Test: what does your app do if Supabase is unreachable? Does it crash or degrade gracefully?

---

## 6. 🤖 Code Vulnerabilities
**Big-tech concept**: SAST/DAST, OWASP Top 10, SBOM, CVE monitoring, dependency management.

**Extra scenario seeds**:
- npm audit reveals a prototype pollution vulnerability in a popular utility library
- AI-generated form handler doesn't sanitize input — SQL injection in search endpoint
- Your `<Script>` tag loads analytics from a CDN that got compromised (supply chain attack)
- Debug middleware logs full request bodies including passwords and tokens to console

**Extra checklist items**:
- Search codebase for `eval()`, `innerHTML`, `dangerouslySetInnerHTML` with user input
- Verify all forms have CSRF protection (Next.js Server Actions handle this, but custom API routes may not)
- Check HTTP response headers: X-Frame-Options, X-Content-Type-Options, Referrer-Policy
- Review AI-generated code that handles: auth, payments, file uploads, database queries

---

## 7. 🔄 Recoverability
**Big-tech concept**: BCP (ISO 22301), infrastructure as code, rebuild drills, vendor diversification.

**Extra scenario seeds**:
- Vercel suspends your account for TOS violation (they think your AI app generates prohibited content)
- Your domain registrar account is compromised — domain transferred to attacker
- GitHub has a major outage — you can't deploy, access code, or run CI for 12 hours
- Supabase free tier project was on your personal email — you lose access to that email account

**Extra checklist items**:
- Could you deploy to Netlify/Cloudflare Pages if Vercel disappeared? What breaks?
- Are your env vars documented somewhere other than just the Vercel dashboard?
- Is your domain registrar account secured with 2FA and recovery options?
- Do you have local copies of critical data, or is everything only in the cloud?

---

## Web-App-Specific Attack Surface (reminder)
These are unique to web apps — always consider in scenarios:
- Client bundle exposure (NEXT_PUBLIC_, VITE_ vars)
- API route surface (every /api/* is public)
- CORS misconfiguration → any site can call your API
- CSP gaps → XSS and data exfiltration
- Serverless limits → function timeouts, memory, invocation quotas
- CDN caching → stale or authenticated data served incorrectly
- Browser storage → localStorage/cookies accessible via XSS
- OAuth redirects → open redirects, state parameter misuse
- SSR data leakage → server data serialized into client HTML
