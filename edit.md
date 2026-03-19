# neurovaX — Coaching SaaS Platform
## Complete Firebase → VPS Migration Prompt
### For: GitHub Copilot / Cursor / Claude Agent
**Company:** neurovaX | www.neurovax.tech | neurova.business@gmail.com  
**Version:** 1.0 | Stack: Flutter + Node.js + PostgreSQL + Redis + NGINX  

---

## WHO YOU ARE

You are a senior full-stack engineer with 8+ years of experience building multi-tenant SaaS products. You write clean, production-ready TypeScript. You never use placeholders or TODOs. Every function has error handling. Every API has input validation. You think about security, performance, and maintainability before writing a single line.

You are building **CoachPro** — a coaching institute management SaaS by **neurovaX**. The app serves multiple coaching institutes from one backend. The Flutter mobile app is already partially built using Firebase. Your job is to **rip out Firebase completely** and replace it with a proper backend we own and control.

---

## WHAT WE ARE BUILDING

A multi-tenant SaaS platform where:
- **One Flutter app** serves all coaching institutes
- **One backend** runs on a single DigitalOcean VPS ($6/month)
- **Each institute** gets isolated data via `institute_id` on every record
- **4 user roles**: Admin, Teacher, Student, Parent
- The system starts cheap and scales without a rewrite

---

## INFRASTRUCTURE WE HAVE (USE THESE — DON'T SUGGEST PAID ALTERNATIVES)

| Resource | Provider | Credit | Use For |
|---|---|---|---|
| VPS — 1 CPU / 2GB RAM / 50GB SSD | DigitalOcean | $200 credit | Main server — runs everything |
| Managed PostgreSQL | DigitalOcean | $200 credit | Primary database |
| Azure VM B1s | Azure Student | $9,085 credit | Staging server |
| Azure Blob Storage | Azure Student | $9,085 credit | PDF receipts, notes backup |
| Domain + SSL | Namecheap | GitHub Pack | neurovax.tech + client subdomains |
| Email | Mailgun | GitHub Pack | Receipts, OTP fallback |
| Error monitoring | Sentry | GitHub Pack | Crash tracking |
| CI/CD | GitHub Actions | Free | Auto-deploy on push |
| AI coding | GitHub Copilot | Free | Use throughout |

**Monthly cost after credits: ~$6/month total. That is the budget.**

---

## WHAT WE ARE REMOVING (FIREBASE — ALL OF IT)

| Firebase Service | Status | Replaced With |
|---|---|---|
| Firebase Authentication | **REMOVE** | JWT + bcrypt in our own auth module |
| Firestore | **REMOVE** | PostgreSQL with Prisma ORM |
| Firebase Realtime Database | **REMOVE** | PostgreSQL + Socket.IO for chat |
| Firebase Storage | **REMOVE** | Local VPS disk → Azure Blob later |
| Firebase Cloud Functions | **REMOVE** | Node.js cron jobs + Bull Queue |
| Firebase Cloud Messaging (FCM) | **REMOVE** | WhatsApp Business API |
| Firebase Analytics | **REMOVE** | Sentry + custom dashboard |
| Firebase Hosting | **REMOVE** | NGINX on DigitalOcean VPS |

> **IMPORTANT:** Do NOT keep any `firebase`, `firebase_core`, `firebase_auth`, `cloud_firestore`, or `firebase_messaging` packages in the Flutter app after migration. Zero Firebase dependencies.

---

## SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────┐
│         Flutter Mobile App              │
│   (Android + iOS — 4 role dashboards)   │
└──────────────────┬──────────────────────┘
                   │ HTTPS
┌──────────────────▼──────────────────────┐
│           NGINX (Port 80/443)           │
│   SSL termination + reverse proxy       │
│   Rate limiting + static file serving   │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│         Node.js API (Port 3000)         │
│   Express + TypeScript                  │
│   JWT Auth middleware                   │
│   Role-based access control             │
│   Zod input validation                  │
│   Institute isolation middleware        │
└────┬─────────────┬────────────┬─────────┘
     │             │            │
┌────▼────┐  ┌────▼────┐  ┌───▼──────┐
│Postgres │  │  Redis  │  │Local     │
│Database │  │  Cache  │  │Storage   │
│(Prisma) │  │(BullMQ) │  │/uploads  │
└─────────┘  └─────────┘  └──────────┘
```

**Everything runs on ONE VPS. One `docker-compose.yml` starts the whole system.**

---

## MULTI-TENANT DESIGN — THE MOST IMPORTANT RULE

Every single database table has `institute_id`. Every single query filters by `institute_id`. This is non-negotiable.

```typescript
// This middleware runs on EVERY authenticated request
export const tenantMiddleware = (req: Request, res: Response, next: NextFunction) => {
  req.instituteId = req.user.instituteId; // extracted from JWT
  next();
};

// Every repository method looks like this
async getStudents(instituteId: string, filters: StudentFilters) {
  return prisma.student.findMany({
    where: { 
      institute_id: instituteId,  // ALWAYS filter by institute
      ...buildFilters(filters)
    }
  });
}
```

**An admin from Institute A must NEVER see data from Institute B. Ever.**

---

## AUTHENTICATION SYSTEM

### JWT Flow (replaces Firebase Auth completely)

```
1. User opens app → enters phone number
2. App hits POST /auth/otp/send → backend sends WhatsApp OTP
3. User enters OTP → App hits POST /auth/otp/verify
4. Backend validates OTP → returns JWT access token + refresh token
5. App stores access token in memory, refresh token in flutter_secure_storage
6. Every API call includes: Authorization: Bearer <access_token>
7. On 401 → app silently hits POST /auth/refresh → gets new access token
```

### JWT Token Structure

```typescript
// Access Token — expires in 15 minutes
{
  userId: "uuid",
  role: "admin" | "teacher" | "student" | "parent",
  instituteId: "uuid",
  phone: "919876543210",
  iat: 1234567890,
  exp: 1234568790
}

