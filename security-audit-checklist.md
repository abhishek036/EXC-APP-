# Security Audit Checklist — Coaching SaaS Platform
**Stack:** Flutter · Node.js + Express · PostgreSQL  
**Tenancy:** Multi-institute · Roles: admin, teacher, student, parent  
**Total items:** 52 across 12 sections

---

## How to use this checklist

- `[ ]` = not started · `[x]` = complete
- **Tags:** `backend` `flutter` `db` `devops`
- **Sprint order:** Critical → High → Medium/Low
- Never skip a Critical item before moving to the next sprint

---

## Sprint 1 — Critical (do first, breach risk today)

### 01 · Authentication

- [ ] **`[CRITICAL]` `backend`** Verify Google ID token server-side  
  Use `google-auth-library` `verifyIdToken()`. Never decode the JWT payload on the client and trust it — always verify the signature against Google's public keys on the server.

### 02 · Authorization & RBAC

- [ ] **`[CRITICAL]` `backend`** Read `institute_id` exclusively from JWT payload  
  Audit every route. Remove any code that reads `institute_id` from `req.body`, `req.params`, or `req.query`. Sign `institute_id` into the JWT at login and extract only from `req.user`.

- [ ] **`[CRITICAL]` `backend`** Create and apply `requireRole()` RBAC middleware  
  Build a single `requireRole(...roles)` middleware. Apply it explicitly to every route. Admin-only: payment approve, user management, fee CRUD. Teacher: class data. Student/parent: own data only.

### 04 · Payment System

- [ ] **`[CRITICAL]` `db`** Add `UNIQUE` constraint to prevent duplicate payment submission  
  `ALTER TABLE payments ADD CONSTRAINT uq_student_fee_month UNIQUE(student_id, fee_id, month_year)`. Add application-level pre-check to return a clear 409 error before the DB constraint fires.

- [ ] **`[CRITICAL]` `backend`** Derive payment amount from server-side fee record  
  Remove `amount` from payment submission request body. Server looks up `fees.amount` using `fee_id` + `institute_id` from JWT. Store the canonical amount — not what the client sent.

### 05 · API Security

