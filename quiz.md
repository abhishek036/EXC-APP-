# CoachPro Core Engagement Blueprint

This document defines production-grade architecture for the two retention engines:
- Classes (live + recorded)
- Doubts (threaded, timestamp-aware)

Stack assumptions:
- Flutter app
- Node.js + Express + Socket.io backend
- PostgreSQL via Prisma
- YouTube for recorded/live stream distribution
- Cloud storage for attachments

Current codebase reality (already present):
- `Lecture`, `LectureProgress`, `Doubt`, `ChatMessage` models
- Lecture and Doubt modules with REST routes
- Socket rooms by batch and institute

Target: evolve existing modules into premium-level behavior without breaking current clients.

---

# Part 1: Classes System (Live + Recorded)

## 1) Role capabilities

Student:
- Join live session using secure join token
- Watch recorded videos
- Ask doubts from class page and video timestamp
- Auto attendance and watch progress tracking

Teacher:
- Schedule classes by batch/subject
- Start/end live session
- Link/upload recorded videos
- Track attendance, watch completion, and engagement

Admin:
- Monitor all classes across institute
- Configure teacher assignment and access controls
- Override/close sessions
- Analytics for attendance, completion, and drop-off

---

## 2) Domain model (production)

Keep existing `lectures` as canonical class row, and add operational tables:

Core tables:
- `Class` (map to existing `lectures`)
- `ClassSession` (one or many live runs for a class)
- `Attendance` (join/leave heartbeat and final attendance)
- `VideoProgress` (map/extend existing `lecture_progress`)

Recommended schema extensions:

`classes` (`lectures` extension):
- `id` UUID
- `institute_id`, `batch_id`, `teacher_id`
- `title`, `subject`, `description`
- `class_type` enum: `live`, `recorded`, `hybrid`
- `scheduled_at`, `duration_minutes`
- `access_rule` enum: `free`, `paid`
- `is_recording_enabled` boolean
- `is_chat_enabled` boolean
- `youtube_video_id` nullable
- `youtube_privacy` enum: `private`, `unlisted`
- `status` enum: `scheduled`, `live`, `ended`, `cancelled`

`class_sessions`:
- `id` UUID
- `class_id` FK
- `institute_id`, `batch_id`
- `session_type` enum: `live`, `replay`
- `provider` enum: `youtube_live`, `custom_rtmp`, `zoom_bridge`
- `join_token_version` int
- `started_at`, `ended_at`
- `peak_concurrency` int
- `chat_replay_available` boolean
- `recording_video_id` nullable

`class_attendance`:
- `id` UUID
- `session_id` FK
- `class_id` FK
- `student_id` FK
- `first_join_at`, `last_leave_at`
- `total_watch_seconds`
- `heartbeat_count`
- `is_late_join` boolean
- `attendance_status` enum: `present`, `partial`, `absent`

`video_progress` (extend existing `lecture_progress`):
- `id` UUID
- `class_id` FK
- `student_id` FK
- `watched_seconds`
- `total_seconds`
- `completion_percent` numeric(5,2)
- `last_position_seconds`
- `last_watched_at`
- unique `(student_id, class_id)`

`class_access_tokens` (optional but strong security):
- `id` UUID
- `class_id`, `session_id`, `student_id`
- `token_hash`
- `expires_at`
- `device_fingerprint`
- `is_revoked`

---

## 3) API contracts (REST)

Teacher/Admin class management:
- `POST /api/classes`
- `GET /api/classes?batchId=&subject=&type=&status=`
- `GET /api/classes/:id`
- `PATCH /api/classes/:id`
- `DELETE /api/classes/:id` (soft delete)

Live operations:
- `POST /api/classes/:id/live/start`
- `POST /api/classes/:id/live/end`
- `GET /api/classes/:id/live/state`

Access and join:
- `POST /api/classes/:id/join-token` (student/teacher)
- `POST /api/classes/:id/join` (register session join)
- `POST /api/classes/:id/heartbeat` (every 20-30 sec)
- `POST /api/classes/:id/leave`