// Refresh Token — expires in 30 days
// Stored hashed in database, not in JWT
// Rotation: every refresh issues a new refresh token
```

### Auth Endpoints

```
POST /auth/otp/send         → send WhatsApp OTP (rate limit: 5/hour/phone)
POST /auth/otp/verify       → verify OTP → return tokens
POST /auth/refresh          → new access token from refresh token
POST /auth/logout           → revoke refresh token
GET  /auth/me               → current user profile
POST /auth/sessions/revoke  → admin: force logout all devices for a user
```

### Password-based login (Admin/Teacher — they can also use password)

```
POST /auth/login            → phone + password → return tokens
POST /auth/password/change  → change password (requires old password)
POST /auth/password/reset   → request reset OTP → verify → set new password
```

---

## WHATSAPP INTEGRATION (Replaces Firebase Messaging entirely)

We use WhatsApp for ALL notifications. Not SMS. Not email. Not push notifications. WhatsApp.

**Why:** Indian parents and students read WhatsApp immediately. SMS gets ignored. Push notifications get disabled. WhatsApp has 95%+ open rate.

### Provider

Use **Twilio WhatsApp API** (we have $50 credit from GitHub Pack) or **MSG91 WhatsApp** (₹0.115 per message as agreed).

### WhatsApp Message Types

```typescript
enum WhatsAppMessageType {
  OTP_VERIFICATION    = 'otp_verification',
  FEE_REMINDER_7D     = 'fee_reminder_7_days',
  FEE_REMINDER_1D     = 'fee_reminder_1_day',
  FEE_OVERDUE         = 'fee_overdue',
  PAYMENT_CONFIRMED   = 'payment_confirmed',
  ABSENT_ALERT        = 'absent_alert',       // to parent
  EXAM_REMINDER       = 'exam_reminder',      // to student
  RESULT_PUBLISHED    = 'result_published',   // to student + parent
  ASSIGNMENT_POSTED   = 'assignment_posted',  // to student
  LIVE_CLASS_REMINDER = 'live_class_15min',   // to student
  ANNOUNCEMENT        = 'announcement',       // batch-wide or institute-wide
  DOUBT_ANSWERED      = 'doubt_answered',     // to student
}
```

### Message Templates (pre-approved format for WhatsApp Business API)

```
OTP:
"Your CoachPro verification code is {{otp}}. Valid for 10 minutes. Do not share this with anyone."

Fee Reminder:
"Dear {{parent_name}}, fee of ₹{{amount}} for {{student_name}} is due on {{due_date}}. 
Pay now: {{payment_link}}. Contact: {{institute_phone}}"

Absent Alert:
"{{student_name}} was marked ABSENT today ({{date}}) in {{batch_name}}. 
Contact {{teacher_name}} for details. - {{institute_name}}"

Result Published:
"{{student_name}} scored {{marks}}/{{total}} in {{exam_name}}. 
Grade: {{grade}}. Rank: {{rank}} in batch. - {{institute_name}}"
```

### WhatsApp Service

```typescript
// src/modules/whatsapp/whatsapp.service.ts
class WhatsAppService {
  async sendOTP(phone: string, otp: string): Promise<void>
  async sendFeeReminder(studentId: string, daysLeft: number): Promise<void>
  async sendAbsentAlert(studentId: string, date: string): Promise<void>
  async sendExamReminder(batchId: string, examId: string): Promise<void>
  async sendResultNotification(studentId: string, examId: string): Promise<void>
  async sendBulkAnnouncement(instituteId: string, batchId: string | null, message: string): Promise<void>
  async sendPaymentConfirmation(studentId: string, receiptUrl: string): Promise<void>
}
```

**Pricing note:** ₹0.115 per WhatsApp message. Bill this to clients as part of AMC or usage-based add-on.

---

## DATABASE SCHEMA (PostgreSQL — Full Schema)

### Core Tables

```sql
-- Every institute using the platform
CREATE TABLE institutes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            VARCHAR(200) NOT NULL,
  slug            VARCHAR(100) UNIQUE NOT NULL,  -- used in subdomain
  logo_url        TEXT,
  address         TEXT,
  phone           VARCHAR(15),
  email           VARCHAR(200),
  website         VARCHAR(200),
  primary_color   VARCHAR(7) DEFAULT '#3F72AF',
  settings        JSONB DEFAULT '{}',
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- All users across all institutes
CREATE TABLE users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institute_id    UUID NOT NULL REFERENCES institutes(id) ON DELETE CASCADE,
  phone           VARCHAR(15) NOT NULL,
  email           VARCHAR(200),
  password_hash   VARCHAR(255),
  role            VARCHAR(20) NOT NULL CHECK (role IN ('admin','teacher','student','parent')),
  is_active       BOOLEAN DEFAULT true,
  last_login_at   TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (institute_id, phone)
);

-- Refresh tokens (JWT rotation)
CREATE TABLE refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  VARCHAR(255) NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- OTP store
CREATE TABLE otp_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       VARCHAR(15) NOT NULL,
  code        VARCHAR(6) NOT NULL,
  purpose     VARCHAR(50) NOT NULL,  -- login, password_reset
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ,
  attempts    INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### People Tables

