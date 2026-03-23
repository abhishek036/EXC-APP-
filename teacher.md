# 🎯 ROLE

You are a world-class EdTech product designer + system architect.

Design a **Teacher Panel** that:

* Uses SAME design system as Admin Panel
* Is fast, action-focused, and practical
* Handles real teacher workflow (not just content upload)

This is a **daily-use execution tool**, not a dashboard showcase.

---

# 🧠 CORE PHILOSOPHY

Admin = Strategy + Control
Teacher = Execution + Interaction

Teacher UI must:

* Reduce friction
* Save time
* Focus on real teaching flow

---

# 🧭 FINAL NAVIGATION (OPTIMIZED)

1. Home
2. My Batches
3. Doubts 🔥 (Global Doubt Inbox across assigned batches)
4. Schedule 🔥
5. Profile / More

👉 REMOVE global "Content" & "Students" (they belong inside batch)

---

# 🏠 HOME DASHBOARD (SMART)

## Show:

* Greeting
* Today’s classes
* Next class countdown
* Pending tasks:

  * Doubts pending
  * Assignments to check
  * Tests to review

---

## ⚡ QUICK ACTIONS (COMPACT)

* Take Attendance
* Upload Lecture
* Add Assignment
* Create Test

👉 Use **1 FAB menu**

---

# 📦 MY BATCHES

List:

* Batch Name
* Subject
* Student count
* Next class

👉 Click → open **Teacher Batch Panel**

---

# 🚀 TEACHER BATCH PANEL

Tabs:

1. Overview
2. Content
3. Students
4. Tests
5. Attendance
6. Doubts 🔥 (IMPORTANT)

---

# 📊 OVERVIEW

* Batch info
* Your subject
* Total students

## 🔥 ADD:

* Teaching progress % (auto from syllabus)
* Last lecture summary
* Upcoming class

---

# 🗺️ SYLLABUS TRACKER (NEW - VERY IMPORTANT)

Inside Content:

* Tree structure:

Physics
→ Mechanics
→ Kinematics
→ Projectile Motion ✅

👉 Teacher marks topics completed
👉 System auto calculates progress

---

# 📚 CONTENT (EXECUTION ZONE)

## Sub-tabs:

* Lectures
* Notes
* Assignments
* Materials

## 📁 MATERIALS (STATIC RESOURCES)

Definition:

* Materials = static learning files/resources (PDFs, slide decks, datasets, images, media files).
* Lectures = time-based teaching sessions with schedule/attendance context.
* Notes = teacher-authored textual/class-summary content.

Teacher actions:

* Upload single file
* Bulk upload
* Create folders/subfolders
* Move/organize items
* Rename
* Delete
* Versioning (new version on same material id)
* Set visibility/publish date
* Attach metadata/tags
* Enforce file type + size limits
* Download

UI/UX behavior:

* Folder tree (left) + content pane (right)
* List/Grid toggle
* Search + filter by tag/type/date
* Batch actions (move/delete/tag/visibility)
* Inline preview (PDF/image/video when supported)
* Upload progress + validation errors per file

Material item example fields:

* id
* title
* description
* type
* fileUrl
* size
* uploadedBy
* uploadedAt
* version
* visibility
* tags

Backend/API + permission requirements:

* Endpoints: upload, bulk-upload, download, list, move, rename, delete, version-create
* Storage quota checks per institute/batch
* Access control: teacher can manage materials only for assigned batches
* Audit logs for upload/move/rename/delete/visibility changes

Integration points:

* Assignment attachments
* Classroom share in live/post-class flow
* LMS export

---

## 🎥 LECTURES (UPGRADED)

Teacher can:

* Upload YouTube link
* Mark complete
* Edit

### 🔥 ADD:

* Views count
* Completion %
* Linked topic (syllabus sync)

---

## 🔴 LIVE CLASS SYSTEM (NEW)

### Pre-Class:

* "Start Class" button (visible before time)

### During Class:

* Focus Mode:

  * Student count
  * Chat
  * Mute control

### Post-Class:

* Auto popup:

  * Upload recording
  * Add notes