Recorded playback:
- `POST /api/classes/:id/progress` (debounced)
- `GET /api/classes/:id/progress/me`
- `POST /api/classes/:id/mark-complete`

Analytics:
- `GET /api/classes/analytics/student/me`
- `GET /api/classes/analytics/teacher/me`
- `GET /api/classes/analytics/admin`

---

## 4) Socket.io event contract

Namespace: default or `/classes`
Rooms:
- `batch_<batchId>`
- `class_<classId>`
- `session_<sessionId>`

Events emitted by server:
- `class_live_started`
- `class_live_ended`
- `class_participant_count`
- `class_chat_message`
- `class_doubt_raised`
- `class_hand_raised`

Events from client:
- `join_class_room`
- `leave_class_room`
- `send_class_chat`
- `raise_hand`
- `raise_doubt_live`

Reliability rules:
- ACK required for `send_class_chat` and `raise_doubt_live`
- Sequence id in payload for replay-safe UI updates
- Server timestamps authoritative

---

## 5) YouTube integration (recorded + live)

Recorded flow:
1. Teacher uploads video to YouTube as `unlisted` or `private`
2. Backend stores `youtube_video_id` and metadata
3. Student player requests signed class access first
4. App embeds player only if access is valid

Live flow:
1. Teacher schedules class
2. Backend creates YouTube live broadcast/stream (already partially supported)
3. Start event notifies batch
4. End event closes session and stores recording id

Hardening:
- Never expose raw unrestricted links in list APIs
- Gate playback behind class access check
- Rotate temporary join tokens every session start

---

## 6) Attendance and engagement policy

Attendance marking rules:
- `present`: watch >= max(20 min, 60% of duration)
- `partial`: watch >= 5 min but below present threshold
- `absent`: otherwise

Late join:
- `is_late_join=true` if first join > 10 min after start

Engagement score (teacher/admin dashboards):
- `score = 0.5 * attendance_rate + 0.3 * avg_completion + 0.2 * interaction_rate`

Drop-off rate per class:
- `dropoff = 1 - (students_reaching_70_percent / students_joined)`

---

## 7) Security model for classes

Access control:
- Must be enrolled in batch
- Must satisfy payment gate for `paid` class
- JWT + tenant validation mandatory

Tokenized join:
- Join token TTL: 3-5 minutes
- Token includes class_id, session_id, user_id, role, device hash
- Revoke on suspicious parallel joins

Link-sharing prevention:
- Signed URLs + short expiry
- Optional watermark overlay with student name + id in player
- Concurrent session cap per student

Abuse controls:
- Rate limit join attempts
- Rate limit chat events
- Audit table for denied access attempts

---

## 8) Edge case handling matrix (classes)

Student joins late:
- Mark `is_late_join`, still track watch-time and attendance status

Network drop:
- Heartbeat timeout closes provisional segment
- Rejoin merges attendance windows

Multiple logins:
- Keep latest token valid, revoke older token
- Optional warning toast and security log entry

Unauthorized access:
- Return 403 with reason code: `NOT_ENROLLED`, `PAYMENT_REQUIRED`, `TOKEN_EXPIRED`

Teacher ends session unexpectedly:
- Auto-close attendance windows
- Emit `class_live_ended` with reason

---

## 9) Flutter app behavior

Student:
- Class list with status chips (`scheduled`, `live`, `recorded`)
- Live card CTA: `Join Now`
- Recorded card CTA: `Watch`
- Progress bar + resume position + completion badge
- Timestamped doubt button in player

Teacher:
- Schedule form with advanced switches
- Start/End live controls
- Real-time participant and chat panel
- Engagement summary cards

Admin:
- Institute class monitor dashboard
- Failed session and low-attendance alerts
- Filter by teacher, batch, subject, date

---

# Part 2: Doubt System (High retention)