```sql
CREATE TABLE teachers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  name            VARCHAR(200) NOT NULL,
  email           VARCHAR(200),
  subjects        TEXT[],
  qualification   VARCHAR(200),
  photo_url       TEXT,
  joining_date    DATE,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE students (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES users(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  name            VARCHAR(200) NOT NULL,
  phone           VARCHAR(15),
  dob             DATE,
  gender          VARCHAR(10),
  address         TEXT,
  photo_url       TEXT,
  blood_group     VARCHAR(5),
  enrollment_date DATE DEFAULT CURRENT_DATE,
  student_code    VARCHAR(20),              -- auto-generated or manual
  prev_institute  VARCHAR(200),
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE parents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES users(id),
  student_id      UUID NOT NULL REFERENCES students(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  name            VARCHAR(200) NOT NULL,
  phone           VARCHAR(15) NOT NULL,
  relation        VARCHAR(20),              -- father, mother, guardian
  occupation      VARCHAR(100),
  is_primary      BOOLEAN DEFAULT true      -- main contact for notifications
);
```

### Batch & Timetable Tables

```sql
CREATE TABLE batches (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  name            VARCHAR(200) NOT NULL,
  subject         VARCHAR(100),
  teacher_id      UUID REFERENCES teachers(id),
  days_of_week    INT[],                    -- 0=Sun,1=Mon...6=Sat
  start_time      TIME,
  end_time        TIME,
  room            VARCHAR(50),
  start_date      DATE,
  end_date        DATE,
  capacity        INT,
  batch_type      VARCHAR(20) DEFAULT 'regular',  -- regular,crash,test_series
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE student_batches (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      UUID NOT NULL REFERENCES students(id),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  joined_date     DATE DEFAULT CURRENT_DATE,
  left_date       DATE,
  is_active       BOOLEAN DEFAULT true,
  UNIQUE (student_id, batch_id)
);
```

### Fee Tables

```sql
CREATE TABLE fee_structures (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  monthly_fee     NUMERIC(10,2) NOT NULL,
  admission_fee   NUMERIC(10,2) DEFAULT 0,
  exam_fee        NUMERIC(10,2) DEFAULT 0,
  late_fee_amount NUMERIC(10,2) DEFAULT 0,
  late_after_day  INT DEFAULT 10,           -- charge late fee after 10th of month
  grace_days      INT DEFAULT 0
);

CREATE TABLE fee_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      UUID NOT NULL REFERENCES students(id),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  month           INT NOT NULL,             -- 1-12
  year            INT NOT NULL,
  total_amount    NUMERIC(10,2) NOT NULL,
  discount_amount NUMERIC(10,2) DEFAULT 0,
  late_fee        NUMERIC(10,2) DEFAULT 0,
  final_amount    NUMERIC(10,2) NOT NULL,
  due_date        DATE NOT NULL,
  status          VARCHAR(20) DEFAULT 'pending' 
                  CHECK (status IN ('paid','partial','pending','overdue','waived')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (student_id, batch_id, month, year)
);

CREATE TABLE fee_payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fee_record_id   UUID NOT NULL REFERENCES fee_records(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  amount_paid     NUMERIC(10,2) NOT NULL,
  payment_mode    VARCHAR(20) CHECK (payment_mode IN ('cash','upi','card','bank','cheque','online')),
  transaction_id  VARCHAR(200),
  note            TEXT,
  receipt_number  VARCHAR(50) UNIQUE,
  receipt_url     TEXT,                     -- stored on Azure Blob or local /uploads
  paid_at         TIMESTAMPTZ DEFAULT NOW(),
  collected_by    UUID REFERENCES users(id)
);

CREATE TABLE fee_discounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      UUID NOT NULL REFERENCES students(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  discount_type   VARCHAR(10) CHECK (discount_type IN ('flat','percent')),
  amount          NUMERIC(10,2) NOT NULL,
  reason          TEXT,
  valid_from      DATE,
  valid_to        DATE
);
```

### Attendance Tables

```sql
CREATE TABLE attendance_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  teacher_id      UUID REFERENCES teachers(id),
  session_date    DATE NOT NULL,
  submitted_at    TIMESTAMPTZ,
  is_corrected    BOOLEAN DEFAULT false,
  UNIQUE (batch_id, session_date)
);

CREATE TABLE attendance_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES attendance_sessions(id),
  student_id      UUID NOT NULL REFERENCES students(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  status          VARCHAR(10) CHECK (status IN ('present','absent','late','leave')),
  corrected_by    UUID REFERENCES users(id),
  correction_note TEXT,
  UNIQUE (session_id, student_id)
);

CREATE TABLE holidays (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  holiday_date    DATE NOT NULL,
  description     VARCHAR(200),
  UNIQUE (institute_id, holiday_date)
);
```

### Exam & Quiz Tables

```sql
CREATE TABLE exams (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  title           VARCHAR(200) NOT NULL,
  subject         VARCHAR(100),
  exam_date       DATE NOT NULL,
  total_marks     INT NOT NULL,
  passing_marks   INT,
  duration_min    INT,
  created_by      UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exam_batches (
  exam_id         UUID REFERENCES exams(id),
  batch_id        UUID REFERENCES batches(id),
  PRIMARY KEY (exam_id, batch_id)
);

CREATE TABLE exam_results (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id         UUID NOT NULL REFERENCES exams(id),
  student_id      UUID NOT NULL REFERENCES students(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  marks_obtained  NUMERIC(6,2),
  is_absent       BOOLEAN DEFAULT false,
  grade           VARCHAR(5),
  rank_in_batch   INT,
  UNIQUE (exam_id, student_id)
);

CREATE TABLE quizzes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  teacher_id      UUID REFERENCES teachers(id),
  title           VARCHAR(200) NOT NULL,
  subject         VARCHAR(100),
  time_limit_min  INT,
  is_published    BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE quiz_questions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id         UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  question_text   TEXT NOT NULL,
  image_url       TEXT,
  option_a        TEXT NOT NULL,
  option_b        TEXT NOT NULL,
  option_c        TEXT NOT NULL,
  option_d        TEXT NOT NULL,
  correct_option  CHAR(1) CHECK (correct_option IN ('A','B','C','D')),
  marks           INT DEFAULT 1,
  order_index     INT DEFAULT 0
);

CREATE TABLE quiz_attempts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id         UUID NOT NULL REFERENCES quizzes(id),
  student_id      UUID NOT NULL REFERENCES students(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  started_at      TIMESTAMPTZ DEFAULT NOW(),
  submitted_at    TIMESTAMPTZ,
  total_marks     INT,
  obtained_marks  INT,
  rank            INT,
  answers         JSONB,  -- { questionId: selectedOption }
  UNIQUE (quiz_id, student_id)
);
```

