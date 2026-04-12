 This is a solid foundation for the admin panel of a coaching management app. You've clearly mapped out the core modules needed to run the business side of things.
Since you're building out the architecture, I've transcribed your handwritten notes exactly as you designed them, and then expanded on each section to fill in the missing UI/UX details, standard industry practices, and state-management logic that will make this a robust system.
Here is the comprehensive UI/UX Architecture for your Coaching App Admin Portal.
Global UI & Navigation Architecture
Based on your notes, the app relies on a primary navigation system (likely a Bottom Navigation Bar for mobile or a Top/Side Nav for tablet/web) with five core modules, plus global accessibility features.
 * Primary Navigation: Home | Students | Fees | Batches | Teachers
 * Hamburger Menu ("Side three line"): For secondary options, app settings, support, and quick shortcuts.
 * Global Profile ("Photo tap"): Tapping the admin's photo opens an editable profile page.
 * Global Syncing: As noted in your "Students" section, any change made to a profile or payment must trigger a state update to "save and update everywhere" (syncing across the student and teacher-facing apps).
1. Home (Dashboard)
Goal: A high-level, real-time overview of the coaching center's health and quick access to frequent actions.
From your notes:
 * At-a-Glance Stats: Quick metrics for total Fees collected/pending, Total Students, and Active Batches.
 * Quick Actions: "All feature shortcuts" but specifically "not much big buttons" (suggests a clean, grid-based icon layout for quick tasks like Add Student or Collect Fee).
 * Activity Timeline: A real-time feed of what's happening (e.g., "Student X paid ₹1000", "Teacher Y started Class Z").
 * Notifications & Settings: A dedicated space for alerts (fee reminders, system alerts).
Expanded UI Details (Filling the gaps):
 * Date Filter: The dashboard needs a global date toggle (Today, This Week, This Month) so the admin can see stats contextually.
 * Pending Actions Widget: A specialized alert card for immediate attention (e.g., "5 students have overdue fees," or "Batch X has no assigned teacher").
2. Students Module
Goal: Comprehensive CRUD (Create, Read, Update, Delete) management for student records.
From your notes:
 * Overview Metrics: Total / Active / Pending fees across the student body.
 * Student List & Search: A master list with a prominent search bar.
 * Filters: Filter by Name, Batch, Fees Pending, and Attendance status.
 * Profile Page (On Tap): Tapping a student opens their full profile.
   * Parent details.
   * Batch assignment.
   * Fee history and current status.
   * Attendance score.
   * Edit Functionality: Ability to change details, which must instantly sync to all apps.
 * Add Student: A clear action to onboard new users.
Expanded UI Details (Filling the gaps):
 * List View UI: Each row in the student list should have quick-glance visual indicators (e.g., a red dot for overdue fees, a green dot for active status).
 * Bulk Actions: Checkboxes next to student names to send bulk SMS/Push notifications (e.g., class cancellations) or assign multiple students to a batch at once.
 * Empty States: If no students match a search, show a friendly "No students found" graphic with a quick "Add Student" button.
3. Fees Management Module
Goal: Financial tracking, offline collection, and revenue follow-ups.
From your notes:
 * Financial Dashboard: Total Revenue, Pending Dues, and Overdue amounts.
 * Filtering: Filter fees by all students, specific batches, classes, or payment status.
 * Offline Collection Flow ("Add"):
   * Select Student & Batch.
   * Input Total Amount given.
   * Select Payment Method (Cash, UPI, Cheque, etc.).
   * Save and update everywhere.
[21-03-2026 07:34] Ardenyx: * Discounts: Ability to apply discount logic to a fee structure.
 * Fees Alert Button: A trigger to send automated reminders for pending/overdue payments.
 * Student Click-Through: Clicking a student from the fee list opens their full fee history.
Expanded UI Details (Filling the gaps):
 * Receipt Generation: After logging an offline payment, the UI should offer an automatic "Generate/Share Receipt" modal (via WhatsApp or Email).
 * Transaction History Tab: A simple ledger view showing a chronological list of all payments received, separate from the student list.
 * Export Data: A crucial feature for admins to export fee data as a CSV or Excel file for their accountants.
4. Batches Module
Goal: Organizing classes, assigning resources, and managing schedules.
From your notes:
 * Overview: Counter for Active vs. Total batches.
 * Create New Batch Flow:
   * Batch Name.
   * Class / Subject.
   * Enrollment Limit (Capacity).
   * Fees structure.
   * Faculty assignment (supports multiple teachers).
   * Start and End dates.
 * Batch Actions: Delete or temporarily suspend a batch.
 * Batch Edit/Detail Page (On Tap):
   * Thumbnail/Cover Image.
   * Description.
   * Assigned Teachers.
   * FAQs (Great addition for student apps to read).
   * Classes/Schedule list.
   * Quizzes assigned to the batch.
   * Enrolled Student List.
Expanded UI Details (Filling the gaps):
 * Timetable Integration: Inside the Batch detail page, a calendar UI or weekly timetable view showing exactly when the classes happen.
 * Batch Status Badges: Visual tags on the list view indicating "Filling Fast," "Full," or "Completed."
 * Promote/Migrate: An action button to easily migrate a whole batch of students to the next level when the current batch's end date passes.