## 1) Entry points

1. After-class popup:
- Trigger prompt after live end or recorded completion milestone

2. During video:
- `Ask Doubt` with optional timestamp and playback context

3. Dedicated doubt center:
- Subject/class filters, thread status, SLA indicators

4. During live chat:
- Convert chat line to formal doubt with one tap

---

## 2) Domain model (production)

Requested core:
- `Doubt`
- `DoubtMessage`
- `DoubtAttachment`

Recommended extensions:
- `DoubtStatusHistory`
- `DoubtAssignment`
- `DoubtUpvote` (advanced/public mode)

`doubts` (extend existing):
- `id` UUID
- `institute_id`, `batch_id`, `student_id`
- `class_id` nullable
- `video_timestamp_sec` nullable
- `subject`, `topic_tag`
- `title` optional, `question_text`
- `status` enum: `pending`, `in_progress`, `answered`, `resolved`
- `priority` enum: `low`, `normal`, `high`
- `assigned_teacher_id` nullable
- `is_pinned` boolean
- `is_spam` boolean
- `created_at`, `first_response_at`, `resolved_at`

`doubt_messages`:
- `id` UUID
- `doubt_id` FK
- `sender_user_id` FK
- `sender_role`
- `message_type` enum: `text`, `audio`, `video`, `system`
- `message_text` nullable
- `created_at`

`doubt_attachments`:
- `id` UUID
- `doubt_id` FK
- `message_id` nullable
- `file_url` (signed/private access)
- `file_type`, `mime_type`, `size_kb`
- `storage_provider`, `storage_path`
- `created_at`

---

## 3) Doubt lifecycle flow

Flow:
1. Student creates doubt
2. Backend validates enrollment + rate limit + file checks
3. Doubt stored with `pending`
4. Teacher notified (push + socket)
5. Teacher replies and status moves to `in_progress` or `answered`
6. Student follow-up allowed as thread messages
7. Student or teacher marks `resolved`

Auto transitions:
- First teacher reply sets `first_response_at`
- `answered` without student follow-up for 48h can auto-suggest `resolved`

---

## 4) API contracts (doubt)

Student actions:
- `POST /api/doubts`
- `GET /api/doubts?status=&subject=&classId=&mine=true`
- `GET /api/doubts/:id`
- `POST /api/doubts/:id/messages`
- `POST /api/doubts/:id/resolve`

Teacher actions:
- `GET /api/doubts?assignedTo=me&status=`
- `POST /api/doubts/:id/assign`
- `PATCH /api/doubts/:id/status`
- `POST /api/doubts/:id/messages`
- `POST /api/doubts/:id/pin`

Admin actions:
- `GET /api/doubts/admin/analytics`
- `PATCH /api/doubts/:id/spam`
- `PATCH /api/doubts/:id/reassign`

Attachments:
- `POST /api/doubts/attachments/upload`
- `GET /api/doubts/attachments/:id/access`

---

## 5) Doubt thread behavior

Thread rules:
- Chronological messages, immutable history
- Support text/audio/video replies
- System messages for status changes and assignments

Follow-up handling:
- Student follow-up moves status back to `in_progress`
- SLA timer restarts for teacher response

Pinning:
- Teacher/admin can pin valuable doubts for batch knowledge base

---

## 6) Notifications and socket events

Push notifications:
- New doubt -> assigned teacher(s)
- New teacher reply -> doubt creator student
- Status changed -> involved participants

Socket events:
- `doubt_created`
- `doubt_assigned`
- `doubt_message_added`
- `doubt_status_changed`
- `doubt_resolved`

Room model:
- `doubt_<doubtId>` for thread realtime
- `teacher_<teacherId>` for assignment feed
- `batch_<batchId>` for general updates

---

## 7) Security and anti-spam (doubt)

Auth and enrollment:
- Only active enrolled students can create doubts
- Cross-tenant access blocked by institute scope