### Content, Doubts, Chat, Lectures

```sql
CREATE TABLE notes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  teacher_id      UUID REFERENCES teachers(id),
  title           VARCHAR(200) NOT NULL,
  subject         VARCHAR(100),
  file_url        TEXT NOT NULL,  -- local path or Azure Blob URL
  file_type       VARCHAR(20),    -- pdf, image, doc
  file_size_kb    INT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE assignments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  teacher_id      UUID REFERENCES teachers(id),
  title           VARCHAR(200) NOT NULL,
  description     TEXT,
  due_date        DATE,
  file_url        TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE doubts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  student_id      UUID NOT NULL REFERENCES students(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  assigned_to     UUID REFERENCES teachers(id),
  question_text   TEXT NOT NULL,
  question_img    TEXT,
  answer_text     TEXT,
  answer_img      TEXT,
  status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','resolved')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  resolved_at     TIMESTAMPTZ
);

CREATE TABLE chat_messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  sender_id       UUID NOT NULL REFERENCES users(id),
  sender_name     VARCHAR(200) NOT NULL,
  sender_role     VARCHAR(20) NOT NULL,
  message         TEXT,
  image_url       TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- YouTube integration — no video hosting on our server
CREATE TABLE lectures (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  teacher_id      UUID REFERENCES teachers(id),
  title           VARCHAR(200) NOT NULL,
  description     TEXT,
  youtube_url     TEXT NOT NULL,  -- YouTube video or live stream URL
  lecture_type    VARCHAR(20) CHECK (lecture_type IN ('live','recorded')),
  scheduled_at    TIMESTAMPTZ,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE announcements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  title           VARCHAR(200) NOT NULL,
  body            TEXT NOT NULL,
  attachment_url  TEXT,
  target_role     VARCHAR(20),          -- null = all, else specific role
  target_batch_id UUID REFERENCES batches(id),  -- null = all batches
  send_whatsapp   BOOLEAN DEFAULT false,
  scheduled_at    TIMESTAMPTZ,
  sent_at         TIMESTAMPTZ,
  created_by      UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE syllabus_topics (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES batches(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  subject         VARCHAR(100),
  chapter_name    VARCHAR(200),
  topic_name      VARCHAR(200) NOT NULL,
  order_index     INT DEFAULT 0
);

CREATE TABLE student_syllabus_progress (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      UUID NOT NULL REFERENCES students(id),
  topic_id        UUID NOT NULL REFERENCES syllabus_topics(id),
  institute_id    UUID NOT NULL REFERENCES institutes(id),
  is_completed    BOOLEAN DEFAULT false,
  completed_at    TIMESTAMPTZ,
  UNIQUE (student_id, topic_id)
);

CREATE TABLE audit_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id        UUID REFERENCES users(id),
  institute_id    UUID REFERENCES institutes(id),
  action          VARCHAR(100) NOT NULL,
  entity_type     VARCHAR(50),
  entity_id       UUID,
  old_value       JSONB,
  new_value       JSONB,
  ip_address      INET,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## PROJECT FOLDER STRUCTURE

```
/coachpro-backend/
├── src/
│   ├── app.ts                    ← Express app setup
│   ├── server.ts                 ← Start server, connect DB
│   ├── config/
│   │   ├── env.ts                ← All env vars with Zod validation
│   │   ├── database.ts           ← Prisma client singleton
│   │   └── redis.ts              ← Redis client singleton
│   ├── middleware/
│   │   ├── auth.middleware.ts    ← JWT verify → attach req.user
│   │   ├── tenant.middleware.ts  ← Attach req.instituteId
│   │   ├── role.middleware.ts    ← requireRole('admin','teacher')
│   │   ├── validate.middleware.ts← Zod validation wrapper
│   │   ├── rateLimit.middleware.ts← Per-route rate limiting
│   │   └── error.middleware.ts   ← Central error handler
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── auth.routes.ts
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── auth.repository.ts
│   │   │   └── auth.validator.ts
│   │   ├── student/
│   │   ├── teacher/
│   │   ├── batch/
│   │   ├── fee/
│   │   ├── attendance/
│   │   ├── exam/
│   │   ├── quiz/
│   │   ├── content/
│   │   ├── lecture/           ← YouTube integration
│   │   ├── doubt/
│   │   ├── chat/              ← Socket.IO
│   │   ├── announcement/
│   │   ├── analytics/
│   │   ├── whatsapp/          ← All notification logic
│   │   └── institute/         ← Settings, branding
│   ├── jobs/
│   │   ├── queue.ts           ← BullMQ queue setup
│   │   ├── fee-reminder.job.ts
│   │   ├── absent-alert.job.ts
│   │   ├── exam-reminder.job.ts
│   │   ├── monthly-fee-create.job.ts
│   │   └── db-backup.job.ts
│   ├── utils/
│   │   ├── response.ts        ← Standard response envelope
│   │   ├── pagination.ts      ← Cursor/offset pagination helper
│   │   ├── pdf.generator.ts   ← Fee receipt PDF (pdfkit)
│   │   ├── file.upload.ts     ← Multer config + Azure Blob upload
│   │   └── otp.ts             ← OTP generate + hash
│   └── types/
│       └── express.d.ts       ← Extend req with user, instituteId
├── prisma/
│   ├── schema.prisma           ← Full schema (all tables above)
│   └── migrations/
├── uploads/                   ← Local file storage (gitignored)
│   ├── photos/
│   ├── notes/
│   └── receipts/
├── tests/
│   ├── auth.test.ts
│   ├── fee.test.ts
│   └── attendance.test.ts
├── docker-compose.yml          ← postgres + redis + app
├── Dockerfile
├── nginx/
│   └── nginx.conf
├── .github/
│   └── workflows/
│       └── deploy.yml
└── .env.example
```

---

## API ROUTES (Complete List)

### Auth `/api/auth`
```
POST   /otp/send              → send WhatsApp OTP (public)
POST   /otp/verify            → verify OTP → tokens (public)
POST   /login                 → phone + password → tokens (public)
POST   /refresh               → new access token (refresh cookie)
POST   /logout                → revoke refresh token (JWT)
GET    /me                    → current user (JWT)
POST   /password/change       → change password (JWT)
POST   /password/reset        → OTP-based reset (public)
POST   /sessions/revoke       → force logout user (admin)
```

### Students `/api/students`
```
GET    /                      → list (search, filter, paginate) [admin]
POST   /                      → create student + user account [admin]
GET    /:id                   → full profile [admin,teacher]
PUT    /:id                   → edit info [admin]
PATCH  /:id/status            → activate/deactivate [admin]
GET    /:id/attendance        → calendar + % [admin,teacher,parent,student]
GET    /:id/fees              → fee history [admin,parent,student]
GET    /:id/results           → exam + quiz history [admin,teacher,parent,student]
GET    /:id/performance       → analytics summary [all roles]
POST   /:id/id-card           → generate ID card PDF [admin]
GET    /me                    → own profile [student]
```

### Teachers `/api/teachers`
```
GET    /                      → list [admin]
POST   /                      → create [admin]
GET    /:id                   → profile [admin]
PUT    /:id                   → edit [admin]
PATCH  /:id/status            → activate/deactivate [admin]
GET    /me/batches            → my batches [teacher]
GET    /me/timetable          → my weekly schedule [teacher]
```

### Batches `/api/batches`
```
GET    /                      → list (filter by subject, teacher) [admin,teacher]
POST   /                      → create [admin]
GET    /:id                   → detail + student list [admin,teacher]
PUT    /:id                   → edit [admin]
PATCH  /:id/status            → activate/deactivate [admin]
POST   /:id/students          → add students to batch [admin]
DELETE /:id/students/:studentId → remove from batch [admin]
```

### Fees `/api/fees`
```
GET    /                      → list (filter by month, status, batch) [admin]
POST   /structure             → set fee structure for batch [admin]
POST   /records/generate      → bulk create monthly records [admin]
POST   /records/:id/pay       → collect payment [admin]
GET    /records/:id/receipt   → PDF receipt [admin,parent,student]
GET    /report                → monthly collection summary [admin]
GET    /outstanding           → all students with pending amount [admin]
POST   /reminders/bulk        → WhatsApp to all pending students [admin]
GET    /me                    → my fee history [student,parent]
POST   /online/initiate       → create Razorpay order [parent,student]
POST   /online/verify         → verify payment callback [parent,student]
```

### Attendance `/api/attendance`
```
POST   /sessions              → mark + submit session [teacher,admin]
GET    /sessions/:batchId/:date → view session [admin,teacher]
PUT    /sessions/:id/correct  → correction with audit log [admin]
GET    /report/batch/:batchId → all students monthly % [admin,teacher]
GET    /report/student/:id    → calendar heatmap [all roles]
GET    /report/low            → below 75% list [admin,teacher]
POST   /absent-alerts         → WhatsApp to absent parents [admin,teacher]
POST   /holidays              → mark holiday [admin]
```

### Exams `/api/exams`
```
GET    /                      → list [admin,teacher,student]
POST   /                      → create [admin,teacher]
PUT    /:id                   → edit [admin,teacher]
POST   /:id/results           → bulk enter marks [admin,teacher]
GET    /:id/results           → result sheet [admin,teacher]
GET    /:id/report            → batch performance report [admin,teacher]
POST   /:id/publish           → notify students via WhatsApp [admin,teacher]
```

### Quizzes `/api/quizzes`
```
GET    /                      → list [teacher,student]
POST   /                      → create [teacher]
PUT    /:id                   → edit (if not yet taken) [teacher]
POST   /:id/publish           → make visible to students [teacher]
POST   /:id/attempt/start     → start quiz [student]
POST   /:id/attempt/submit    → submit answers [student]
GET    /:id/result            → my result [student]
GET    /:id/leaderboard       → batch leaderboard [all]
GET    /:id/report            → full report [admin,teacher]
```

### Content `/api/content`
```
GET    /notes/:batchId        → list notes [student,teacher]
POST   /notes                 → upload note (multipart) [teacher]
DELETE /notes/:id             → delete [teacher,admin]
GET    /assignments/:batchId  → list assignments [student,teacher]
POST   /assignments           → upload assignment (multipart) [teacher]
DELETE /assignments/:id       → delete [teacher,admin]
```

### Lectures `/api/lectures`
```
GET    /batch/:batchId        → list lectures [student,teacher,admin]
POST   /                      → add lecture (YouTube URL) [teacher,admin]
PUT    /:id                   → edit [teacher,admin]
DELETE /:id                   → delete [teacher,admin]
```

### Doubts `/api/doubts`
```
GET    /                      → inbox (teacher: pending / student: mine) [teacher,student]
POST   /                      → ask doubt [student]
PUT    /:id/answer            → submit answer [teacher]
PATCH  /:id/resolve           → mark resolved [teacher,admin]
```

### Chat `/api/chat` (REST) + WebSocket
```
GET    /batch/:batchId/history    → last 50 messages [student,teacher]
DELETE /message/:id              → delete message [admin,teacher]

