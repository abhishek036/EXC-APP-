# Complete Admin Module — Coaching Management System

---

## 1. DASHBOARD

The first screen admin sees after login. Everything at a glance.

**Stats Cards (top row)**
- Total active students
- Total teachers
- Total batches running
- Monthly revenue collected
- Pending fee amount (overdue)
- Today's total classes scheduled

**Charts**
- Monthly fee collection bar chart (last 6 months)
- Attendance overview — % present today across all batches
- Student enrollment trend (last 3 months)

**Quick Actions (buttons)**
- Add Student
- Collect Fee
- Mark Attendance
- Send Announcement

**Live Feed**
- Today's class schedule (batch name, teacher, time, room)
- Recent 5 payments received
- Recent 5 students marked absent today
- Overdue fee alert banner (e.g. "23 students have overdue fees")

---

## 2. STUDENT MANAGEMENT

### Add Student
- Full name
- Phone number (used for login)
- Date of birth
- Gender
- Address
- Photo upload
- Blood group (optional)
- Previous school / institute name
- Enrollment date
- Assign to batch(es) — can assign to multiple
- Student ID — auto-generated or manual entry

### Parent / Guardian Info
- Father's name, phone, occupation
- Mother's name, phone, occupation
- Emergency contact number
- Relationship

### Student List
- Search by name or phone
- Filter by: batch / status (active, inactive) / fee status / enrollment month
- Sort by: name, enrollment date, fee status
- View as table or card grid
- Bulk select → bulk action (send message, mark inactive, assign batch)

### Student Profile (full 360 view)
- Personal info tab
- Attendance history tab — monthly calendar heatmap
- Fee history tab — every month's record
- Exam results tab — all exams with marks and grades
- Quiz attempts tab
- Documents tab — uploaded ID proof, photos

### Edit Student
- Edit any field
- Change batch assignment
- Upload or change photo

### Deactivate / Reactivate
- Soft delete — data preserved, student cannot log in
- Reason for deactivation (optional note)
- Reactivate any time

### Transfer Student
- Move student from one batch to another
- Transfer history maintained

### Student ID Card Generation
- Auto-generate printable ID card with photo, name, batch, institute name

---

## 3. TEACHER MANAGEMENT

### Add Teacher
- Full name, phone, email
- Subject(s) they teach
- Qualification
- Joining date
- Photo
- Address
- Bank details (if salary is tracked)

### Teacher List
- Search and filter by subject or batch
- View batches assigned to each teacher

### Teacher Profile
- Personal info
- Assigned batches
- Attendance they've marked (history)
- Quizzes created
- Notes uploaded
- Salary records (if enabled)

### Edit / Deactivate Teacher
- Edit any info
- Reassign batches to another teacher before deactivating

---

## 4. BATCH MANAGEMENT

### Create Batch
- Batch name (e.g. "Class 11 — Science Morning")
- Subject
- Assign teacher
- Days of week (Mon, Tue… or custom)
- Start time and end time
- Room / location
- Start date and end date
- Max student capacity
- Batch type: regular / crash course / test series

### Batch List
- Filter by: subject, teacher, active/inactive
- Student count per batch
- Color coding by subject

### Batch Detail Page
- All enrolled students list
- Timetable for that batch
- Attendance history
- Quizzes published for this batch
- Notes and assignments uploaded

### Add / Remove Students from Batch
- Add individual or bulk
- Set joining date within batch
- Remove with reason note

### Deactivate Batch
- Mark batch as completed or cancelled
- All data preserved

---

## 5. FEE MANAGEMENT

This is the most critical module.

### Fee Structure Setup
- Set monthly fee amount per batch
- One-time admission fee
- Exam fee (separate)
- Late fee — auto-add after due date (e.g. ₹50 after 10th of month)
- Discount setup — fixed amount or percentage (for specific students)
- Concession flag — mark students with fee concession and reason

### Create Fee Record
- Select student and month
- Amount auto-filled from batch fee structure
- Admin can override amount manually
- Due date auto-set (configurable — e.g. 10th of every month)
- Add late fee if applicable

### Collect Payment
- Select payment mode: Cash / UPI / Card / Bank Transfer / Cheque
- Enter amount received
- Enter transaction ID (for UPI/bank)
- Add note (optional)
- Partial payment — collect part, mark remaining as balance
- Multiple payments for one month allowed