Rate limiting:
- Example: max 8 doubts/hour/student
- Max 20 messages/10 min per doubt thread

Duplicate detection:
- Normalize and hash question text
- Similarity check in recent window (same subject/class)
- Prompt user with possible duplicate threads

Attachment validation:
- Allow list mime types
- Virus scan status for files
- Size limits and signed access URLs only

Moderation:
- Spam flagging and admin review queue
- Abuse audit trail per user

---

## 8) Analytics KPIs (doubt)

Student metrics:
- doubts_asked
- avg_first_response_time
- resolution_rate

Teacher metrics:
- assigned_count
- avg_first_response_time
- avg_resolution_time
- unanswered_over_sla

Admin metrics:
- most_common_subjects
- most_common_topics
- slow_teachers leaderboard
- spam_rate

Definitions:
- first response time = `first_response_at - created_at`
- resolution time = `resolved_at - created_at`

---

## 9) Classes + Doubts integration (retention loop)

After class end:
- Trigger `Any doubts?` quick sheet
- Pre-fill class and subject context

During video:
- Capture current timestamp
- Create doubt linked to class and timestamp

Teacher view:
- Doubted moments heatmap on timeline
- Frequently doubted timestamps indicate unclear teaching segments

Admin view:
- Correlate low completion and high doubt volume by class/teacher

---

## 10) Migration plan from current modules

Current status:
- `lectures`, `lecture_progress`, `doubts` exist
- Basic lecture CRUD and doubt answer/resolve exist
- Socket rooms exist for batch messaging

Upgrade steps:

Phase A (safe schema additions):
- Add class status/access/chat/recording columns
- Add `class_sessions`, `class_attendance`
- Add `doubt_messages`, `doubt_attachments`
- Keep old endpoints working

Phase B (API expansion):
- Add join token, attendance heartbeat, progress APIs
- Add threaded doubt message APIs
- Add analytics endpoints

Phase C (client rollout):
- Flutter class player with progress + timestamp doubt
- Doubt thread UI with realtime updates
- Feature flags for staged rollout

Phase D (hardening):
- Rate limits
- audit logs
- SLA alerts and escalation jobs

---

## 11) Implementation sprint plan (6 sprints)

Sprint 1:
- Schema migrations + Prisma models
- Backward compatibility adapters

Sprint 2:
- Class access token + live session APIs
- Attendance heartbeat pipeline

Sprint 3:
- Recorded playback progress sync
- Student/teacher class analytics endpoints

Sprint 4:
- Doubt thread APIs + attachments + status history
- Notification wiring (push + socket)

Sprint 5:
- Flutter UI rollout for class player and doubt thread
- Moderation and anti-spam controls

Sprint 6:
- SLA automation jobs, dashboards, load testing, release hardening

---

## 12) Non-functional requirements

Performance:
- P95 API latency < 300 ms for list endpoints
- Socket event delivery < 1.5 sec median

Reliability:
- Idempotent join/leave/progress endpoints
- Event retry for critical notifications

Scalability:
- Horizontal backend pods
- Redis adapter for Socket.io when scaling instances

Observability:
- Trace id per request
- Structured logs for class and doubt events
- Alerts for failed session starts and SLA breaches

---

## 13) Acceptance criteria (production readiness)

Classes:
- Student can join live only with valid token
- Attendance is correct under reconnect scenarios
- Progress resumes from last position for recorded videos
- Admin can see class-level drop-off and watch KPIs

Doubts:
- Student can create from all four entry points
- Thread supports multi-message conversation
- Teacher response updates status and notifies student in realtime
- Admin can detect spam and slow-response bottlenecks

Security:
- Cross-tenant access blocked in all endpoints
- Link sharing does not grant unauthorized class playback
- Rate limits and upload validations active

---

# Final recommendation

Treat Classes + Doubts as one unified engagement platform, not two isolated modules.
If you execute this blueprint with strict telemetry and realtime feedback loops, this becomes your retention moat.