# WebSocket events (Socket.IO)
# Client → Server
join_batch     { batchId, token }
send_message   { batchId, message, imageUrl? }
typing         { batchId }

# Server → Client  
new_message    { id, senderId, senderName, message, imageUrl, createdAt }
user_typing    { userName }
message_deleted { id }
```

### Announcements `/api/announcements`
```
GET    /                      → list (paginated) [all roles]
POST   /                      → create + send [admin]
PUT    /:id                   → edit (only if not yet sent) [admin]
DELETE /:id                   → delete [admin]
```

### Analytics `/api/analytics`
```
GET    /dashboard             → admin dashboard stats [admin]
GET    /student/:id           → student performance summary [admin,teacher,parent,student]
GET    /batch/:id             → batch performance [admin,teacher]
GET    /revenue               → fee collection report [admin]
GET    /attendance/overview   → institute-wide attendance today [admin]
```

### Institute `/api/institute`
```
GET    /                      → settings [admin]
PUT    /                      → update name, logo, settings [admin]
PUT    /branding              → update colors, app display name [admin]
GET    /users                 → all user accounts [admin]
POST   /users                 → create user manually [admin]
PATCH  /users/:id/status      → activate/deactivate [admin]
POST   /users/:id/reset-password → trigger OTP reset [admin]
```

---

## BACKGROUND JOBS (BullMQ + Redis)

```typescript
// All jobs are defined in /src/jobs/