### Fee Receipt
- Auto-generated PDF on every payment
- Receipt includes: receipt number, date, student name, batch, amount, payment mode, month, institute name and logo
- Download as PDF
- Share via WhatsApp or email directly from app
- Receipt numbering — sequential and unique

### Fee Status Tracking
- Paid — full amount received
- Partial — some amount received, balance pending
- Pending — not yet paid, due date not passed
- Overdue — due date passed, not paid
- Waived — admin has waived off (with reason)

### Fee Dashboard / Reports
- Monthly collection summary — total collected vs total expected vs pending
- Filter by: batch / month / status / payment mode
- Student-wise outstanding report
- Date-range report — custom start and end date
- Payment mode breakdown (how much cash vs UPI vs card)

### Fee Reminders
- Send bulk WhatsApp message to all pending/overdue students
- Send SMS to pending students
- Schedule reminder — 7 days before due, 1 day before, on due date
- Automated reminders (no manual action needed)
- Custom reminder message text (admin sets it once)

### Online Fee Collection
- Parent pays via UPI / card inside app
- Payment gateway integration (Razorpay / PayU)
- Auto-receipt on successful payment
- Admin sees payment in real-time
- Failed payment log

### Export
- Export fee report as Excel / CSV
- Filter before export — by month, batch, status

---

## 6. ATTENDANCE MANAGEMENT

### Mark Attendance (Admin can also mark, not just teacher)
- Select batch and date
- Mark each student: Present / Absent / Late / Leave
- Mark all present — one tap
- Submit with timestamp

### Attendance Dashboard
- Today's attendance across all batches — % present
- Batch-wise attendance summary

### Student Attendance Report
- Monthly calendar view per student — color coded (green=present, red=absent, yellow=late, grey=leave)
- Attendance % calculation — automatically
- Month-wise breakdown — X present out of Y working days

### Batch Attendance Report
- All students in a batch, their % for selected month
- Sort by attendance % (lowest first — find at-risk students)
- Students below 75% highlighted automatically

### Absent Alerts
- One-click: send WhatsApp / SMS to parents of all absent students today
- Auto-alert: configure to send automatically after attendance is submitted

### Attendance Correction
- Admin can correct attendance submitted by teacher
- Edit any past date's attendance
- Correction log maintained (who changed, when, what)

### Holiday / Working Day Management
- Mark holidays — those days excluded from attendance calculation
- Set working days per week for each batch

---

## 7. EXAM & RESULT MANAGEMENT

### Create Exam
- Exam title (e.g. "Unit Test 2 — Physics")
- Subject
- Batch(es) it applies to
- Exam date
- Total marks
- Passing marks
- Duration

### Enter Results
- Student-wise marks entry
- Absent for exam — mark separately
- Marks out of total — auto grade calculated
- Grade scale: configurable (A+ above 90, A above 80, etc.)

### Result Dashboard
- Batch average
- Highest and lowest score
- Students who failed (below passing marks) — highlighted
- Subject-wise comparison across batches

### Result Report
- Student's complete result history — all exams
- Rank in batch for each exam
- Performance trend — score graph over time
- Downloadable as PDF (report card format)

### Send Results
- Notify students and parents when result is published — push + WhatsApp
- Parents can see result in their app immediately

---

## 8. TIMETABLE MANAGEMENT

### Create Timetable
- Slot-based — define time slots (e.g. 8am–9:30am, 10am–11:30am)
- Assign batch + teacher to each slot
- Day-wise for the week
- Room assignment

### View Timetable
- Admin sees full institute timetable — all batches, all rooms, all teachers
- Filter by: teacher / batch / room / day
- Detect conflicts — if same teacher or room is double-booked, show warning

### Edit Timetable
- Change any slot
- Handle substitution — replace teacher for a specific day

---

## 9. ANNOUNCEMENTS & COMMUNICATION

### Create Announcement
- Title and body text
- Attach image or PDF (optional)
- Target: All / specific role (teachers only, students only, parents only) / specific batch
- Send as: in-app notification + WhatsApp + SMS (choose one or all)
- Schedule for later (e.g. send tomorrow 9am)

### Announcement History
- All past announcements
- See who received it, how many opened it

### Bulk Messaging
- Select students by batch or filter
- Type a custom message
- Send via WhatsApp / SMS
- Use for: exam alerts, fee reminders, holiday notices, event info

### Direct Message
- Admin can message individual student, parent, or teacher from admin panel

