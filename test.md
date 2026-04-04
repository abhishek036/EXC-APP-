# 🎓 Educational App — Complex Scenarios & Feature Blueprint
### All Roles: Admin · Teacher · Student · Parent  
### Core Entities: Batch · Subject · Timetable · Attendance · Fee · Notification

> **Purpose:** This document maps every complex real-world situation that can arise in an educational platform, including edge cases that break naive implementations. Each scenario includes the expected behavior, the data model impact, and the UI/UX requirement.

---

## 📋 Table of Contents

1. [Batch–Subject–Teacher Relationship Matrix](#1-batchsubjectteacher-relationship-matrix)
2. [Teacher Scenarios (Complex)](#2-teacher-scenarios-complex)
3. [Student Scenarios (Complex)](#3-student-scenarios-complex)
4. [Admin Scenarios (Complex)](#4-admin-scenarios-complex)
5. [Parent Scenarios (Complex)](#5-parent-scenarios-complex)
6. [Attendance Scenarios (Complex)](#6-attendance-scenarios-complex)
7. [Timetable & Scheduling Conflicts](#7-timetable--scheduling-conflicts)
8. [Fee & Payment Scenarios](#8-fee--payment-scenarios)
9. [Notification & Communication Logic](#9-notification--communication-logic)
10. [Data Model Design (Recommended)](#10-data-model-design-recommended)
11. [API Endpoint Matrix](#11-api-endpoint-matrix)
12. [Testing Scenarios Checklist](#12-testing-scenarios-checklist)

---

## 1. Batch–Subject–Teacher Relationship Matrix

### 1.1 All Possible Relationship Combinations

| Scenario | Description | Real Example |
|----------|-------------|--------------|
| **1 Batch → 1 Subject → 1 Teacher** | Simplest case | Batch A has Math, taught by Teacher X |
| **1 Batch → 1 Subject → 2 Teachers** | Co-teaching / Theory+Lab split | Batch A has Physics: Mr. Kumar (Theory) + Ms. Rao (Lab Practical) |
| **1 Batch → Multiple Subjects → 1 Teacher** | Generalist teacher | Teacher X teaches Math + Science for Batch A (primary school) |
| **1 Teacher → Multiple Batches → Same Subject** | Shared teacher | Teacher X teaches Math to Batch A (morning) + Batch B (evening) |
| **1 Teacher → Multiple Batches → Different Subjects** | Expert across subjects | Teacher X teaches Math to Batch A and Physics to Batch B |
| **1 Subject → Multiple Batches → Different Teachers** | Subject taught differently | Math in Batch A by Teacher X, Math in Batch B by Teacher Y |
| **Guest/Visiting Lecturer** | One-time or limited sessions | Expert visits for 3 sessions only on a special topic |
| **Substitute Teacher (temporary)** | Covering for absent primary | Teacher Z covers Teacher X's sessions for 2 weeks |
| **Theory Teacher + Lab Teacher (same subject)** | Split by session type | Chemistry: Dr. Sharma (theory 3×/week) + Lab Instructor (practical 1×/week) |
| **Head Teacher + Assistant Teacher** | Hierarchical co-teaching | Senior teacher plans; junior teacher executes/monitors |

---

### 1.2 Relationship Rules (Business Logic)

```
Batch
  └── BatchSubject (junction — many subjects per batch)
        ├── SubjectTeacher (many teachers per BatchSubject)
        │     ├── role: PRIMARY / SUBSTITUTE / CO_TEACHER / LAB / GUEST
        │     ├── from_date, to_date (for substitute tenure)
        │     └── session_type: THEORY / PRACTICAL / BOTH
        └── Timetable slots
```

**Key Constraints:**
- A subject in a batch MUST have at least one PRIMARY teacher at all times
- Multiple teachers of same role is allowed for CO_TEACHING only
- SUBSTITUTE teacher overrides PRIMARY for attendance purposes during tenure
- A teacher can be PRIMARY in one batch and SUBSTITUTE in another simultaneously
- GUEST teacher has no attendance marking rights; admin marks for guest sessions

---

## 2. Teacher Scenarios (Complex)

### 2.1 Teacher Teaches Multiple Batches (Same Subject)

**Scenario:** Teacher X teaches Mathematics in Batch A (9 AM), Batch B (11 AM), and Batch C (3 PM).

**Requirements:**
- Teacher dashboard shows ALL their batches with a batch-switcher tab
- Attendance marking is batch-specific — marking in Batch A does NOT affect Batch B
- Announcements can be sent to: "All my batches" OR a specific batch
- Teacher can view comparative performance across their batches
- Salary/payout linked to sessions conducted per batch (if applicable)
- Teacher schedule must show all three time slots and auto-alert on conflicts

**Edge Cases:**
- What if Batch A and Batch C are rescheduled to same time? → Admin must be blocked from creating this conflict; or teacher sees a conflict warning
- Teacher is absent — substitute for which batch? Can be different substitutes per batch
- Teacher views "my students" — must see all students across all 3 batches (deduplicated if a student is in multiple)

---

### 2.2 Teacher Teaches Multiple Subjects (Same Batch)

**Scenario:** Teacher X teaches both Mathematics and Computer Science in Batch A.

**Requirements:**
- Teacher sees subject-specific attendance records (not combined)
- Notes, assignments, and announcements scoped per subject, not per batch
- When taking attendance: Teacher must select WHICH subject's session they are marking
- Report card shows teacher name against each subject separately
- If Teacher X is absent, each subject may have a different substitute

**Edge Cases:**
- Teacher marks attendance for Maths class, but accidentally for CS slot → undo/correction flow needed
- Teacher teaches Maths on Mon/Wed/Fri and CS on Tue/Thu → timetable must enforce this
- Teacher X is removed from one subject but stays in the other → partial subject reassignment flow

---

### 2.3 Two Teachers for One Subject (Co-Teaching / Theory+Lab)

**Scenario:** Chemistry in Batch A has Dr. Sharma (Theory, 4 days/week) and Mr. Patel (Practical Lab, 1 day/week).

**Requirements:**
- Both teachers can see the same student list for that subject
- Attendance is marked SEPARATELY per session type — theory attendance and lab attendance are distinct
- Student's overall subject attendance = weighted average (e.g., theory 70% weight, lab 30% weight) OR both must independently meet threshold (e.g., ≥75%)
- Each teacher can only upload notes/assignments for their session type
- Subject grade = theory component + practical component (combined by admin-defined formula)
- Notifications to students come from the correct teacher (Dr. Sharma for theory, Mr. Patel for lab)

**Edge Cases:**
- Mr. Patel (Lab) is absent for 2 weeks → Substitute only for Lab sessions, not theory
- Student is present for theory but absent for lab → Two separate attendance records
- Lab requires prerequisite — student who missed 3+ theory sessions cannot attend lab → auto-block or alert
- Dr. Sharma uploads an assignment → Students see it as "Chemistry (Theory) Assignment" not just "Chemistry Assignment"

---

### 2.4 Substitute Teacher (Temporary Replacement)

**Scenario:** Teacher X (primary, Math, Batch A) goes on medical leave for 3 weeks. Teacher Z is assigned as substitute.

**Requirements:**
- Admin assigns substitute with a `from_date` and `to_date`
- During substitute period: Teacher Z can mark attendance, upload notes, send announcements FOR THAT BATCH ONLY
- Teacher X retains their assignment but loses active access during the period
- All attendance and notes uploaded by Teacher Z are tagged as "substitute session" in records
- When Teacher X returns, they can see what was covered by substitute
- Substitute teacher's data (notes uploaded, attendance marked) is preserved even after substitute tenure ends
- Salary/payout: substitute teacher paid for sessions covered, primary teacher is NOT paid for those sessions (if applicable)

**Edge Cases:**
- Substitute is extended — admin must update `to_date`
- Teacher X returns early → admin marks return date; both Teacher X and Z see the batch briefly during transition
- What if Teacher X never returns? Substitute must be promoted to PRIMARY formally
- Substitute for only specific sessions (e.g., only Monday sessions) → Session-level granularity in substitute assignment

---

### 2.5 Guest / Visiting Lecturer

**Scenario:** A visiting expert takes 3 sessions on "Machine Learning" for Batch A's CS subject.

**Requirements:**
- Guest teacher has limited access: can only see enrolled students, mark attendance for their sessions
- No salary linkage (or a different one-time payment)
- Guest sessions appear in timetable marked as "Guest Lecture"
- Admin (not the primary CS teacher) creates and manages guest teacher access
- Guest teacher account auto-deactivates after their last scheduled session (or after `to_date`)
- Students see guest teacher's name + topic in their timetable ("Machine Learning — Prof. Guest")

---

### 2.6 Teacher Transfer Mid-Course

**Scenario:** Teacher X has been teaching Batch A's Physics for 3 months. Suddenly Teacher X is transferred to Batch B.

**Requirements:**
- Existing sessions, attendance records, and notes uploaded by Teacher X remain associated with Batch A
- New Teacher Y is assigned to Batch A's Physics from transfer date onwards
- Teacher Y can view all historical content from Teacher X for continuity
- Teacher X can no longer access Batch A
- Report to admin shows: "Physics, Batch A — Teacher X (01 Jan–15 Mar), Teacher Y (16 Mar onwards)"
- Attendance reports for the full academic year show the correct teacher for each date
- Students and parents are notified of teacher change

---

## 3. Student Scenarios (Complex)

### 3.1 Student Enrolled in Multiple Batches (Cross-Batch)

**Scenario:** Student Rahul is enrolled in Batch A for Mathematics and Physics, but attends Batch B for Chemistry (different schedule, better teacher preference).

**Requirements:**
- Student dashboard shows all their subjects across all batches in one unified view
- Attendance tracked per subject per batch independently
- Fee charged for each batch enrollment (pro-rated or per-subject)
- Timetable for student = merged timetable from all enrolled batches (with conflict detection)
- If Math (Batch A) and Chemistry (Batch B) clash at same time → student/admin alerted during enrollment
- Report card pulls grades from each subject's respective batch/teacher
- Notifications from all enrolled batches are received by the student

**Edge Cases:**
- Student is marked absent in Math (Batch A) but present in Chemistry (Batch B) at different times — both are valid and independent
- Student drops Chemistry from Batch B but stays in Batch A — partial unenrollment flow
- Batch B Chemistry has a different syllabus than Batch A Chemistry — subject must be differentiated by batch

---

### 3.2 Student Transfer Between Batches

**Scenario:** Student Priya transfers from Batch A to Batch B mid-semester (both batches run the same subjects).

**Requirements:**
- All attendance records in Batch A are preserved and linked to Priya's profile
- From transfer date, Priya's attendance is counted in Batch B
- Overall attendance report = Batch A attendance (before date) + Batch B attendance (after date)
- All Batch A notes/study material remain accessible to Priya after transfer
- Batch A teacher is notified: "Priya has been transferred out"
- Batch B teacher is notified: "Priya has been transferred in (joining mid-course)"
- Fee recalculation: Batch A fees pro-rated up to transfer date; Batch B fees from transfer date

**Edge Cases:**
- Priya had pending assignments in Batch A — what happens? Admin must explicitly mark as waived or transferred
- Batch A and Batch B are at different points in syllabus — Batch B teacher sees "transferred student: 3 chapters behind" flag
- Transfer happens during exam period — which batch's exam does Priya take?
- Student transfers but Batch B is already full (seat limit) → enrollment blocked, admin notified

---

### 3.3 Student Repeating a Subject (Failed / Remedial)

**Scenario:** Student Amit failed Physics in the previous batch. He is re-enrolled in the same subject in the new batch.

**Requirements:**
- Previous batch's records are preserved and marked as "historical"
- New enrollment creates fresh attendance, fresh assignment records for the new batch
- System flags Amit as "repeat student" for this subject — teacher is optionally notified
- Fee: Full fee again OR discounted re-enrollment fee (configurable by admin)
- Report card shows: current batch marks only for current report; historical report available separately
- If student passes remedial, both records coexist; final transcript shows both attempts

**Edge Cases:**
- Student repeats the same subject in the SAME batch (unusual but possible) → system must support this as a separate enrollment record with a new attempt number
- Student is a repeat student in Subject X but a new student in Subject Y within same batch

---

### 3.4 Student Makeup / Compensatory Classes

**Scenario:** Student was absent for 5 sessions of Mathematics in Batch A. Admin schedules makeup sessions from Batch B (which is 2 weeks behind).

**Requirements:**
- Student can attend Batch B's Math sessions as makeup attendance, credited to their Batch A record
- Batch B teacher sees the makeup student in their session (marked distinctly, e.g., "visiting for makeup")
- Makeup attendance is tagged differently in records (e.g., type: MAKEUP vs REGULAR)
- Attendance percentage calculation: whether makeup counts towards the ≥75% threshold is configurable
- Batch B teacher cannot see Batch A student's grades or full profile — only their name

**Edge Cases:**
- Student misses makeup session too — now doubly absent, no further makeup option (policy-driven)
- Makeup is in a different subject inadvertently — validation must block wrong-subject makeup credits
- Multiple students from Batch A attend Batch B for makeup on same day — Batch B teacher gets list in advance

---

### 3.5 Student Accessing Notes from a Subject They Dropped

**Scenario:** Student Neha enrolled in all 5 subjects, then dropped Economics in week 3. She still wants to access Economics notes.

**Requirements:**
- Upon drop, access to Economics resources (notes, assignments) is configurable: revoke OR maintain read-only
- Attendance tracking stops from drop date
- Fee credit/refund for dropped subject (if applicable)
- Neha's slot in the Economics timetable is freed
- Teacher of Economics no longer sees Neha in attendance sheets
- If Neha re-enrolls in Economics later, prior partial attendance records are shown to admin

---

## 4. Admin Scenarios (Complex)

### 4.1 Creating a Batch with Multiple Subjects and Teachers

**Full Flow:**
1. Admin creates Batch: "JEE 2026 — Batch A"
2. Admin adds subjects: Physics, Chemistry, Mathematics, Biology
3. For each subject, admin assigns:
   - Primary teacher
   - (Optional) Co-teacher / Lab teacher
   - (Optional) Substitute teacher with date range
4. Admin sets subject-level schedule within timetable builder
5. Admin sets fee structure: per batch OR per subject OR per student tier
6. Admin publishes batch → students can enroll

**Edge Cases:**
- Admin tries to assign Teacher X to two subjects in same time slot → conflict alert: "Teacher X already has Physics at 9 AM on Mon/Wed"
- Admin creates batch but forgets to assign a teacher for Chemistry → batch cannot be published (or published as "incomplete")
- Admin assigns same teacher to same subject in two different batches at conflicting times → system warns
- Admin accidentally creates duplicate batch names → enforce unique batch names within an academic year

---

### 4.2 Mid-Course Teacher Reassignment

**Scenario:** Admin must remove Teacher X from Math in Batch A and assign Teacher Y from 1st March.

**Admin Flow:**
1. Admin selects Batch A → Math → Teacher assignments
2. Sets Teacher X's `end_date` = 28 Feb
3. Assigns Teacher Y with `start_date` = 1 Mar
4. System notifies: Teacher X (removed), Teacher Y (added), Students in Batch A, Parents of Batch A

**Constraints:**
- Cannot set `end_date` before Teacher X's earliest session date (they can't retroactively not have taught)
- All sessions from 1 Mar onwards in Teacher X's name must be re-tagged to Teacher Y (or left as historical)
- Teacher X's already-marked attendance records are NOT altered — historical integrity preserved
- If Teacher Y is already at max batch capacity (admin-defined limit), warn before assignment

---

### 4.3 Admin Generates Cross-Batch Reports

**Report Types Admin Needs:**

| Report | Filters | Complexity |
|--------|---------|------------|
| Attendance % by Student | Batch, Subject, Date range | Must handle students in multiple batches |
| Attendance % by Teacher | Teacher, Subject, Batch | Must show substitute sessions separately |
| Performance comparison | Batch vs Batch, same subject | Only comparable if same syllabus |
| Fee collection status | Batch, Month, Payment method | Show partial payments, pending, overdue |
| Teacher utilization | Sessions assigned vs conducted | Leaves, substitutions considered |
| Syllabus coverage | Per subject per batch | % topics covered vs planned |
| Parent engagement | Notification read rate, portal login frequency | Per parent per student |

---

### 4.4 Batch Cloning / Template

**Scenario:** Admin creates "Batch A" every year with the same structure (same subjects, similar timetable).

**Requirements:**
- Admin can clone an existing batch as a template
- Clone copies: subjects, default timetable structure, fee structure
- Clone does NOT copy: enrolled students, teacher assignments (must be re-done), historical data
- Admin must review and update before publishing cloned batch
- Cloned batch starts with status: DRAFT

---

### 4.5 Admin Handles Timetable Conflicts

**Conflict Types:**
1. **Teacher-Teacher Conflict:** Same teacher, two sessions at same time
2. **Student-Student Conflict:** Student enrolled in two subjects at same time (cross-batch)
3. **Room/Resource Conflict:** (if room management is implemented) Same room booked twice
4. **Batch Overlap:** Two batches sharing a teacher, scheduled at the same time

**Required Behaviors:**
- Real-time conflict detection during timetable creation (not just on publish)
- Admin sees a visual conflict map: red cells = conflicted slots
- System suggests available time slots for a teacher based on their current schedule
- Student can report a timetable conflict via app → admin notified

---

### 4.6 Academic Year / Session Management

**Scenario:** Admin closes Academic Year 2024–25 and opens 2025–26.

**Requirements:**
- All batches from 2024–25 are archived (read-only)
- Students not re-enrolled in 2025–26 batches are marked as ALUMNI or INACTIVE
- Fee dues from 2024–25 carry forward if unpaid
- Teachers carry over; their subject assignments reset for new year
- Historical data (attendance, grades) remains accessible with "Academic Year 2024–25" filter
- Report cards for 2024–25 can still be generated after year close

---

## 5. Parent Scenarios (Complex)

### 5.1 Parent with Multiple Children in Different Batches

**Scenario:** Parent Sharma ji has two children: Rohan (Batch A, Class 10) and Kavya (Batch B, Class 8).

**Requirements:**
- Single parent login shows a child-switcher: [Rohan] [Kavya]
- All notifications are attributed to the correct child
- Fee payment is separate per child (but visible from single parent view)
- Attendance, grades, and teacher details are separate per child
- If both children have a fee due at the same time, parent sees combined "Total dues: ₹X" with breakdown

**Edge Cases:**
- Parent pays fee for Rohan but the system credits to Kavya → fee allocation must require explicit child selection
- Notification: "Rohan's attendance is below 75% in Physics" — not just "attendance is low"
- One child excels (honor roll), another struggles — parent dashboard shows both clearly without conflation

---

### 5.2 Parent Communication & Notification Scenarios

| Trigger | Notification | Medium |
|---------|-------------|--------|
| Attendance drops below threshold (e.g., 75%) | "Rahul's Mathematics attendance is 68%. Minimum required: 75%." | Push + SMS |
| Upcoming fee due | "Fee of ₹5,000 for Batch A is due on 15th March." | Push + Email |
| Teacher changed | "Rahul's Physics teacher has changed from Mr. Kumar to Ms. Singh effective 1st March." | Push + Email |
| Assignment not submitted | "Priya has not submitted the Chemistry assignment due yesterday." | Push |
| Exam scheduled | "Batch A Final Exam: Mathematics on 20th March at 10 AM." | Push + SMS |
| Result published | "Rahul's result for Mid-term Exam is now available." | Push + Email |
| Student absent today | "Kavya was marked absent today (18th March) in all sessions." | SMS (real-time) |
| Holiday declared | "All classes cancelled on 25th March (Holiday: Holi)." | Push |
| Parent-Teacher meeting | "Parent-Teacher Meeting scheduled on 30th March." | Push + Email + SMS |

---

### 5.3 Parent Can View Per-Subject Per-Teacher Details

**What a Parent Should See:**
- For each subject their child is enrolled in: Subject name, Batch, Teacher name(s)
- If the subject has two teachers (theory + lab): Both names shown with their role
- If substitute teacher is active: Shows "Currently taught by [Substitute Name]" with notice
- Attendance breakdown: Theory attendance % + Lab attendance % shown separately
- Assignment submission status per subject
- Grade/marks per assessment per subject

---

### 5.4 Parent Raises a Concern / Complaint

**Scenario:** Parent believes their child's attendance was incorrectly marked absent on 15th March.

**Flow:**
1. Parent taps the absent session → "Raise Dispute" option
2. Parent fills: date, subject, reason, optional evidence (screenshot/note)
3. Admin and relevant teacher are notified of the dispute
4. Teacher reviews → confirms or corrects the attendance record
5. If corrected: Parent and student notified; audit log records the change
6. If not corrected: Admin makes final decision; parent sees final status

**Data Requirements:**
- Every attendance record modification must create an audit trail: `changed_by`, `changed_at`, `reason`, `original_value`, `new_value`
- Disputes visible to admin for compliance review

---

## 6. Attendance Scenarios (Complex)

### 6.1 Attendance Calculation — Which Formula?

**Scenario:** Subject Chemistry has Theory (4 days/week) and Lab (1 day/week).

```
Option A — Combined:
Total sessions = theory + lab sessions combined
Student attendance % = (attended theory + attended lab) / (total theory + total lab) × 100

Option B — Separate thresholds:
Theory attendance must be ≥ 75% independently
Lab attendance must be ≥ 75% independently
Both must pass for overall subject eligibility

Option C — Weighted:
Attendance % = (theory attended × 0.7 + lab attended × 0.3) /
               (theory total × 0.7 + lab total × 0.3) × 100
```

**Requirement:** Admin must be able to configure per-subject which formula to apply.

---

### 6.2 Attendance During Substitute Period

**Logic:**
- Session on 5th March: Teacher Z (substitute) marked 30/40 students present
- This session is counted towards student attendance — regardless of who marked it
- Report shows: "5th March — Teacher Z (sub)" in the attendance log
- Teacher X's attendance stats: Their sessions are from 1 Jan to 4 March + 26 March onwards
- Teacher Z's stats: Only for their substitute sessions (5–25 March)

---

### 6.3 Backdated Attendance Correction

**Scenario:** Teacher accidentally marked everyone present on 10th Feb (was actually a holiday). Needs to correct 5 days later.

**Requirements:**
- Teachers cannot modify attendance older than X hours/days (configurable, e.g., 24 hours)
- Beyond the window: teacher submits a correction request with reason
- Admin approves/rejects the correction request
- All corrections are logged: `original_value`, `corrected_value`, `corrected_by`, `corrected_at`, `reason`, `approved_by`
- Students whose attendance changes are notified

---

### 6.4 Holiday / Cancellation Impact on Attendance

**Scenario:** Admin declares 5 holidays in March. Some are declared after attendance was already marked for those days.

**Requirements:**
- If holiday is declared BEFORE the session: session is cancelled from timetable; not counted in total sessions
- If holiday is declared AFTER sessions were already marked: admin must choose — cancel session (reduces denominator) OR keep it (attendance already marked counts)
- "Cancelled session" different from "missed session" — student is not penalized for cancelled sessions
- Total sessions (denominator) in attendance % = scheduled sessions - cancelled sessions

---

### 6.5 Proxy Attendance Detection

**Scenario:** Student A marks attendance on behalf of Student B (both mobile devices present).

**Detection Methods:**
- GPS location at time of marking (must match class location ± configurable radius)
- Rapid sequential markings from same IP/device
- Student marked present but left early (if exit also tracked)
- QR code rotation (new QR every 60 seconds; old QR invalid)

**Requirements:**
- If proxy suspected: flag the record for teacher/admin review (don't auto-penalize)
- Alert: "Suspicious attendance activity detected for [Student] on [Date, Subject]"
- Admin can mark attendance as "DISPUTED" pending investigation

---

## 7. Timetable & Scheduling Conflicts

### 7.1 Types of Conflicts to Detect

```
1. TEACHER_DOUBLE_BOOKING
   Teacher X → Math (Batch A, Mon 9-10 AM) AND Physics (Batch B, Mon 9-10 AM)
   → BLOCK: Cannot save this timetable

2. STUDENT_OVERLAP (Cross-Batch Enrollee)
   Student R → Math (Batch A, Tue 11-12) AND Chemistry (Batch B, Tue 11-12)
   → WARN student/admin during enrollment; do not auto-block (policy decision)

3. RESOURCE_CONFLICT (if rooms tracked)
   Room 101 → Math (Batch A, Wed 2-3 PM) AND CS (Batch B, Wed 2-3 PM)
   → BLOCK

4. CONSECUTIVE_OVERLOAD (teacher welfare)
   Teacher X → 6 consecutive sessions in a day (beyond configurable max)
   → WARN admin

5. BATCH_TIME_OVERLAP
   Batch A and Batch B both share Teacher X; their timetables must not clash for Teacher X

6. SUBJECT_GAP VIOLATION
   Same subject scheduled twice on the same day for the same batch
   → Optional: WARN (depends on institution policy)
```

---

### 7.2 Timetable Operations Admin Needs

- **Bulk reschedule:** "Shift all Monday sessions of Batch A to Tuesday for the month of March"
- **Holiday cascade:** "Mark 10 March as holiday — cancel all sessions, notify all affected students/teachers"
- **Teacher leave cascade:** "Teacher X is on leave 5–10 March — auto-cancel their sessions OR auto-assign substitute"
- **Clone week:** "Repeat this week's timetable for next 4 weeks"
- **Exception slots:** "Add extra session for Batch B's Math on Saturday 20 March only"

---

## 8. Fee & Payment Scenarios

### 8.1 Fee Structure Complexity

| Structure Type | Description | Example |
|----------------|-------------|---------|
| **Per batch (flat)** | One fee for entire batch | ₹30,000/semester for Batch A |
| **Per subject** | Fee per enrolled subject | ₹5,000/subject × 5 subjects |
| **Tiered by subject count** | Discount for more subjects | 1–3 subjects: ₹5k each; 4+: ₹4k each |
| **Installment plan** | Split into 3–4 installments | ₹30k paid as ₹10k × 3 months |
| **Pro-rated on join date** | Student joins mid-month | Only pays for remaining sessions |
| **Sibling discount** | Two children from same family | 10% off second child's fee |
| **Scholarship/Waiver** | Partial or full fee waiver | Admin applies ₹5k scholarship |
| **Late fee penalty** | Fee paid after due date | ₹500 penalty per week late |

---

### 8.2 Fee Scenarios When Batch/Subject Changes

- **Student transfers batch mid-course:** Batch A fee partially credited; Batch B fee charged pro-rated
- **Student drops a subject:** Subject fee refunded/credited per admin policy (no refund / partial / full based on weeks remaining)
- **Teacher changes mid-course:** No fee impact (fee is per batch/subject, not teacher)
- **Batch dissolved mid-course:** Full or pro-rated refund; admin must handle bulk refund
- **Student is expelled:** Fee dues still collectible; no refund for used sessions

---

### 8.3 Fee Dispute Flow

1. Parent disputes a charge: "I was charged ₹5,000 but the subject fee is ₹4,000"
2. Admin reviews payment record and fee structure
3. Admin either confirms the charge or creates a credit note
4. If credit note: applied to next installment automatically
5. Audit trail: every fee change logged with reason

---

## 9. Notification & Communication Logic

### 9.1 Notification Routing Rules

```
For a given event:
  → Find all affected students
  → For each student:
      → Find parent(s) linked to that student
      → Find teacher(s) responsible for that session/subject
      → Find admin (always notified for critical events)

  Channels:
    → In-app push notification (Flutter Firebase FCM)
    → SMS (Twilio) — for critical events only (absent, fee due, result)
    → Email — for formal communications (fee receipts, report cards)
```

### 9.2 Notification Scenarios by Role

**Teacher receives:**
- Student submitted assignment (their subject only)
- Student attendance drops below threshold in their subject
- Admin reassigned/changed their schedule
- New student enrolled in their batch
- Exam results need to be entered by [deadline]
- Timetable changed for their session

**Student receives:**
- New assignment uploaded (per subject)
- Attendance warning (per subject)
- Result/grades published
- Fee due reminder
- Timetable change affecting their subjects
- Teacher change announcement

**Parent receives:**
- All student notifications (relayed) + fee-specific ones
- Weekly attendance summary (optional, configurable)
- Parent-teacher meeting invites
- Emergency announcements

**Admin receives:**
- Teacher absence report (auto-generated if teacher misses session without marking holiday)
- Fee collection daily summary
- Dispute/complaint raised by parent or student
- System errors (batch with no teacher, timetable conflict, etc.)

---

### 9.3 Bulk Announcement Logic

**Admin broadcasts to:**
- All students in one batch
- All students across all batches
- All parents of students in a specific batch
- All teachers of a specific subject
- All teachers in the institute

**Teacher broadcasts to:**
- Students in their assigned batch(es)
- Students in a specific subject they teach
- Specific students (tagged)

**Constraints:**
- Teacher CANNOT broadcast to batches they are not assigned to
- Teacher CANNOT message parents directly (only via admin-mediated channels or formal announcements)
- Messages are not real-time chat — they are announcements with read receipts

---

## 10. Data Model Design (Recommended)

### 10.1 Core Tables

```sql
-- Institute
institutes (id, name, config_json, created_at)

-- Academic Year
academic_years (id, institute_id, name, start_date, end_date, is_active)

-- Users (polymorphic role table)
users (id, name, email, phone, role: ADMIN|TEACHER|STUDENT|PARENT, is_active)

-- Teacher profiles
teachers (id, user_id, specializations[], max_batches, salary_type)

-- Students
students (id, user_id, enrollment_number, current_batch_id)

-- Parents
parents (id, user_id)
parent_student (parent_id, student_id, relation: FATHER|MOTHER|GUARDIAN)

-- Subjects (master list)
subjects (id, name, code, type: THEORY|PRACTICAL|BOTH, institute_id)

-- Batches
batches (
  id, institute_id, academic_year_id,
  name, description, max_students,
  status: DRAFT|ACTIVE|COMPLETED|ARCHIVED,
  start_date, end_date
)

-- Batch–Subject assignments
batch_subjects (
  id, batch_id, subject_id,
  theory_sessions_per_week, practical_sessions_per_week,
  attendance_formula: COMBINED|SEPARATE|WEIGHTED,
  theory_weight, practical_weight,  -- for WEIGHTED formula
  min_attendance_theory_pct, min_attendance_practical_pct
)

-- Teacher assignments per batch-subject
batch_subject_teachers (
  id, batch_subject_id, teacher_id,
  role: PRIMARY|CO_TEACHER|SUBSTITUTE|LAB|GUEST,
  session_type: THEORY|PRACTICAL|BOTH,
  from_date, to_date,  -- NULL to_date = indefinite
  is_active
)

-- Student enrollments per batch (and per subject if cross-batch)
student_enrollments (
  id, student_id, batch_id, batch_subject_id,  -- batch_subject_id nullable for full-batch enroll
  status: ACTIVE|DROPPED|TRANSFERRED|COMPLETED,
  enrolled_date, exit_date, exit_reason
  attempt_number  -- for repeat students
)

-- Timetable slots
timetable_slots (
  id, batch_subject_id,
  day_of_week: 0-6,
  start_time, end_time,
  session_type: THEORY|PRACTICAL,
  room, recurrence_end_date,
  is_cancelled, cancellation_reason
)

-- Individual sessions (instances of timetable slots)
sessions (
  id, timetable_slot_id, session_date,
  teacher_id,  -- may differ from primary if substitute
  status: SCHEDULED|CONDUCTED|CANCELLED|HOLIDAY,
  session_type: THEORY|PRACTICAL,
  notes
)

-- Attendance
attendance_records (
  id, session_id, student_id,
  status: PRESENT|ABSENT|LATE|EXCUSED|MAKEUP,
  marked_by_teacher_id, marked_at,
  is_disputed, dispute_reason,
  correction_by, correction_at, correction_reason, original_status
)

-- Substitute assignments
substitute_assignments (
  id, batch_subject_id, primary_teacher_id, substitute_teacher_id,
  from_date, to_date,
  created_by_admin_id, reason
)

-- Fee structures
fee_structures (
  id, batch_id, batch_subject_id,  -- null batch_subject_id = batch-level fee
  amount, due_date, installment_number,
  late_fee_per_week
)

-- Student fee records
student_fees (
  id, student_id, fee_structure_id,
  amount_due, amount_paid, discount, scholarship,
  status: PENDING|PARTIAL|PAID|OVERDUE|WAIVED,
  due_date, paid_date
)
```

---

## 11. API Endpoint Matrix

### 11.1 Teacher APIs

| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/teacher/batches` | Teacher | All batches assigned to logged-in teacher |
| GET | `/api/teacher/batches/:batchId/subjects` | Teacher | Subjects taught by teacher in a batch |
| GET | `/api/teacher/sessions/today` | Teacher | Today's sessions across all batches |
| GET | `/api/teacher/sessions/:sessionId/students` | Teacher | Students for a specific session |
| POST | `/api/teacher/sessions/:sessionId/attendance` | Teacher | Mark attendance for a session |
| PUT | `/api/teacher/attendance/:recordId` | Teacher | Correct attendance (within time window) |
| POST | `/api/teacher/attendance/correction-request` | Teacher | Request correction after window expired |
| GET | `/api/teacher/subjects/:subjectId/attendance-summary` | Teacher | Attendance stats for their subject |
| POST | `/api/teacher/announcements` | Teacher | Announce to assigned batch/subject only |
| GET | `/api/teacher/schedule` | Teacher | Full timetable across all batches |

### 11.2 Student APIs

| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/student/dashboard` | Student | All enrolled subjects, attendance, upcoming sessions |
| GET | `/api/student/timetable` | Student | Merged timetable from all enrolled batches |
| GET | `/api/student/attendance` | Student | Per-subject attendance with formula applied |
| GET | `/api/student/attendance/:subjectId` | Student | Detailed session-by-session record |
| POST | `/api/student/attendance/:recordId/dispute` | Student | Raise dispute on an attendance record |
| GET | `/api/student/teachers` | Student | All teachers for all enrolled subjects |
| GET | `/api/student/fees` | Student | Fee schedule, paid, pending |

### 11.3 Admin APIs

| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| POST | `/api/admin/batches` | Admin | Create batch |
| PUT | `/api/admin/batches/:id/publish` | Admin | Publish batch (validates completeness) |
| POST | `/api/admin/batches/:id/subjects` | Admin | Add subject to batch |
| POST | `/api/admin/batch-subjects/:id/teachers` | Admin | Assign teacher to batch-subject |
| PUT | `/api/admin/batch-subject-teachers/:id` | Admin | Update teacher assignment (dates, role) |
| POST | `/api/admin/substitutes` | Admin | Assign substitute teacher |
| GET | `/api/admin/conflicts/timetable` | Admin | Get all timetable conflicts |
| GET | `/api/admin/reports/attendance` | Admin | Cross-batch attendance report |
| GET | `/api/admin/reports/fee-collection` | Admin | Fee collection summary |
| PUT | `/api/admin/attendance/:id/correction` | Admin | Override attendance correction |
| POST | `/api/admin/announcements/bulk` | Admin | Broadcast to any target group |

### 11.4 Parent APIs

| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/parent/children` | Parent | All linked children |
| GET | `/api/parent/children/:studentId/attendance` | Parent | Child's attendance per subject |
| GET | `/api/parent/children/:studentId/fees` | Parent | Child's fee status |
| GET | `/api/parent/children/:studentId/teachers` | Parent | All teachers for child's subjects |
| POST | `/api/parent/children/:studentId/attendance/:id/dispute` | Parent | Raise dispute on behalf of child |
| GET | `/api/parent/notifications` | Parent | All notifications across all children |

---

## 12. Testing Scenarios Checklist

### 12.1 Batch-Subject-Teacher Assignment Tests

- [ ] Create batch with 5 subjects, each with 1 teacher — verify all 5 teachers can access
- [ ] Assign 2 teachers to same subject (co-teaching) — both can mark attendance independently
- [ ] Try to assign same teacher to two time-conflicting sessions — must be blocked
- [ ] Assign substitute teacher for 2 weeks — verify primary teacher loses access during that period
- [ ] Substitute period ends — verify primary teacher regains access automatically
- [ ] Substitute marks attendance — verify it counts for students and is tagged "substitute session"
- [ ] Remove teacher from one subject but keep them in another (same batch) — verify scoped removal
- [ ] Transfer teacher mid-course — verify historical sessions remain, new sessions go to new teacher
- [ ] Create guest teacher — verify auto-deactivation after last scheduled session

### 12.2 Student Enrollment & Transfer Tests

- [ ] Enroll student in cross-batch subjects — verify merged timetable has no conflicts
- [ ] Try to enroll student in two subjects with the same time slot — conflict detected
- [ ] Transfer student batch mid-course — verify attendance carries over with date attribution
- [ ] Student drops one subject — verify other subjects unaffected; fee recalculated
- [ ] Repeat student enrolled in same subject — previous records preserved; new attempt tracked
- [ ] Student attends makeup from different batch — credited to original batch attendance
- [ ] Student added to full batch (at capacity) — enrollment blocked with proper error

### 12.3 Attendance Logic Tests

- [ ] Mark attendance for theory session — does not affect lab attendance count
- [ ] Apply Combined formula — verify % = (theory_present + lab_present) / (theory_total + lab_total)
- [ ] Apply Separate threshold — student passes theory but fails lab — marks as ineligible
- [ ] Apply Weighted formula — verify weighted calculation
- [ ] Holiday declared AFTER session marked — verify denominator adjustment
- [ ] Backdated correction beyond allowed window — verify correction request flow
- [ ] Parent disputes attendance — verify teacher notified and can confirm/correct
- [ ] Proxy detection triggered — verify flagging without auto-penalizing

### 12.4 Parent & Notification Tests

- [ ] Parent with 2 children — notification for Child A does NOT appear under Child B
- [ ] Fee payment for Child A must not credit to Child B
- [ ] Parent sees attendance for each subject per child separately
- [ ] Teacher change notification sent to all parents of affected batch
- [ ] Student below 75% attendance — SMS triggered to parent (not just push)
- [ ] Parent raises fee dispute — admin notified, resolution logged

### 12.5 Admin Operations Tests

- [ ] Admin creates timetable — real-time conflict detection blocks double-booking
- [ ] Admin declares holiday — all sessions that day cancelled, all affected parties notified
- [ ] Admin generates cross-batch attendance report — correct for students in multiple batches
- [ ] Admin clones batch — subjects and timetable structure copied, no students/teachers/data copied
- [ ] Admin closes academic year — all batches archived, historical data accessible

---

> **Document Status:** Living document — update as new features are added.  
> **Coverage:** Admin, Teacher, Student, Parent across all lifecycle stages.  
> **Standards:** Supports multi-batch, multi-teacher, multi-subject, multi-child, cross-batch enrollment.

*Version 1.0 — Educational App Feature Blueprint*