// Runs daily at 9:00 AM
FeeReminder7DJob     → find fees due in 7 days → send WhatsApp to parent
FeeReminder1DJob     → find fees due tomorrow → send WhatsApp
FeeDueTodayJob       → find fees due today → send urgent WhatsApp

// Runs daily at midnight
FeeMarkOverdueJob    → update all past-due unpaid records to 'overdue'

// Event-driven (triggered from API)
AbsentAlertJob       → on attendance submit → WhatsApp to absent parents
ExamReminderJob      → on exam create → scheduled WhatsApp 24h before
LiveClassReminderJob → on lecture create → scheduled WhatsApp 15min before
ReceiptGenerateJob   → on payment → generate PDF → save → WhatsApp link to parent

// Runs 1st of every month at 6:00 AM
MonthlyFeeCreateJob  → bulk create fee records for all active students

// Runs daily at 2:00 AM
DbBackupJob          → pg_dump → gzip → upload to Azure Blob cold storage

// Runs every 6 hours
AnalyticsRefreshJob  → rebuild cached dashboard stats in Redis
```

---

## SECURITY IMPLEMENTATION

### Every API follows this exact middleware chain:

```typescript
router.post('/fees/records/:id/pay',
  authenticateJWT,           // 1. Verify JWT, attach req.user
  tenantMiddleware,          // 2. Attach req.instituteId from token
  requireRole('admin'),      // 3. Check role
  validate(payFeeSchema),    // 4. Zod validation on req.body
  rateLimiter('50/1min'),    // 5. Rate limit
  feeController.collectPayment  // 6. Business logic
);
```

### Input Validation (Zod — every request body)

```typescript
// src/modules/fee/fee.validator.ts
export const collectPaymentSchema = z.object({
  amount_paid: z.number().positive().max(1000000),
  payment_mode: z.enum(['cash','upi','card','bank','cheque','online']),
  transaction_id: z.string().max(200).optional(),
  note: z.string().max(500).optional(),
  paid_at: z.string().datetime().optional()
});
```

### Rate Limits

```
POST /auth/otp/send        → 5 per hour per phone
POST /auth/login           → 10 per 15 minutes per IP
File upload endpoints      → 20 per minute per user
General API                → 200 per minute per user
WhatsApp send              → 60 per minute per institute (provider limit)
```

### Institute Isolation — NEVER SKIP THIS

```typescript
// src/middleware/tenant.middleware.ts
export const tenantMiddleware = async (req, res, next) => {
  const instituteId = req.user.instituteId;
  
  // Verify the requested resource belongs to this institute
  if (req.params.studentId) {
    const student = await prisma.student.findFirst({
      where: { id: req.params.studentId, institute_id: instituteId }
    });
    if (!student) return res.status(404).json({ success: false, error: 'Not found' });
  }
  
  req.instituteId = instituteId;
  next();
};
```

---

## STANDARD RESPONSE FORMAT

Every single API response — success or error — uses this format:

```typescript
// Success
{
  "success": true,
  "data": { ... },
  "message": "Payment collected successfully",
  "meta": {                    // only for paginated responses
    "page": 1,
    "perPage": 20,
    "total": 150,
    "totalPages": 8
  }
}

// Error
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",    // machine-readable
    "message": "Amount must be greater than 0",  // human-readable
    "fields": {                    // only for validation errors
      "amount_paid": "Must be positive"
    }
  }
}
```

---

## DOCKER SETUP (Single VPS — Everything in One Compose)

```yaml
# docker-compose.yml
version: '3.9'