- [ ] **`[CRITICAL]` `backend`** Eliminate all string-concatenated SQL queries  
  Grep for `` db.query(`...${) `` patterns. Every query must use parameterized placeholders (`$1`, `$2`). Treat this as a zero-tolerance rule — add ESLint rule `no-template-curly-in-string` for query files.

---

## Sprint 2 — High severity

### 01 · Authentication

- [ ] **`[HIGH]` `flutter`** Replace `SharedPreferences` with `flutter_secure_storage`  
  Store JWT access token and refresh token using `flutter_secure_storage` (Android Keystore / iOS Keychain). Remove any existing `SharedPreferences` usage for tokens.

- [ ] **`[HIGH]` `backend`** Implement short-lived access tokens (15 min expiry)  
  Reduce access token TTL to 15 minutes. Update all token-issuance points (email login, Google login, token refresh).

- [ ] **`[HIGH]` `backend`** Add refresh token rotation with `httpOnly` cookie  
  Issue 7-day refresh token stored in `httpOnly; Secure; SameSite=Strict` cookie. Rotate on every use. Maintain Redis denylist for revoked tokens.

### 02 · Authorization & RBAC

- [ ] **`[HIGH]` `backend`** Fix IDOR on student resource routes  
  `GET /students/:id`, `GET /results/:id`, `GET /attendance/:id` — verify `req.params.id === req.user.id` for student role. For parent role, verify `parent_student` relationship in DB.

- [ ] **`[HIGH]` `backend`** Verify parent-child relationship on every parent request  
  Parents can only access data for linked children. Add a helper `assertParentOwnsStudent(parentId, studentId, institute_id)`. Call it on every parent-scoped route.

### 03 · Multi-tenant Isolation

- [ ] **`[HIGH]` `db`** Add row-level security (RLS) policies in PostgreSQL  
  Enable RLS on `users`, `payments`, `results`, `attendance` tables. Set a policy: `USING (institute_id = current_setting('app.institute_id')::uuid)`. Set the setting via `SET LOCAL` at the start of each request.

### 04 · Payment System

- [ ] **`[HIGH]` `backend`** Restrict payment approval to admin role only  
  `POST /payments/:id/approve` must have `requireRole('admin')` middleware. Verify the payment's `institute_id` matches the admin's `institute_id` from JWT before approving.

- [ ] **`[HIGH]` `backend`** Serve payment screenshots via signed S3 URLs only  
  Move screenshots to a private S3 bucket. Generate presigned GET URLs (15-min TTL) in the API after verifying the requester is admin or the owning student. Never expose the raw S3 key.

- [ ] **`[HIGH]` `backend`** Validate screenshot MIME type by magic bytes  
  Use `file-type` npm package to read actual file magic bytes. Allow only `image/jpeg`, `image/png`, `image/webp`. Reject anything else with 400. Do not trust the `Content-Type` header.

### 05 · API Security

- [ ] **`[HIGH]` `backend`** Add Zod input validation middleware on every route  
  Define a Zod schema per route. Use a `validate(schema)` middleware that calls `safeParse`, returns 400 on failure, and sets `req.body = result.data` (sanitized). Never access `req.body` before validation.

- [ ] **`[HIGH]` `backend`** Apply rate limiting on all endpoints  
  Global: 100 req/min per IP. Auth routes: 10 req/15min per IP. Payment submission: 5/hour per user ID. Use `express-rate-limit` with `standardHeaders: true, legacyHeaders: false`.

- [ ] **`[HIGH]` `backend`** Add global error handler — no stack traces to client  
  Single `app.use((err,req,res,next))` handler at end of middleware chain. Log full error server-side with `pino`. Return only `{error: message, ref: uuid}` to client. Never expose `err.stack`.

### 06 · Database Security

- [ ] **`[HIGH]` `db`** Add indexes on `institute_id`, `student_id`, `fee_id` columns  
  Run `CREATE INDEX CONCURRENTLY` on: `payments(institute_id)`, `payments(student_id, month_year)`, `results(student_id, institute_id)`, `users(institute_id, role)`. Use `CONCURRENTLY` to avoid table locks.

### 07 · File Storage

- [ ] **`[HIGH]` `devops`** Move file storage to private S3 bucket  
  Create a new bucket with Block All Public Access enabled. Set bucket policy to deny public `GetObject`. Migrate existing screenshots. Update any hardcoded public URLs to use the signed URL API.

- [ ] **`[HIGH]` `backend`** Enforce 5 MB file size limit on uploads  
  Set `multer` limits: `{ fileSize: 5 * 1024 * 1024 }`. Return 413 Payload Too Large if exceeded. Also configure your reverse proxy (nginx) with `client_max_body_size 6m` as a second layer.

### 09 · Session & Token Security

- [ ] **`[HIGH]` `backend`** Add `jti` claim to JWTs for revocation support  
  Include a `jti` (JWT ID) UUID claim when issuing tokens. On logout, store the `jti` in Redis with TTL matching token expiry. Check Redis denylist in `requireAuth` before processing the request.

### 10 · Attack Prevention

- [ ] **`[HIGH]` `devops`** Deploy a Web Application Firewall (WAF)  
  Enable WAF rules on your cloud provider (AWS WAF, Cloudflare WAF). At minimum: SQL injection, XSS, HTTP flood, and bad bot rules. WAF operates before requests reach your Node.js server.

### 11 · Logging & Monitoring

- [ ] **`[HIGH]` `backend`** Install structured logger (`pino` or `winston`)  
  `npm install pino pino-pretty`. Replace all `console.log` with `logger.info`, `logger.error`. Every log line must include: timestamp, level, requestId, userId, institute_id, route, duration_ms.

- [ ] **`[HIGH]` `backend`** Log every auth event (login, logout, failure)  
  On login success: log user ID, method (google/email), IP, user agent. On failure: log email (hashed), IP, failure reason. On logout: log user ID, token jti. Never log passwords or tokens.

### 12 · Infrastructure & DevOps

- [ ] **`[HIGH]` `devops`** Move all secrets to environment variables  
  Audit codebase for any hardcoded DB passwords, JWT secrets, S3 keys, or API keys. Move to `.env` locally and to your cloud secrets manager (AWS Secrets Manager, Doppler, or Railway env vars) in production.

---

## Sprint 3 — Medium & Low severity

### 01 · Authentication

- [ ] **`[MEDIUM]` `backend`** Add logout endpoint that invalidates refresh token  
  On logout: clear the `refreshToken` cookie, add the token's `jti` to a Redis denylist (TTL = token expiry). Verify denylist in `requireAuth` middleware.

- [ ] **`[MEDIUM]` `backend`** Validate email/password login against timing attacks  
  Use `bcrypt.compare()` for password checks. Ensure the response time for invalid email vs invalid password is identical (constant-time comparison).

- [ ] **`[LOW]` `backend`** Add account lockout after repeated failed logins  
  After 5 failed login attempts, lock the account for 15 minutes. Store attempt count in Redis with a TTL. Return a generic error — do not reveal which field is wrong.

### 02 · Authorization & RBAC

- [ ] **`[MEDIUM]` `backend`** Audit teacher access — restrict to assigned classes only  
  Teachers should only view/edit students in their assigned classes. Add a `class_assignments` table check. A teacher should not be able to query any student across the institute.

- [ ] **`[MEDIUM]` `backend`** Prevent admin of one institute accessing another  
  Even admins are scoped to their `institute_id` from the JWT. Verify no admin route allows cross-institute queries. Add an integration test that calls admin endpoints with a different `institute_id`.

### 03 · Multi-tenant Isolation

- [ ] **`[MEDIUM]` `db`** Add DB-level `CHECK` constraints on `institute_id`  
  Ensure no record can be inserted without a valid `institute_id`. Add `NOT NULL` constraint and a FK to `institutes` table on every tenant-scoped table.

- [ ] **`[MEDIUM]` `backend`** Write cross-tenant penetration test suite  
  Add automated tests: authenticate as institute A user, attempt to read/write institute B data. All responses must be 403 or 404. Run these in CI on every deploy.

### 04 · Payment System

- [ ] **`[MEDIUM]` `backend`** Log all payment state transitions with actor and timestamp  
  Every status change (pending → approved, pending → rejected) must write to an `audit_log` table: `action`, `actor_id`, `target_payment_id`, `institute_id`, `amount`, `timestamp`. Never delete audit logs.

- [ ] **`[MEDIUM]` `db`** Wrap payment approval in a DB transaction  
  Payment approval touches `payments`, `student_balances`, and `audit_log`. Wrap in `BEGIN/COMMIT/ROLLBACK`. Test that a simulated failure between steps leaves the DB in its pre-transaction state.

- [ ] **`[LOW]` `backend`** Add rate limit on payment screenshot upload  
  Limit payment submissions to 5 per hour per authenticated user ID. Use `express-rate-limit` with `keyGenerator: req => req.user.id`. Return a 429 with a `Retry-After` header.

### 05 · API Security

- [ ] **`[MEDIUM]` `backend`** Install and configure `helmet.js`  
  `npm install helmet`. Add `app.use(helmet())` before all routes. Customize CSP to allow only your own domain and your S3 bucket domain for images.

- [ ] **`[MEDIUM]` `backend`** Add request ID header for log correlation  
  Generate a UUID per request. Attach as `X-Request-Id` response header. Include in every log line. Expose as the `ref` field in error responses.

- [ ] **`[MEDIUM]` `backend`** Sanitize all string inputs against XSS  
  Use `DOMPurify` (server-side via jsdom) or `validator.js` `escape()` on any string stored in DB that will be rendered in a web view. Especially: student names, notes, comments fields.

- [ ] **`[LOW]` `backend`** Add CORS policy — allow only your frontend origin  
  Use `cors` npm package. Set `origin` to your Flutter web domain or mobile app scheme. Do not use `origin: '*'`. Explicitly list allowed methods and headers.

### 06 · Database Security

- [ ] **`[MEDIUM]` `db`** Set least-privilege DB user for the application  
  Create a dedicated DB role (`app_user`) with only `SELECT`, `INSERT`, `UPDATE` on application tables. Never connect as `postgres` or a superuser. Store credentials in environment variables, never in code.

- [ ] **`[MEDIUM]` `db`** Enable SSL for all DB connections  
  Set `ssl: { rejectUnauthorized: true }` in `pg` Pool config. Verify the server certificate. Do not use `ssl: true` with `rejectUnauthorized: false` in production — that is equivalent to no SSL.

- [ ] **`[MEDIUM]` `db`** Run `EXPLAIN ANALYZE` on the 5 heaviest queries  
  Identify the 5 most-called queries using `pg_stat_statements`. Run `EXPLAIN ANALYZE` on each. Fix any Seq Scan on large tables. Target: no query over 50ms at P95.

- [ ] **`[LOW]` `db`** Evaluate PgBouncer for connection pooling  
  If concurrent users exceed 50, add PgBouncer in transaction-pooling mode. Configure `pool_size = (2 × CPU cores)`. Prevents connection exhaustion under load spikes.

- [ ] **`[LOW]` `db`** Schedule automated DB backups and test restore  
  Enable daily automated backups or `pg_dump` to encrypted S3. Monthly restore drill: restore to a staging environment and verify data integrity.

### 07 · File Storage

- [ ] **`[MEDIUM]` `backend`** Generate presigned PUT URLs for direct S3 uploads  
  Client requests a presigned PUT URL from your API (after auth). Client uploads directly to S3. Server receives the S3 key via callback. This avoids routing the file through your Node.js server.

- [ ] **`[MEDIUM]` `backend`** Store only S3 object key in DB, never full URL  
  Signed URLs change on every generation. Storing the key lets you generate fresh URLs on demand. Add a `NOT NULL` constraint on `screenshot_key` column and remove any `screenshot_url` columns.

### 08 · Data Consistency

- [ ] **`[MEDIUM]` `backend`** Move all fee/balance calculations to backend  
  Audit the Flutter app for any arithmetic on fee data. Replace with API calls that return pre-calculated values from SQL `SUM`/`COUNT` queries. Frontend is read-only display.

- [ ] **`[MEDIUM]` `backend`** Wrap all multi-step operations in DB transactions  
  Identify operations that touch 2+ tables: payment approval, enrollment, fee creation. Wrap each in a transaction using `pg` client `pool.connect()` + `BEGIN/COMMIT/ROLLBACK` pattern.

- [ ] **`[MEDIUM]` `backend`** Make all writes idempotent where possible  
  Add idempotency keys (UUID from client) on payment submissions. Store the key in `payments` table. If same key arrives twice, return the original response without a duplicate insert.

- [ ] **`[LOW]` `backend`** Add `created_at` / `updated_at` timestamps to all tables  
  Every table should have `created_at TIMESTAMPTZ DEFAULT NOW()` and `updated_at` updated via trigger. Enables audit trails and debugging data inconsistencies.

### 09 · Session & Token Security

- [ ] **`[MEDIUM]` `flutter`** Clear all tokens on logout in Flutter  
  On logout: call logout API, await confirmation, then call `flutter_secure_storage.deleteAll()`. Also clear any in-memory state (Provider/Bloc). Do not navigate away until storage is cleared.

- [ ] **`[MEDIUM]` `flutter`** Handle token expiry gracefully in Flutter HTTP client  
  Intercept 401 responses in a Dio interceptor. Attempt one silent refresh using the refresh token. If refresh fails, log the user out and redirect to login. Do not retry indefinitely.

- [ ] **`[LOW]` `flutter`** Implement certificate pinning for production API  
  Use `dio_certificate_pinning` or `http_certificate_pinning`. Pin your API's leaf certificate SHA-256 fingerprint. Prevents MITM attacks on compromised networks. Update pins with each cert renewal.

### 10 · Attack Prevention

- [ ] **`[MEDIUM]` `backend`** Add brute-force protection beyond rate limiting  
  Track login failures per email address (not just IP). After 5 failures for an email, require CAPTCHA or impose a 15-minute lockout. Prevents distributed brute force from many IPs.

- [ ] **`[MEDIUM]` `backend`** Validate all redirect URLs server-side  
  If any endpoint accepts a redirect parameter (OAuth callback, post-login redirect), validate it against an allowlist of your own domains. Prevents open redirect attacks.

- [ ] **`[LOW]` `devops`** Set up anomaly alerting for unusual API patterns  
  Alert on: >50 req/min from a single IP, >10 payment submissions from one user in an hour, admin actions outside business hours, logins from new countries. Use Datadog, Grafana, or CloudWatch.

### 11 · Logging & Monitoring

- [ ] **`[MEDIUM]` `backend`** Log all admin actions to immutable audit table  
  Every admin action (approve payment, change role, edit fee, delete user) writes to `audit_log(id, action, actor_id, target_id, before_state, after_state, institute_id, created_at)`. Never update or delete this table.

- [ ] **`[MEDIUM]` `devops`** Ship logs to a centralized log service  
  Use CloudWatch Logs, Logtail, or Papertrail. Set log retention to 90 days minimum. Configure search alerts on ERROR level, payment approval events, and 5xx spikes.

- [ ] **`[LOW]` `devops`** Add health check and uptime monitoring  
  Create `GET /health` endpoint returning `{status:'ok', db:'connected', version}`. Connect to UptimeRobot or Betterstack. Alert on downtime within 1 minute. Expose to load balancer for auto-recovery.

### 12 · Infrastructure & DevOps

- [ ] **`[MEDIUM]` `devops`** Enable HTTPS everywhere — enforce HSTS  
  Verify all traffic is HTTPS. Set `Strict-Transport-Security: max-age=31536000; includeSubDomains` via `helmet`. Redirect all HTTP to HTTPS at the load balancer/nginx level.

- [ ] **`[MEDIUM]` `devops`** Add security scanning to CI/CD pipeline  
  Add `npm audit`, Snyk or OWASP Dependency Check to your GitHub Actions / CI pipeline. Fail the build on high-severity CVEs in dependencies. Run on every PR.

- [ ] **`[LOW]` `devops`** Enable automatic dependency updates  
  Add Dependabot or Renovate to the repository. Configure it to auto-update patch versions and open PRs for minor/major. Keeps you ahead of known CVEs without manual tracking.

- [ ] **`[LOW]` `devops`** Document incident response procedure  
  Write a one-page runbook: how to revoke all tokens (flush Redis), how to rotate JWT secret (force re-login for all users), who to notify on breach, how to roll back a bad deploy.

---

## Summary by sprint

| Sprint | Severity | Items | Owner |
|--------|----------|-------|-------|
| Sprint 1 | Critical | 6 | backend, db |
| Sprint 2 | High | 19 | backend, flutter, db, devops |
| Sprint 3 | Medium + Low | 27 | backend, flutter, db, devops |
| **Total** | | **52** | |

## Summary by tag

| Tag | Items |
|-----|-------|
| `backend` | 33 |
| `db` | 11 |
| `devops` | 10 |
| `flutter` | 5 |

---

*Generated from full security audit — Flutter + Node.js + Express + PostgreSQL multi-tenant SaaS*