---

## 📄 NOTES

* Upload PDF
* Replace
* Download stats

---

## 📝 ASSIGNMENTS

### Teacher can:

* Create
* Set deadline
* Attach files

### 🔥 ADD:

* Pending evaluation count
* Late submissions highlight

---

## ✍️ GRADING SYSTEM (IMPORTANT UX)

### When checking:

* Left: student submission
* Right: marks + remarks

👉 Swipe → next student
👉 No page reload

---

# 👨‍🎓 STUDENTS

List (COMPACT VIEW):

Name | Attendance | Assignment | Status

---

## 🔥 ADD:

* Filter:

  * Low attendance
  * Weak students
  * Pending work

---

## Student Profile:

* Attendance graph
* Test scores
* Assignment status

---

# 🧪 TESTS

Teacher can:

* Create test
* Add questions
* View results

---

## 🔥 ADD:

* Avg score
* Topper
* Weak students list

---

# 📅 ATTENDANCE

* Mark attendance
* View daily stats

---

## 🔥 ADD:

* Highlight low attendance
* Quick notify option

---

# 💬 DOUBT RESOLUTION (CRITICAL MODULE)

👉 This was missing earlier → now core feature

## Global Doubt Inbox (Top-level "Doubts" navigation)

Scope:

* Shows doubts across ALL batches assigned to the teacher.
* Includes optional batch filter (All Batches + per-batch filter).
* Fast triage view for cross-batch pending doubts.

## Batch Doubts (Teacher Batch Panel → "Doubts" tab)

* Same doubt objects, but pre-filtered to the currently opened batch.
* Use this when resolving doubts in batch context alongside attendance/tests/students.

Terminology rule:

* "Doubts" in global navigation = Global Doubt Inbox.
* "Doubts" inside Teacher Batch Panel = Batch-scoped doubts view.

Each card:

* Student name
* Question (text/image/audio)
* Topic

---

## Actions:

* Reply (text / voice / image)
* Mark:

  * Resolved
  * Pending
  * Discuss in class

---

## UX:

👉 Bottom sheet reply (NOT new page)
👉 Fast interaction

---

# 📢 ANNOUNCEMENTS (NEW)

Inside batch:

* Post message
* Mark urgent

👉 Sends push notification

---

# 📅 SCHEDULE (NEW TAB)

* Weekly calendar
* Today’s classes
* Upcoming sessions

---

## 🔥 ADD:

* Substitution alerts
* Class reminders

---

# 🧑‍🏫 PROFILE / MORE

* Profile
* Settings

## 🔥 ADD:

* Leave request
* Assigned batches
* Teaching stats

---

# 🚫 PERMISSIONS

Teacher CANNOT:

* Manage fees
* Add/remove students globally (outside assigned batches)

Teacher & Batch permission matrix (explicit):

* Add student to assigned batch: ❌ Direct add not allowed, ✅ Request add allowed
* Remove student from assigned batch: ❌ Direct remove not allowed, ✅ Request remove allowed
* Add/remove students globally: ❌ Not allowed

Change batch structure (granular):

* Schedule (class timings) for assigned batch: ✅ Allowed
* Syllabus/content for assigned batch: ✅ Allowed (teaching progress/content organization)
* Student roster for assigned batch: ❌ Direct change not allowed (request workflow only)
* Batch settings (name/capacity/fee/core policy): ❌ Not allowed

---

# 🎨 DESIGN SYSTEM (STRICT)

Use SAME as admin:

* #0D1282
* #EEEDED
* #F0DE36
* #D71313

---

# 🧠 UI RULES

* Compact view for lists
* Clean spacing
* No repetitive cards
* Highlight important data

---

# ⚡ INTERACTION RULES

* Fast actions
* 2-click workflow
* Instant feedback

---

# 🎯 FINAL GOAL

Teacher panel should feel:

* Fast
* Practical
* Daily usable
* Minimal friction

---

# 🧠 SUCCESS CONDITION

If teacher can:

* Start class quickly
* Upload lecture fast
* Solve doubts instantly
* Check students easily

→ SUCCESS