5. Teacher Module
Goal: Staff management, tracking activity, and monitoring attendance.
From your notes:
 * Teacher List: Scrollable list of faculty.
   * Long tap to delete: Quick action for removing a profile.
 * Teacher Profile (On Tap):
   * Editable profile details.
   * List of batches they are assigned to.
   * Teacher's attendance in their assigned classes.
   * Recent activity timeline (what they've updated or taught recently).
 * "Other options also necessary"
Expanded UI Details (Filling the gaps for "Other options"):
 * Add Teacher: A dedicated onboarding form for new staff (Name, Subject Expertise, Contact, Salary/Revenue Share details).
 * Permission Toggles: Since this is an admin app, the teacher profile should have toggles for what the teacher can access (e.g., "Can edit attendance," "Can see fee data," "Can upload study material").
 * Performance/Feedback: A section in their profile summarizing student ratings or feedback for that specific teacher.







 # Excellence — Admin Role UI Redesign Specification
## Complete Screen-by-Screen Redesign Guide
**Version:** 2.0 | **Role:** Admin Only | **Platform:** Flutter Mobile (9:16)

---

## WHAT WE ARE CHANGING AND WHY

Your current UI (v1) is a **good start but not good enough to sell**. Here is exactly what is wrong and what we are replacing:

| Current Problem | What It Looks Like | What We Replace With |
|---|---|---|
| Revenue chart renders empty | Blank area with just month labels | Actual bars that render with real data |
| Student list is a spreadsheet | Column headers like a web table | Clean list rows, no headers |
| Student rows are too tall | Phone number, roll, batch all stacked | Single line name + batch only |
| Quick actions are not a grid | 3 separate sections of buttons | One intentional asymmetric block |
| Stat cards get cut off | No scroll affordance visible | Fade-to-white edge on right side |
| Activity icons too saturated | Solid dark circles | Light tint circles (very light bg) |
| Student photo left-aligned | Looks accidental, not designed | Centered in header OR left-aligned with name right |
| Info card fields too spaced | Giant gaps between label and value | Tight key-value list |

---

## BRAND COLORS — DO NOT CHANGE THESE

```
Navy:        #0D1282   → AppBar, primary buttons, headings, active state
Light Grey:  #EEEDED   → Input fills, chip bg, shimmer, inactive
Yellow:      #F0DE36   → ONE alert per screen only. Never as card bg fill.
Red:         #D71313   → Overdue, absent, error ONLY. Never decorative.

Page BG:     #F4F5FA   → Slightly cool white. Not #EEEDED, not pure white.
Card BG:     #FFFFFF   → Pure white cards on #F4F5FA
Text Dark:   #0A0C1E   → Primary text (navy-tinted near black)
Text Mid:    #4B5073   → Secondary text, descriptions
Text Muted:  #8F97B8   → Captions, timestamps, labels
Border:      #E3E4EE   → Card borders, dividers
Success:     #16A34A   → Paid, present, active
Warning:     #D97706   → Pending, partial
```

---

## TYPOGRAPHY — DO NOT CHANGE THESE

```
Font: Inter (keep what you have)

Display:  32px  SemiBold  #0A0C1E   Big stat numbers
H1:       22px  SemiBold  #0A0C1E   Page titles
H2:       18px  SemiBold  #0A0C1E   Section headings
H3:       16px  Medium    #0A0C1E   Card titles
Body:     14px  Regular   #4B5073   Descriptions
Caption:  12px  Regular   #8F97B8   Timestamps, muted info
Label:    11px  Medium    #8F97B8   ALL CAPS + letter-spacing: 1.2px
Mono:     16px  SemiBold  #0D1282   Fee amounts, big numbers with ₹
```

---

## SPACING SYSTEM — STICK TO THESE VALUES

```
Page horizontal padding:  20px
Section vertical gap:     24px
Card internal padding:    16px
List row height:          64px
List row padding:         0px 20px
Icon size (functional):   20px
Icon size (nav):          24px
Avatar (list):            40px circle
Avatar (profile header):  72px circle
Corner radius — card:     16px
Corner radius — chip:     20px (full pill)
Corner radius — button:   12px
Corner radius — input:    10px
Corner radius — small:    8px
```

---

## BOTTOM NAVIGATION — REDESIGN THIS

### Current Problem
Active tab shows a yellow dot below icon — good idea but implementation is inconsistent.

### New Spec

```
Height: 64px + bottom safe area (device dependent)
Background: #FFFFFF
Top border: 0.5px #E3E4EE

5 Tabs:
  1. Home       → HouseSimple icon (Phosphor)
  2. Students   → Users icon (Phosphor)
  3. Fees       → CurrencyInr icon (Phosphor)  ← NEW separate tab
  4. Batches    → BookOpen icon (Phosphor)      ← NEW separate tab
  5. More       → DotsThreeOutline icon (Phosphor)

Active tab state:
  Icon color: #0D1282 (Navy)
  Label: 10px SemiBold #0D1282
  Indicator: 3px × 24px rounded pill at BOTTOM of tab
             Color: #F0DE36 (Yellow)
             Centered under icon

Inactive state:
  Icon color: #8F97B8
  Label: 10px Regular #8F97B8

NOTE: The yellow indicator at BOTTOM is better than a dot above.
It is the underline of the whole app. Feels intentional.
```

### "More" Menu (Bottom Sheet — opens from More tab)

```
Handle: 4px × 36px #EEEDED centered at top

Grid of options — 3 columns:

Row 1: [Teachers] [Exams] [Timetable]
Row 2: [Reports] [Announcements] [Settings]
Row 3: [Staff & Pay] [Leads] [Audit Log]

Each option:
  64px × 64px square, 12px radius
  Background: #F4F5FA
  Icon: 24px center #0D1282
  Label: 11px center #4B5073 below icon

Do NOT use the hamburger menu. Bottom sheet is more natural on mobile.
```

---

## SCREEN 1 — DASHBOARD (COMPLETE REDESIGN)

### AppBar

```
Background: #0D1282 (Navy solid — not gradient)
Height: 72px

LEFT:
  Avatar circle — 44px
  Background: random from [#F0DE36, #16A34A, #D71313] (assigned once, stays)
  Text: Admin's initials, 16px SemiBold White
  Tap: opens admin profile sheet

CENTER:
  Line 1: "Good Morning, Rajan 👋"
          16px Medium White
  Line 2: "Sunrise Coaching · Indore"
          12px Regular rgba(255,255,255,0.55)

RIGHT:
  Notification bell icon (Phosphor) — White — 24px
  Badge: if notifications exist → 8px red dot at top-right of icon
         Do NOT show number inside dot — just presence indicator
```

### Stat Cards — HORIZONTAL SCROLL ROW

```
Container: horizontal scroll, 20px left padding start, 8px right
No ScrollBar visible
Fade-to-white gradient on right edge (40px wide, white to transparent)
This tells the user to scroll → very important UX

Card size: 148px wide × 88px tall
Card bg: #FFFFFF
Border: 1px #E3E4EE
Corner: 14px
Inner padding: 14px

Right side of last card: 20px empty card-shaped spacer
(so last card can scroll fully into view — common mistake)

--- CARD 1: Students ---
  Top: "STUDENTS" — 10px ALL CAPS #8F97B8 letter-spacing 1.2px
  Center: "284" — 32px SemiBold #0A0C1E
  Bottom: "↑ 3 this week" — 12px #16A34A with small upward arrow icon

--- CARD 2: Pending Fees ---
  Left border: 3px solid #D71313 (Red — signals urgency)
  Top: "PENDING FEES" — 10px ALL CAPS #8F97B8
  Center: "₹48,200" — 28px SemiBold #D71313
  Bottom: "23 students" — 12px #4B5073

--- CARD 3: Attendance ---
  Top: "TODAY" — 10px ALL CAPS #8F97B8
  Center: "86%" — 32px SemiBold #0D1282
  Bottom: "3 absent · 6/7 batches" — 12px #4B5073

--- CARD 4: Revenue ---
  Top: "THIS MONTH" — 10px ALL CAPS #8F97B8
  Center: "₹1.2L" — 30px SemiBold #0A0C1E
  Bottom: "↑ 12% vs last month" — 12px #16A34A

--- CARD 5: Teachers ---
  Top: "TEACHERS" — 10px ALL CAPS #8F97B8
  Center: "7" — 32px SemiBold #0A0C1E
  Bottom: "All active today" — 12px #8F97B8

--- CARD 6: Classes Today ---
  Top: "CLASSES TODAY" — 10px ALL CAPS #8F97B8
  Center: "8" — 32px SemiBold #0A0C1E
  Bottom: "Next: 4:00 PM Physics" — 12px #4B5073
```

### Alert Banners — SHOW BELOW STAT CARDS

```
Rule: Only show if condition is true. Never show empty or placeholder state.

--- UNMARKED ATTENDANCE (Yellow) ---
Show when: any batch has not marked attendance for today

Background: #FFFBEB
Border left: 3px #F0DE36
Corner: 12px
Padding: 12px 16px
Height: auto

Content:
  Row: [Warning icon 16px #D97706] + ["Attendance not marked" 14px Medium #92400E]
  Below: "Class 12 PCM, Class 11 Commerce" 12px #4B5073
  Right: "Mark Now →" 12px SemiBold #0D1282 — tappable


--- OVERDUE FEE (Red) ---
Show when: any student has overdue status

Background: #FFFFFF
Border left: 4px #D71313
Corner: 12px
Shadow: 0px 2px 8px rgba(215,19,19,0.08)
Padding: 14px 16px

Content top row:
  [● URGENT] — 10px ALL CAPS #D71313 with 6px red dot
  Right: "View All →" 12px #0D1282

Content:
  "23 students have overdue fees" 15px SemiBold #0A0C1E
  "Total outstanding ₹48,200" 13px #4B5073

Button row:
  [Send WhatsApp Reminder] — Navy filled pill button, full width, 44px
  14px Medium White
  Icon: WhatsApp icon left 16px
```

### Quick Actions — ASYMMETRIC LAYOUT (FIX THIS NOW)

```
Section label: "QUICK ACTIONS" 11px ALL CAPS #8F97B8 letter-spacing 1.2px

Layout: 
  ROW 1 (height 88px):
    LEFT card (62% width):
      Background: #0D1282 (Navy filled)
      Icon: UserPlus 24px White
      Title: "Add Student" 16px SemiBold White
      Sub: "Enroll new student" 12px rgba(255,255,255,0.55)
      Corner: 14px

    GAP: 10px

    RIGHT card (38% width):
      Background: #FFFFFF border 1px #E3E4EE
      Icon: CurrencyInr 22px #0D1282
      Title: "Collect" 13px SemiBold #0A0C1E center
      Sub: "Fee" 13px SemiBold #0A0C1E center
      (title + sub together = "Collect Fee" on two lines, centered)
      Corner: 14px

  GAP: 10px

  ROW 2 (height 88px):
    LEFT card (38% width):
      Background: #FFFFFF border 1px #E3E4EE
      Icon: ClipboardText 22px #0D1282
      Title: "Mark" 13px SemiBold #0A0C1E center
      Sub: "Attendance" 12px #4B5073 center
      Corner: 14px

    GAP: 10px

    RIGHT card (62% width):
      Background: #F4F5FA
      Border: 1px #E3E4EE
      Icon: Megaphone 22px #4B5073
      Title: "Send Announcement" 14px SemiBold #0A0C1E
      Sub: "Reach all batches instantly" 12px #8F97B8
      Corner: 14px
```

### Revenue Trend — FIX THE EMPTY CHART

```
Section label: "REVENUE — LAST 6 MONTHS" 11px ALL CAPS #8F97B8

Right of label: "₹6.4L total" 13px SemiBold #0D1282 (right aligned)

Chart area: height 120px, full width, padding 0px 20px

Bar chart spec:
  6 bars: Jan, Feb, Mar, Apr, May, Jun
  Bar width: 24px each
  Bar corner radius: 4px top only
  Space between bars: (available width - 6×24px) / 5 — equal gaps
  
  Color rules:
    Past months bars: #0D1282 (Navy) at 70% opacity
    Current month bar: #F0DE36 (Yellow) at 100% opacity ← stands out
    
  Heights are proportional to actual data values
  If no data yet → show shimmer placeholder bars

Month labels below each bar:
  "Jan" "Feb" etc — 10px #8F97B8 centered under each bar

Y-axis: NO grid lines. ONE label at top-left: peak value (e.g. "₹1.5L")
        10px #8F97B8

Below chart: thin separator 0.5px #E3E4EE

Below separator: two numbers side by side
  Left: "₹1,20,000 collected" 13px Medium #0A0C1E
  Right: "₹30,000 pending" 13px Medium #D97706 (warning amber)
  Divider: 1px vertical #E3E4EE between them, centered
```

### Today's Schedule Strip

```
Section label: "TODAY'S SCHEDULE" 11px ALL CAPS #8F97B8

Horizontal scroll row
Each event card: 140px wide × 70px tall

Card structure:
  Top: Day badge pill — "TODAY 4PM" 10px SemiBold #0D1282 on #EEF0FF bg
  Middle: Batch name — "Class 12 PCM" 13px Medium #0A0C1E
  Bottom: Teacher — "Ankit Joshi" 11px #8F97B8

Left border (3px) color depends on batch subject:
  Physics/PCM:   #0D1282 (Navy)
  Biology/NEET:  #16A34A (Green)
  Exam:          #D71313 (Red)
  Holiday:       #F0DE36 (Yellow)

Card BG: #FFFFFF
Border: 1px #E3E4EE
Corner: 12px
```

### Recent Activity

```
Section label: "RECENT ACTIVITY" 11px ALL CAPS #8F97B8
Right: "See all" 12px #0D1282

Style: List rows — NO card wrappers. Separator lines only.

Each row (64px height, 0px 20px padding):
  LEFT: Icon circle — 36px
    Background: light tint version of semantic color
      Fee collected → #DCFCE7 (light green) + ₹ icon #16A34A
      Student added → #EEF0FF (light navy) + UserPlus icon #0D1282
      Absent today  → #FEF2F2 (light red) + X icon #D71313
      Announcement  → #FFFBEB (light yellow) + Megaphone icon #D97706

  CENTER:
    Line 1: "Fee collected — Aryan Sharma" 14px Medium #0A0C1E
    Line 2: "₹3,500 · Cash · Class 12 PCM" 12px #8F97B8

  RIGHT:
    "2m ago" 11px #8F97B8

  SEPARATOR: 0.5px #E3E4EE
             Starts from left edge of text (not from icon) — important detail
             Feels deliberate, not mechanical

Max 5 rows shown. "See all activity →" text link below, centered, 13px #0D1282
```

---

## SCREEN 2 — STUDENT LIST (FULL REDESIGN)

### AppBar

```
Background: #0D1282
Back arrow: White (if navigated from elsewhere)
Title: "Students" 20px SemiBold White centered
Right icons: Filter (Funnel) + Add (UserPlus) — both White 24px

Below AppBar (White bg):
  Search bar — full width, 20px horizontal margin, 12px top margin
  Height: 46px
  Background: #EEEDED
  Corner: 10px
  Left: MagnifyingGlass icon 18px #8F97B8
  Placeholder: "Search name, phone, batch..." 14px #8F97B8
  On focus: border 1.5px #0D1282, background #FFFFFF
```

### Filter Chips

```
Horizontal scroll, 20px left padding, 12px vertical margin
No scrollbar

--- CHIP TYPES ---

Category chips (single select):
  [All 284]  [Active]  [Inactive]

Status chips (multi-select, can combine):
  [Fee Due]  [Overdue]  [Below 75%]

Batch chips (single select):
  [Class 11 PCM]  [Class 12 PCM]  [NEET Dropper]

--- CHIP STYLES ---

Default chip:
  BG: #EEEDED
  Text: 12px #4B5073
  Height: 32px, pill shape

Active/selected chip:
  BG: #0D1282
  Text: 12px White
  Height: 32px

Fee Due / Overdue chip:
  BG: #FEF2F2
  Text: 12px #D71313
  Border: 1px #D71313

Below 75% chip:
  BG: #FFFBEB
  Text: 12px #D97706
  Border: 1px #F0DE36

Count badge inside chip:
  "All 284" — the number is medium weight, the label regular
```

### Student List — THIS IS THE BIG FIX

```
REMOVE THE TABLE HEADER COMPLETELY.
"STUDENT INFO | BATCH & CONTACT | FEE STATUS | ATTEND" — DELETE THIS.
It makes the app look like an Excel sheet.

Each student row — 68px height:
  Left padding: 20px
  Right padding: 20px

  AVATAR (40px circle):
    Shows 2 initials of student name
    Color palette — rotate through (assigned based on student ID, not random each load):
      Navy #0D1282 + White text
      Success #16A34A + White text
      Purple #7C3AED + White text
      Amber #D97706 + White text
      Teal #0891B2 + White text
    If photo uploaded: show photo instead of initials

  CENTER AREA:
    Line 1: Student name — 15px Medium #0A0C1E
    Line 2: Batch name — 12px Regular #8F97B8

    NOTE: NO phone number here. NO roll number here.
    These go on the profile page only.
    Keep the list clean.

  RIGHT AREA:
    TOP: Fee status badge — pill, 28px height
      "PAID"    → BG #F0FDF4  Text #16A34A Border #BBF7D0  10px Medium
      "PENDING" → BG #FFFBEB  Text #D97706 Border #FDE68A  10px Medium
      "OVERDUE" → BG #FEF2F2  Text #D71313 Border #FECACA  10px Medium
      "PARTIAL" → BG #F5F3FF  Text #7C3AED Border #DDD6FE  10px Medium

    BOTTOM: Attendance percentage
      "94%" — 13px SemiBold #0D1282
      Small thin bar below (4px height, 36px wide):
        Filled: #0D1282 (proportional to %)
        Unfilled: #E3E4EE
        Corner: 2px
        If < 75%: filled bar color changes to #D71313 (Red)

SEPARATOR:
  0.5px #E3E4EE
  Starts from text area left edge (not from avatar left edge)
  This detail makes it feel premium

OVERDUE ROWS:
  Very subtle: background tint #FEF9F9 (barely visible red tint)
  Just enough to notice without being aggressive
```

### Swipe Actions on Student Row

```
SWIPE LEFT reveals:

Action 1 (rightmost, 64px wide):
  BG: #D71313 (Red)
  Icon: Bell 20px White
  Label: "Remind" 10px White

Action 2 (72px wide):
  BG: #0D1282 (Navy)
  Icon: CurrencyInr 20px White
  Label: "Collect" 10px White

Action 3 (64px wide):
  BG: #8F97B8 (Muted)
  Icon: Pencil 20px White
  Label: "Edit" 10px White

Reveal animation: smooth spring physics, not linear
```

### Pagination — REPLACE THE WEB PAGINATION

```
Remove: "Showing 1-5 of 124 students < >" — this is web UI

Replace with: Infinite scroll
  As user scrolls to bottom → auto-load next 20 students
  Loading state: 3 skeleton rows (shimmer in #EEEDED)
  
  At absolute bottom (all loaded):
    "All 284 students loaded" — 12px #8F97B8 centered
    with a thin 0.5px line either side of text
```

### FAB

```
Position: Bottom right, 24px from bottom, 24px from right
Size: 56px circle
BG: #0D1282
Icon: UserPlus 24px White
Shadow: 0px 6px 20px rgba(13,18,130,0.30)

On scroll down: FAB collapses to just the icon (no label needed)
On scroll up: FAB expands to show "Add Student" label → pill shape
This is called an Extended FAB collapse — common pattern
```

---

## SCREEN 3 — STUDENT PROFILE (REDESIGN)

### Header — FIX THE PHOTO POSITION

```
Background: #0D1282 (Navy, 200px tall)

THIS IS THE CURRENT PROBLEM:
Photo is under the back arrow, left-aligned → looks accidental

NEW LAYOUT — Option A (Centered — recommended):
  Back arrow: top-left, White
  
  Centered below back arrow (vertically):
    Avatar 72px circle
      White border 3px
      Photo or initials
    
    Name: "Aryan Sharma" 22px SemiBold White (centered below avatar)
    Batch + Status: "Class 12 PCM · Active" 13px rgba(255,255,255,0.65) centered
  
  Yellow dot: top-right of screen, 10px circle #F0DE36
              This indicates "active student"
              Position: absolute top-right 20px from each edge

NEW LAYOUT — Option B (Left-aligned with name right):
  Back arrow top-left
  
  Left: Avatar 64px circle (white border 3px), positioned 20px from left
  Right of avatar: 
    Name: 20px SemiBold White
    Batch: 13px rgba(255,255,255,0.65)
    Status pill: "Active" 10px White on rgba(255,255,255,0.15) bg

PICK ONE and be consistent across all profile pages in the app.
Recommendation: Option A (centered) — more premium feeling.
```

### Stat Pills Below Header

```
3 pills, horizontally centered, overlap the header bottom by 16px (they float)
BG: #FFFFFF
Shadow: 0px 2px 8px rgba(13,18,130,0.12)
Corner: 20px (pill)
Height: 32px
Padding: 8px 14px

Pill 1: [Calendar icon 14px #0D1282] "94% Attend." 13px Medium #0A0C1E
Pill 2: [Trophy icon 14px #D97706] "Rank #3" 13px Medium #0A0C1E
Pill 3: [CurrencyInr icon 14px #16A34A] "₹0 Due" 13px Medium #0A0C1E

Gap between pills: 8px
```

### Tab Bar

```
4 tabs: Overview | Fees | Attendance | Exams

BG: #FFFFFF
Border bottom: 0.5px #E3E4EE
Tab height: 46px

Active tab:
  Label: 14px SemiBold #0D1282
  Indicator: 3px underline #F0DE36 (Yellow — NOT Navy)
  Width: matches text width + 8px each side

Inactive tab:
  Label: 14px Regular #8F97B8
```

### Overview Tab

```
Section: PERSONAL INFORMATION

Header row:
  Left: "Personal Information" 16px SemiBold #0A0C1E
  Right: "Edit ✏" 13px #0D1282 — tappable

Card (BG: #FFFFFF, 16px radius, 1px border #E3E4EE):
  Internal padding: 16px

  Each field row (44px height):
    Left: Label — "PHONE NUMBER" 10px ALL CAPS #8F97B8 letter-spacing 1px
    Right: Value — "+91 98765 43210" 14px Medium #0A0C1E right-aligned

    SEPARATOR: 0.5px #E3E4EE full width BETWEEN rows
               No separator after last row

    Fields in order:
      PHONE NUMBER
      GENDER
      DATE OF BIRTH
      ENROLLMENT DATE
      PARENT / GUARDIAN
      PARENT PHONE
      EMAIL ADDRESS
      ADDRESS (this one can be 2 lines — row height auto)

  IMPORTANT: Tighten spacing. Currently too spread out.
  Label and value in same row, NOT stacked.
  Stacked layout = wasteful space.

Section: ENROLLED BATCHES

Header: "Enrolled Batches" 16px SemiBold #0A0C1E

Each batch row (60px height):
  Left: Square icon (48px × 48px, 10px corner)
    Background: batch subject color (fixed palette):
      Maths: #0D1282 (Navy) with Sigma icon White
      Physics: #D97706 (Amber) with Lightning icon White
      Chemistry: #16A34A (Green) with Flask icon White
      Biology: #D71313 (Red) with Leaf icon White
      Commerce: #7C3AED (Purple) with ChartBar icon White
    → Consistent across whole app. Same subject = same color everywhere.

  Center:
    Line 1: "Advanced Mathematics" 14px Medium #0A0C1E
    Line 2: "Mon, Wed, Fri · 4:00 PM" 12px #8F97B8

  Right: Chevron right 16px #8F97B8

  SEPARATOR between rows: 0.5px #E3E4EE starting from text left
```

### Fees Tab

```
Summary strip (3 mini-cards, horizontal row, 8px gaps):

Each card (⅓ width − gaps, 64px height):
  Corner: 12px
  BG: #FFFFFF, border 1px #E3E4EE

  Top: label 10px ALL CAPS #8F97B8
  Bottom: amount 18px SemiBold

  Card 1 — TOTAL PAID:   ₹18,000  color #0A0C1E
  Card 2 — PENDING:      ₹3,500   color #D97706  left-border 3px #D97706
  Card 3 — OVERDUE:      ₹0       color #16A34A  (zero = success color)

Fee history list:

Section label: "PAYMENT HISTORY" 11px ALL CAPS #8F97B8

Each row (56px height):
  Left: Month — "January 2025" 14px Medium #0A0C1E
  Center: "Class 12 PCM" 12px #8F97B8
  Right top: "₹3,500" 15px SemiBold (color based on status)
  Right bottom: Date + Status badge

  Status badge (tiny, 22px height):
    Same pill styles as student list

  Separator: 0.5px #E3E4EE from left text to right edge

Sticky bottom:
  "Collect Fee" button
  BG: #0D1282, White text, 52px height, 12px corner, 20px margins
  Full width minus margins
  Taps → opens the Collect Fee bottom sheet
```

### Attendance Tab

```
Month navigation:
  "< February 2025 >"
  Left/right arrows: 24px #0D1282
  Month name: 16px SemiBold #0A0C1E
  Year: 16px Regular #4B5073

Summary chips (one row):
  [✓ Present 22]  [✗ Absent 3]  [◔ Late 1]  [○ Leave 0]
  Each pill: colored appropriately
  Height: 28px

Calendar heatmap (7 columns × 4-5 rows):
  Each day: 36px × 36px square, 4px corner
  
  Colors:
    Present → #0D1282 Navy
    Absent  → #D71313 Red
    Late    → #F0DE36 Yellow (#0A0C1E text for contrast)
    Leave   → #8F97B8 Grey
    No class (holiday) → #F4F5FA with dashed border
    Future  → #EEEDED
    No data → empty (transparent)
  
  Day number inside square: 11px (color: white if dark bg, dark if light bg)

Summary stat below calendar:
  "22 Present · 3 Absent · 88% Attendance" 
  14px #4B5073 centered
  
  "Below 75% threshold" warning:
    Show only if < 75%
    Yellow pill: "⚠ Low Attendance" BG #FFFBEB Text #D97706
```

### Exams Tab

```
Each exam card (full width, margin 0px 20px):
  BG: #FFFFFF, 12px corner, 1px border #E3E4EE
  Padding: 14px

  Top row:
    Left: Exam name "Unit Test 2 — Physics" 14px SemiBold #0A0C1E
    Right: Grade pill "A+" BG #F0FDF4 Text #16A34A

  Middle:
    "18 Feb 2025 · 50 marks total" 12px #8F97B8

  Bottom row:
    Left: "Marks: 44/50" 14px Medium #0A0C1E
    Center: "Rank #3 in batch" 13px #4B5073
    Right: thin vertical bar chart (5 dots showing score trend)
           Current exam dot: #F0DE36 (yellow — stands out)
           Others: #0D1282

Gap between exam cards: 10px
```

---

## SCREEN 4 — FEE COLLECTION BOTTOM SHEET (MINOR FIXES)

This is the best screen currently. Keep 90% of it. Fix these:

```
KEEP:
  ✓ Month chip selector with Navy fill
  ✓ Yellow late fee banner
  ✓ Payment mode 2×2 grid
  ✓ WhatsApp receipt toggle
  ✓ Bottom CTA button with amount

FIX:

1. Total Amount Card:
   Current: Plain grey box with big number
   
   Fix — Add context:
     Top: "TOTAL AMOUNT · JANUARY 2025" 10px ALL CAPS #8F97B8
     Center: "₹ 3,500" 32px SemiBold #0A0C1E
     Bottom: "Base fee ₹3,400 + Late fee ₹100" 12px #4B5073
   
   Also: if only 1 month selected → no change
         if 3 months selected → "₹10,500 · 3 months selected" below

2. Payment Mode — Change 2×2 grid:
   Current: equal 2×2 squares
   
   Fix: Make it a horizontal chip row instead
   [💵 Cash] [📱 UPI] [💳 Card] [🏦 Bank]
   
   Height: 44px each, equal width, pill or 8px corner
   Selected: Navy BG + White icon + White text
   Unselected: #FFFFFF border 1px #E3E4EE
   
   This is more compact and feels more native.

3. Transaction ID field:
   Show/hide based on mode:
     Cash → hide
     UPI → show "Transaction ID / UPI Ref" field
     Card → show "Last 4 digits" field
     Bank → show "UTR Number" field
   
   Smooth animation when field appears/disappears.

4. Bottom CTA:
   Current: "Collect ₹3,500 →"
   
   Fix — Be more specific:
     If 1 month: "Collect ₹3,500 for January →"
     If 3 months: "Collect ₹10,500 for Jan–Mar →"
   
   This confirms what the admin is doing.
```

---

## SCREEN 5 — ATTENDANCE MARKING (REDESIGN)

### AppBar

```
Background: #FFFFFF (Light nav — this page is operational, not branding)
Back arrow: #0D1282
Title: "Mark Attendance" 18px SemiBold #0A0C1E
Subtitle: "Class 12 PCM · 18 Feb 2025" 12px #8F97B8 centered below

Right: Calendar icon #0D1282 (tap to change date)

Status bar: if marking PAST date:
  Yellow strip below AppBar:
  "⚠ Marking for 15 Feb 2025 (not today)" 12px #92400E BG #FFFBEB
```

### Summary Bar

```
Sticky below AppBar (stays visible while scrolling)
BG: #FFFFFF
Border bottom: 0.5px #E3E4EE
Padding: 10px 20px

4 chips in a row:
  [✓ Present 28] [✗ Absent 3] [◔ Late 1] [○ Leave 0]
  
  Each updates live as you tap students
  
  Colors:
    Present → BG #F0FDF4 Text #16A34A Border #BBF7D0
    Absent  → BG #FEF2F2 Text #D71313 Border #FECACA
    Late    → BG #FFFBEB Text #D97706 Border #FDE68A
    Leave   → BG #F4F5FA Text #4B5073 Border #E3E4EE
  
  Chip height: 30px, pill shape

Right side of bar: "Mark All P" — 12px #0D1282 tappable
  "P" = Present
  Tap: confirmation micro-dialog (2 seconds, dismissible)
       "Marking all 32 students as present. Undo?"
```

### Student List

```
Each row — 68px height, 20px horizontal padding

LEFT: Avatar 40px circle (initials, colored)

CENTER:
  Line 1: Student name — 15px Medium #0A0C1E
  Line 2: Roll # or batch position — 12px #8F97B8

RIGHT: Status selector — 4 buttons in a row
  Each button: 32px × 32px, 6px corner

  [P]  →  Present
    Default (unselected): BG #FFFFFF border 1px #E3E4EE, text 13px SemiBold #8F97B8
    Selected: BG #16A34A, text White
  
  [A]  →  Absent
    Selected: BG #D71313, text White
  
  [L]  →  Late
    Selected: BG #D97706, text White
  
  [V]  →  Leave (V for Vacation/Leave)
    Selected: BG #8F97B8, text White

  Gap between buttons: 4px

  IMPORTANT: When one is selected, other 3 go to very light ghost state
             Not hidden — just visually receded
             This is critical for scan-ability

Separator: 0.5px #E3E4EE

UNMARKED state: Row has subtle left indicator
  3px left border: #F0DE36 Yellow (means: this student not yet marked)
  Border disappears once any status is selected
  This is a powerful visual cue — at a glance admin sees who is unmarked
```

### Submit Button — Sticky Bottom

```
Position: Fixed at bottom, above navigation bar
BG: #FFFFFF
Padding: 12px 20px
Border top: 0.5px #E3E4EE

Submit button:
  Height: 52px
  BG: #0D1282 (active) / #EEEDED (inactive)
  Text: "Submit Attendance · 32 students" 15px SemiBold White
  Corner: 12px
  Full width (minus 40px total margins)

  Inactive state (not all students marked):
    BG: #EEEDED
    Text: "Mark all students first" 15px #8F97B8
    Tapping shows toast: "Please mark attendance for all students"

  Active state: all students have a status selected → button becomes Navy
```

---

## SCREEN 6 — FEE MANAGEMENT PAGE

### AppBar + Tabs

```
AppBar: #0D1282
Title: "Fee Management" White

Tabs below AppBar (white background):
  [Overview] [Records] [Reminders]
  Active: Yellow 3px underline, 14px SemiBold #0D1282
  Inactive: 14px Regular #8F97B8
  Height: 44px
```

### Overview Tab

```
Month navigation:
  "< February 2025 >" centered
  Left/right arrows: 20px #0D1282
  Month: 18px SemiBold #0A0C1E

3 summary cards (horizontal, 8px gaps):

  COLLECTED:
    BG: #F0FDF4, border 1px #BBF7D0
    Label: "COLLECTED" 10px ALL CAPS #16A34A
    Amount: "₹1,20,000" 20px SemiBold #16A34A
    Below: "84% of expected" 11px #4B5073

  PENDING:
    Left border: 3px #D97706
    BG: #FFFFFF, border 1px #FDE68A
    Label: "PENDING" 10px ALL CAPS #D97706
    Amount: "₹23,000" 20px SemiBold #D97706
    Below: "16 students" 11px #4B5073

  OVERDUE:
    Left border: 3px #D71313
    BG: #FFFFFF, border 1px #FECACA
    Label: "OVERDUE" 10px ALL CAPS #D71313
    Amount: "₹5,200" 20px SemiBold #D71313
    Below: "4 students" 11px #4B5073

Payment mode breakdown (below cards):
  Thin horizontal bar divided by payment mode:
    Navy = Cash (60%), Yellow tint = UPI (30%), Grey = Card (10%)
  
  Labels below: "Cash 60% · UPI 30% · Card 10%"
  12px #4B5073

Fee list (below breakdown):
  Filter chips: [All] [Paid] [Pending] [Overdue]

  Each row:
    Same as Student list row format:
    Avatar + Name + Batch | Amount | Status badge
    
    IMPORTANT: Sort order:
      Default: Overdue first, then Pending, then Paid
      This means the most urgent are always at top
    
    Overdue rows: #FEF9F9 tint background (barely visible)
    
    Swipe left: [Remind] [Collect] — same as student list

  Bottom: "Send Bulk WhatsApp Reminder" outline button
    Border 1px #0D1282, Text #0D1282
    "Send to 20 pending/overdue students"
    Height: 48px, full width minus 40px margins
    WhatsApp icon left of text
```

---

## SCREEN 7 — BATCH MANAGEMENT PAGE

### Batch List

```
AppBar: "Batches" + "+" add button White on Navy

Filter row:
  [All] [Active] [PCM] [Biology] [Commerce] [Test Series]
  Same chip style as student list

Each batch card (full width, 16px corner, 1px border #E3E4EE, BG #FFFFFF):
  Padding: 16px

  Top row:
    Left: Color dot 8px (subject color — consistent with batch icon colors)
    After dot: Batch name — "Class 12 PCM" 16px SemiBold #0A0C1E
    Right: Status pill "ACTIVE" BG #F0FDF4 Text #16A34A
  
  Middle row:
    Teacher avatar 28px + "Ankit Joshi" 13px #4B5073
    Separator dot · 
    "Mon, Wed, Fri · 4PM" 13px #4B5073
  
  Bottom row (stats in a row):
    👥 "32 students" 12px #4B5073
    | divider |
    🏢 "Room 3" 12px #4B5073
    | divider |
    📅 "Started Jan 2025" 12px #4B5073
  
  Gap between batch cards: 10px

Tap batch card → Batch Detail page

Long press card → context menu:
  [Edit] [Deactivate] [View Students] [Delete]
```

### Batch Detail Page

```
Header (Navy BG, 180px):
  Batch name: 24px SemiBold White
  Teacher: "Ankit Joshi · Physics" 14px rgba(255,255,255,0.65)

  3 stat pills (float overlapping header):
    [32 Students] [86% Avg Attend] [Active]

Tabs: Students | Schedule | Content | Reports

Students Tab:
  Mini student list (same format as main list but compacted)
  "Transfer Student" option on long press

Schedule Tab:
  Weekly timetable — 7 columns (Mon-Sun), rows per time slot
  Filled slots: Navy cell with batch name
  Empty slots: #F4F5FA
  Conflict: Red cell
  
Content Tab:
  Notes and assignments uploaded for this batch
  Same as teacher's content view

Reports Tab:
  Attendance % for each student in this batch
  Fee collection summary for this batch
  Avg score in exams for this batch
```

---

## SCREEN 8 — REPORTS / ANALYTICS PAGE

```
AppBar: "Reports" on #0D1282

Date filter row (sticky):
  [Today] [This Week] [This Month] [Custom]
  Same chip style, single select
  "Custom" → opens date range picker

Section: Revenue Overview
  Two big numbers, side by side:
    Left: "₹14.4L" 32px SemiBold #0A0C1E + "Total this year" 12px #8F97B8
    Divider: 1px vertical #E3E4EE
    Right: "₹1.2L" 24px SemiBold #0D1282 + "This month" 12px #8F97B8

  Bar chart (full width, 120px height) — same specs as dashboard
  Current month bar in Yellow.

Section: Attendance Overview
  "ATTENDANCE — FEBRUARY" label

  Batch-wise list:
    Each row: Batch name | % bar | % number
    Bar: 4px height, Navy filled on #EEEDED bg
    If < 75%: Red fill + red % number
    
    Sort: lowest % at top (most urgent first)

Section: Top Performing Students
  "TOP STUDENTS — THIS MONTH" label

  3 rows — podium style:
    Row 1: 🥇 Yellow trophy · Aryan Sharma · 94% attend · Avg 88/100
    Row 2: 🥈 Silver trophy · Priya Verma · 91% attend · Avg 85/100
    Row 3: 🥉 Bronze trophy · Sneha Patel · 89% attend · Avg 82/100
    
    Trophy icons: actual small icon, not emoji in production
    Use: Trophy icon (Phosphor), colored appropriately

Section: Fee Summary
  Donut chart — 140px diameter, centered
    Segments:
      Navy #0D1282 = Collected 72%
      Yellow #F0DE36 = Pending 18%
      Red #D71313 = Overdue 10%
    
    Center text: "₹1.43L" 18px SemiBold #0A0C1E
                 "collected" 11px #8F97B8 below

  Legend below chart (3 rows):
    [Color dot] Label [amount right] [percent right]

Export button at bottom of each section:
  "Export as CSV" — text link, 12px #0D1282
  Small Download icon left
```

---

## SCREEN 9 — ANNOUNCEMENT COMPOSER

```
AppBar: White background
Title: "New Announcement" 18px SemiBold #0A0C1E
Left: X (close) icon #0A0C1E
Right: "Send" 15px SemiBold #0D1282 (disabled grey until content filled)

Body (white card, no borders — feels like composing):

Section: SEND TO — 11px ALL CAPS #8F97B8

Recipient chips (multi-select, 3 rows):
  Row 1: [All Students] [All Teachers] [All Parents]
  Row 2: [Class 12 PCM] [Class 11 PCM] [NEET Dropper]
  Row 3: [Class 11 Commerce] → scrollable if more batches
  
  Selected chip: Navy BG + White text + ✓ tick icon left
  Unselected: #EEEDED BG + #4B5073 text

Section: SEND VIA — 11px ALL CAPS #8F97B8

3 toggle chips (each independent toggle):
  [In-App] [WhatsApp] [Both]
  Both = selected by default

Section: COMPOSE

Title input:
  No border, no background
  Placeholder: "Announcement title..." 22px Medium #EEEDED (placeholder color)
  Actual text: 22px SemiBold #0A0C1E
  Max: 80 characters

Body input:
  Placeholder: "Type your message..." 15px Regular #EEEDED
  Actual text: 15px Regular #4B5073
  Min height: 120px, expands
  Max: 500 chars
  Character count: "0/500" 11px #8F97B8 right-aligned below

Attachment row:
  "📎 Attach PDF" 13px #0D1282 · "🖼 Add Image" 13px #0D1282
  Both are text buttons, icon left
  Gap: 20px between them

Reach estimate card:
  Appears after selecting recipients
  BG: #EEF0FF (light navy tint)
  Corner: 10px, Padding: 12px
  
  "This will reach 284 students, 127 parents and 7 teachers"
  14px #0D1282 Medium
  Users icon left, 16px #0D1282

Schedule option:
  "Schedule for later →" 13px #4B5073 centered
  Tap → date + time picker bottom sheet

Bottom: "Send Now" button
  Full width minus 40px margins
  52px height, 12px corner
  Navy BG + White text
  Active only when: title filled + at least 1 recipient selected
```

---

## GLOBAL COMPONENTS — STANDARDIZE THESE

### Empty States (All Screens)

```
Each empty state:
  Simple line illustration — NOT Lottie, NOT 3D, NOT emoji
  
  Illustration style: 2px stroke, Navy #0D1282, 100px × 100px
  
  Title: "No students yet" 16px SemiBold #0A0C1E
  Sub: "Add your first student to get started" 14px #4B5073
  
  Primary button: "Add Student" — Navy, 48px, 12px corner, 200px wide
  
  Centered on screen, vertically middle.

Per screen:
  Students empty: Illustration of empty chair
  Fees empty: Illustration of empty wallet
  Attendance empty: Illustration of empty calendar
  Activity empty: Illustration of clock
```

### Loading States

```
Use skeleton screens — NOT spinners (spinners feel old)

Skeleton:
  Colored: #EEEDED
  Pulse animation: opacity 1.0 → 0.4 → 1.0, 1.2s loop
  
  Match exact shape of content:
    Student row skeleton: circle 40px + 2 lines (long + short) + pill
    Stat card skeleton: full card shape with 3 lines
    Chart skeleton: bar chart shapes at different heights

NEVER show a white screen with a spinner in the center.
```

### Toast / Snackbar

```
Position: Bottom, 16px above bottom nav
BG: #0A0C1E (near-black — universal)
Text: White 14px Medium
Corner: 8px
Padding: 14px 20px
Auto-dismiss: 3 seconds

With action:
  Text on right: "Undo" 14px #F0DE36 (Yellow)

Success variant:
  Left border: 3px #16A34A

Error variant:
  Left border: 3px #D71313

Max width: screen width minus 40px
```

### Confirmation Dialogs

```
NOT full-screen modals for simple confirmations.
Use bottom sheets instead.

Bottom sheet (destructive action):
  Handle bar at top
  
  Icon: Warning circle 40px, #FEF2F2 BG, #D71313 icon
  Title: "Deactivate Aryan Sharma?" 18px SemiBold #0A0C1E
  Sub: "They will lose access to the app. You can reactivate anytime." 14px #4B5073
  
  Buttons (full width, stacked):
    Primary (destructive): "Deactivate" BG #D71313 White text 52px
    Secondary: "Cancel" BG #EEEDED #4B5073 text 52px
    Gap: 10px

Bottom sheet (non-destructive):
  Same format but Primary button is Navy.
```

---

## WHAT TO TELL YOUR DEVELOPER

```
1. Remove the spreadsheet header from student list — TABLE HEADER DELETE KARO
2. Render the revenue chart bars — chart area mein actual bars add karo
3. Fix quick actions to asymmetric layout — 2+1 rows not 3 separate sections
4. Student row mein sirf naam aur batch — phone number student list se hatao
5. Student photo center karo profile page mein — currently left-aligned looks accidental
6. Info card mein label aur value ek hi row mein — stacked nahi horizontal
7. Activity feed circles light tint banana — solid dark circles nahi
8. Stat cards horizontal scroll ka right edge fade karo — scroll affordance
9. Replace pagination arrows with infinite scroll on student list
10. Add yellow 3px underline as bottom nav active indicator — dot theek hai par aur bhi
```

---

## SCREENS PRIORITY ORDER

Build/fix in this order:

1. **Dashboard** — Most seen screen. Fix chart + quick actions + alert banners.
2. **Student List** — Remove table header. Fix rows.
3. **Fee Collection Sheet** — Already good, just small fixes.
4. **Student Profile** — Fix photo position. Tighten info card.
5. **Attendance Marking** — Yellow unmarked indicator is new key feature.
6. **Fee Management Page** — Sort by urgency (overdue first).
7. **Batch Detail Page** — Currently missing entirely.
8. **Reports Page** — Analytics section, clean charts.
9. **Announcement Composer** — Reach estimate card is the key addition.

---

*neurovaX · Excellence Admin UI v2.0*  
*Designed to be sold. Built to last.*