services:
  app:
    build: .
    restart: always
    env_file: .env
    ports:
      - "3000:3000"
    volumes:
      - ./uploads:/app/uploads
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_DB: coachpro
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --requirepass ${REDIS_PASS}
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

```dockerfile
# Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

---

## NGINX CONFIG

```nginx
# nginx/nginx.conf
server {
    listen 80;
    server_name api.neurovax.tech;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name api.neurovax.tech;

    ssl_certificate     /etc/letsencrypt/live/neurovax.tech/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/neurovax.tech/privkey.pem;

    # File upload limit
    client_max_body_size 25M;

    # API proxy
    location /api/ {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }

    # Serve uploaded files directly
    location /uploads/ {
        alias /app/uploads/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
    limit_req zone=api burst=20 nodelay;
}
```

---

## ENVIRONMENT VARIABLES (.env.example)

```bash
# App
NODE_ENV=production
PORT=3000
APP_NAME=CoachPro
APP_URL=https://api.neurovax.tech

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/coachpro
DB_USER=coachpro
DB_PASS=<strong-random-password>

# Redis
REDIS_URL=redis://:password@localhost:6379
REDIS_PASS=<strong-random-password>

# JWT
JWT_SECRET=<512-bit-random-hex>
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=30d

# WhatsApp (Twilio)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=<token>
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886

# WhatsApp (MSG91 alternative)
MSG91_AUTH_KEY=<key>
MSG91_SENDER_ID=NVRAX
MSG91_WHATSAPP_URL=https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/

# File Storage
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE_MB=20
# Azure Blob (optional — for backup and overflow)
AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;...
AZURE_BLOB_CONTAINER=coachpro-uploads

# Email (Mailgun — GitHub Pack)
MAILGUN_API_KEY=<key>
MAILGUN_DOMAIN=mg.neurovax.tech
MAIL_FROM=noreply@neurovax.tech

# Payments (Razorpay — Phase 2)
RAZORPAY_KEY_ID=rzp_live_...
RAZORPAY_KEY_SECRET=<secret>

# Monitoring
SENTRY_DSN=https://...@sentry.io/...

# OTP
OTP_EXPIRY_MINUTES=10
OTP_MAX_ATTEMPTS=3
```

---

## GITHUB ACTIONS CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run lint
      - run: npm test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to DigitalOcean VPS
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.DO_HOST }}
          username: deploy
          key: ${{ secrets.DO_SSH_KEY }}
          script: |
            cd /app/coachpro-backend
            git pull origin main
            docker-compose build app
            docker-compose up -d --no-deps app
            docker-compose exec app npx prisma migrate deploy
            echo "Deploy complete at $(date)"
```

---

## FLUTTER APP — WHAT TO CHANGE

### Remove all Firebase packages from pubspec.yaml

```yaml
# DELETE THESE ENTIRELY
# firebase_core: ^2.x.x
# firebase_auth: ^4.x.x
# cloud_firestore: ^4.x.x
# firebase_storage: ^11.x.x
# firebase_messaging: ^14.x.x
# firebase_analytics: ^10.x.x
```

### Add these instead

```yaml
dependencies:
  dio: ^5.4.0                    # HTTP client with interceptors
  flutter_secure_storage: ^9.0.0 # store refresh token
  jwt_decoder: ^2.0.1            # decode JWT on client
  socket_io_client: ^2.0.3       # batch chat
  cached_network_image: ^3.3.1   # photos and thumbnails
  youtube_player_flutter: ^9.0.1 # play YouTube lectures in-app
  pdf: ^3.10.7                   # NOT needed — receipts generated by backend
```

### API Service Pattern (Dio with interceptors)

```dart
// lib/core/api/api_client.dart
class ApiClient {
  static const baseUrl = 'https://api.neurovax.tech/api';
  
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));

  ApiClient() {
    // Attach JWT to every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthService.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // On 401 — silently refresh token and retry
        if (error.response?.statusCode == 401) {
          final newToken = await AuthService.refreshToken();
          if (newToken != null) {
            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final retry = await _dio.request(
              error.requestOptions.path,
              options: Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers,
              ),
            );
            return handler.resolve(retry);
          }
          // Refresh failed → force logout
          AuthService.logout();
        }
        handler.next(error);
      },
    ));
  }
}
```

### Replace FirebaseAuth calls

```dart
// OLD (Firebase)
await FirebaseAuth.instance.signInWithPhoneNumber(phone);
await FirebaseAuth.instance.currentUser?.getIdToken();

// NEW (Our backend)
await ApiClient.post('/auth/otp/send', { 'phone': phone });
await ApiClient.post('/auth/otp/verify', { 'phone': phone, 'otp': otp });
// Returns { accessToken, refreshToken } — store refresh token securely
```

### Replace Firestore calls

```dart
// OLD (Firebase)
await FirebaseFirestore.instance.collection('students').get();

// NEW (Our backend)
await ApiClient.get('/students?batch_id=$batchId&page=1');
```

### Replace Firebase Storage

```dart
// OLD
await FirebaseStorage.instance.ref('photos/$studentId').putFile(file);

// NEW
final formData = FormData.fromMap({
  'file': await MultipartFile.fromFile(file.path, filename: 'photo.jpg'),
});
await ApiClient.post('/students/$studentId/photo', data: formData);
```

### YouTube Lecture Player

```dart
// lib/features/lecture/lecture_player_screen.dart
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class LecturePlayerScreen extends StatelessWidget {
  final String youtubeUrl;

  String get videoId => YoutubePlayer.convertUrlToId(youtubeUrl)!;

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: true),
        ),
      ),
      builder: (context, player) => Scaffold(
        body: Column(children: [player]),
      ),
    );
  }
}
```

---

## BUILD ORDER (Step by Step)

Follow this exact order. Do not skip steps. Each step must work before moving to the next.

### Phase 1 — Server Setup
- [ ] **Step 01:** Provision DigitalOcean Droplet (Ubuntu 24.04, 2GB RAM). Install Docker, Docker Compose, NGINX, Certbot.
- [ ] **Step 02:** Clone repo, create `.env` from `.env.example`, fill all values.
- [ ] **Step 03:** `docker-compose up -d postgres redis` → verify connections.
- [ ] **Step 04:** Init Prisma schema with all tables above. Run `prisma migrate dev`. Seed one demo institute + admin user.

### Phase 2 — Core Backend
- [ ] **Step 05:** Build Express app structure — app.ts, server.ts, all middleware, response utils.
- [ ] **Step 06:** Build `auth` module — OTP send/verify, JWT issue, refresh, logout.
- [ ] **Step 07:** Build `institute` module — settings CRUD, user management.
- [ ] **Step 08:** Build `teacher` module — CRUD, batch assignment.
- [ ] **Step 09:** Build `student` module — CRUD, batch enrollment, 360 profile.
- [ ] **Step 10:** Build `batch` module — CRUD, student add/remove, timetable.

### Phase 3 — Operations
- [ ] **Step 11:** Build `fee` module — structure, records, payments, receipt PDF, reminders.
- [ ] **Step 12:** Build `attendance` module — mark, submit, reports, correction, holiday.
- [ ] **Step 13:** Build `exam` module — create, results, grades, report.
- [ ] **Step 14:** Build `announcement` module — create, target, send via WhatsApp.

### Phase 4 — Learning
- [ ] **Step 15:** Build `content` module — note/assignment upload (Multer → local disk → Azure Blob).
- [ ] **Step 16:** Build `quiz` module — builder, publish, take, submit, leaderboard.
- [ ] **Step 17:** Build `lecture` module — YouTube URL store, schedule, list by batch.
- [ ] **Step 18:** Build `doubt` module — ask, assign, answer, resolve.
- [ ] **Step 19:** Build `chat` module — Socket.IO rooms per batch, history REST.

### Phase 5 — Intelligence
- [ ] **Step 20:** Build `whatsapp` module — all message types, templates, queue integration.
- [ ] **Step 21:** Build `analytics` module — dashboard stats, student performance, revenue.
- [ ] **Step 22:** Build all BullMQ jobs (fee reminders, absent alerts, monthly fee create, backup).

### Phase 6 — Flutter Migration
- [ ] **Step 23:** Remove all Firebase packages from pubspec.yaml. Run `flutter pub get`.
- [ ] **Step 24:** Build `ApiClient` (Dio + JWT interceptor + auto-refresh).
- [ ] **Step 25:** Migrate auth screens (OTP login replacing Firebase phone auth).
- [ ] **Step 26:** Migrate all admin screens to hit new REST APIs.
- [ ] **Step 27:** Migrate teacher, student, parent screens.
- [ ] **Step 28:** Replace Firestore listeners with Dio GET + pull-to-refresh.
- [ ] **Step 29:** Add YouTube player for lectures.
- [ ] **Step 30:** Test all 4 roles end-to-end on staging.

### Phase 7 — DevOps & Launch
- [ ] **Step 31:** Configure NGINX with SSL (Certbot). Verify HTTPS.
- [ ] **Step 32:** Set up GitHub Actions deploy pipeline.
- [ ] **Step 33:** Configure Sentry on both backend and Flutter app.
- [ ] **Step 34:** Load test with 50 concurrent users (Artillery or k6).
- [ ] **Step 35:** Go live. Point client domain to server IP.

---

## MASTER AGENT PROMPT (Paste this into Copilot / Cursor / Claude)

```
You are a senior backend engineer building CoachPro — a multi-tenant coaching institute 
management SaaS by neurovaX.

STACK: Node.js 20, TypeScript, Express, Prisma ORM, PostgreSQL, Redis, BullMQ, 
Socket.IO, Multer (file uploads), pdfkit (receipts).

ARCHITECTURE: Single VPS. Monolith structured as modules 
(/src/modules/auth, /fee, /student, etc). Not microservices — one process.

MULTI-TENANCY: Every table has institute_id. Every query filters by institute_id.
The tenant middleware (already built) attaches req.instituteId from JWT. 
Always use it. Never query without institute_id filter.

AUTHENTICATION:
- JWT access token (15min) + refresh token (30 days, stored hashed in DB)  
- JWT payload: { userId, role, instituteId, phone }
- Roles: admin | teacher | student | parent

RESPONSE FORMAT — always return this exact structure:
Success: { success: true, data: {...}, message: "...", meta: {...} }
Error:   { success: false, error: { code: "...", message: "..." } }

WHATSAPP: All notifications go via WhatsApp (Twilio API). we want push notifications through firebase.
No SMS fallback unless WhatsApp fails.

VIDEOS: All lectures use YouTube URLs. We do NOT host videos.

SECURITY RULES:
- Zod validation on every request body (use validate middleware wrapper)
- Parameterized queries only via Prisma — never raw SQL string concat
- Role check on every route
- Rate limiting via middleware
- Log every action to audit_logs table

CURRENT TASK: [build complete]

Generate: Complete production-ready TypeScript code. Full error handling. 
No placeholders. No TODOs. Include the route file, controller, service, 
repository, and validator. Add a Jest test file covering the main flows.
```

---


---

*neurovaX | www.neurovax.tech | neurova.business@gmail.com*