---

## 10. QUIZ MANAGEMENT (Admin oversight)

- See all quizzes created by all teachers
- View quiz results and leaderboard
- Publish or unpublish any quiz
- Delete quiz
- Overall quiz performance report across batches

---

## 11. DOUBT MANAGEMENT (Admin oversight)

- See all pending doubts across all batches
- Assign doubt to a specific teacher if unassigned
- Flag urgent doubts
- See resolution rate per teacher

---

## 12. CONTENT MANAGEMENT (Admin oversight)

- See all notes and assignments uploaded by teachers
- Delete inappropriate or wrong content
- Content library — searchable, filter by subject, batch, date

---

## 13. LIVE CLASS MANAGEMENT

- See all scheduled live classes
- Cancel or reschedule
- See attendance of who joined the live session
- Recording URL — save link after class

---

## 14. STAFF & PAYROLL (Optional Module)

### Staff Management
- Add non-teaching staff (receptionist, peon, accountant)
- Role and department
- Contact info and joining date

### Salary Management
- Set monthly salary per staff/teacher
- Mark salary as paid
- Salary slip generation (PDF)
- Salary history per person
- Monthly payroll summary — total salary outgoing

### Advance / Deduction
- Record advance taken
- Record deduction reason and amount
- Auto-adjust in monthly salary

---

## 15. INSTITUTE SETTINGS

### General Settings
- Institute name
- Logo upload
- Address
- Contact phone and email
- Website URL
- Board / affiliation (CBSE, ICSE, State board, etc.)

### App Branding
- Primary colour theme
- Logo shown inside student and parent app
- Custom app display name

### Fee Settings
- Default due date (e.g. 10th of every month)
- Late fee amount and when it kicks in
- Grace period days
- Currency symbol

### Grade / Marks Settings
- Define grade scale: A+ = 90–100, A = 80–89, etc.
- Passing marks default

### Notification Settings
- Toggle: which notifications go out automatically
- Edit default message templates (for fee reminder, absent alert, etc.)
- WhatsApp sender ID / SMS sender ID

### Academic Year
- Set current academic year (e.g. 2025–26)
- Year-end rollover — archive old data, reset for new year

---

## 16. USER MANAGEMENT

- View all accounts: admin, teacher, student, parent
- Reset any user's password
- Deactivate any account
- See last login time per user
- Force logout from all devices
- Audit log — who did what and when (every action timestamped)

---

## 17. REPORTS & ANALYTICS (Central Reports Section)

| Report | Description |
|---|---|
| Fee collection report | Month-wise, batch-wise, mode-wise |
| Outstanding fee report | Who owes how much |
| Attendance report | Batch-wise %, student-wise |
| Low attendance report | Students below 75% |
| Exam performance report | Batch average, toppers, failures |
| Enrollment report | New students per month |
| Teacher activity report | Quizzes created, notes uploaded, doubts answered |
| Revenue report | Total income vs expected per month |

All reports: filterable by date range, batch, subject — exportable as CSV or PDF.

---

## 18. DATA & BACKUP

- Daily automatic backup to cloud
- Admin can manually trigger backup
- Download full data export (students, fees, attendance) as Excel
- Data retention — old academic year data archived, not deleted

---

That covers every admin function a coaching institute would ever need — from day one operations to long-term management. 





# 1️⃣ Important Features Missing

## A. Admission / Lead Management (Very Important)

Your system manages **existing students**, but not **new leads**.

Real coaching institutes need:

**Admission Leads Module**

Fields:

* Student name
* Phone number
* Interested course
* Source (Walk-in / Website / Instagram / Referral)
* Counsellor assigned
* Status:

  * New
  * Contacted
  * Trial class
  * Converted
  * Not interested

Features:

* Follow-up reminders
* Call tracking
* Conversion rate dashboard

This helps coaching increase **enrollments**.

---

## B. Inquiry Form on Website

Add:

```
Website Admission Form
```

Fields:

* Name
* Phone
* Class
* Course interest

Automatically create a **lead inside admin panel**.

---

## C. Trial Class Management

Many coaching institutes run **demo classes**.

Module:

```
Trial Class Management
```

Features:

* Schedule trial
* Assign student to trial batch
* Convert to full admission
* Track trial conversion rate

---

## D. Certificate Generation

Students often need:

* Completion certificate
* Participation certificate
* Test series certificate

Add:

```
Auto Certificate Generator
```

Admin enters:

* student name
* course
* completion date

Generate **PDF certificate**.

---

# 2️⃣ Operational Improvements

## A. Multi-Branch Support

Even if you start with single coaching, many institutes expand.

Add structure:

```
Branch
 ├ students
 ├ batches
 ├ teachers
```

Admin can manage:

* multiple locations
* branch-wise reports

---

## B. Classroom / Room Capacity

Batch module should include:

```
Room capacity
```

System should warn if:

```
students > capacity
```

This prevents overcrowding.

---

## C. Substitute Teacher Management

Real scenario:

Teacher absent.

Admin assigns substitute.

Add feature:

```
Teacher substitution
```

Track substitution history.

---

## D. Homework Tracking

Teachers assign homework.

Students submit.

Add:

```
Homework Module
```

Teacher:

* upload homework

Student:

* submit answers
* upload photo / PDF

Teacher:

* mark checked

---

# 3️⃣ Security Improvements (Important)

Your system manages **student personal data and payments**, so security matters.

Add:

### Role Based Access Control

```
Admin
Teacher
Student
Parent
Staff
```

Each role can only access allowed modules.

---

### Audit Logs

Already partially included but expand:

Track:

```
Who edited student data
Who deleted record
Who changed fee
```

Prevent misuse.

---

### Two-Factor Login for Admin

Admin login should support:

```
OTP verification
```

Adds security.

---

### Data Encryption

Sensitive fields:

```
phone numbers
payment transactions
```

Should be encrypted.

---

# 4️⃣ Features That Increase Sales Value

These are **not mandatory technically**, but they help you sell the product.

---

## A. Parent App Notifications

Parents should receive:

* attendance alert
* exam result
* fee reminder
* announcement

Parents often push institutes to adopt apps.

---

## B. Rank & Leaderboard System

Students love rankings.

Example:

```
Top 10 students
Batch rank
Subject rank
```

Gamification improves engagement.

---

## C. AI Doubt Assistant (Optional Future)

Basic AI chatbot:

```
Ask doubt
Get explanation
```

Even simple integration increases product value.

---

## D. Performance Prediction

System predicts:

```
student likely to fail
low attendance risk
```

Useful for teachers.

---

# 5️⃣ UX Improvements

Some operational UX improvements:

---

## A. Global Search

Admin should be able to search:

```
student
batch
teacher
payment
```

From one search bar.

---

## B. Activity Timeline

Student profile should show:

```
fees paid
attendance
exam result
announcements
```

All in chronological timeline.

---

## C. Notification Center

Admin should see:

```
recent alerts
failed payments
low attendance
```

---

# 6️⃣ Infrastructure Improvements

Since your target is **500–1000 students**, architecture should remain simple.

Recommended stack:

### Mobile

```
Flutter
```

### Backend

```
Firebase
```

Services:

```
Firebase Auth
Firestore
Firebase Storage
Firebase Messaging
```

### Payments

```
Razorpay
```

### Messaging

```
WhatsApp API
SMS Gateway
```

---

# 7️⃣ Missing Data Model Concept

Your system must be **Batch-Centric**.

Everything connects to batch:

```
Batch
 ├ Students
 ├ Attendance
 ├ Fees
 ├ Exams
 ├ Content
 ├ Live Classes
```

This keeps database clean.

---

# 8️⃣ Small But Useful Features

These small features improve daily operations.

Add:

```
Student birthday reminders
Teacher attendance
Inventory tracking (books, materials)
Expense tracking
Holiday calendar
Transport management (optional)
```

---

# 9️⃣ Scalability Weakness

Right now system assumes **single institute**.

Even if you sell per coaching, design it so that internally it supports:

```
multi-tenant structure
```

Later you can convert it to **SaaS platform**.

---

# 10️⃣ Final Missing Modules Summary

Add these modules to make system complete:

```
Lead / Admission management
Trial class system
Certificate generator
Homework system
Substitute teacher system
Branch management
Global search
Gamification leaderboard
```

---

# Overall Evaluation

Your design quality:

| Category              | Score    |
| --------------------- | -------- |
| Feature coverage      | 9 / 10   |
| Operational usability | 8.5 / 10 |
| Scalability           | 7.5 / 10 |
| Sales value           | 8.5 / 10 |

With improvements it becomes:

```
Enterprise-grade coaching ERP
```

---

