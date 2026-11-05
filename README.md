# QR Attendance System

A web-based attendance system for college classes. A teacher starts a class and shows a QR code. Students scan it on their phones and mark themselves present using a roll number and a personal PIN. Teachers get live updates, monthly percentages with low-attendance warnings, and an Excel export.

**Live demo:** https://amazing-pasca-124f6b.netlify.app

## Screenshots

_Add 2 or 3 screenshots here: the teacher screen with the QR code, the student phone page, and the monthly summary._

## Features

- Teacher login (email and password)
- Add and remove students, each with a roll number and PIN
- Start a class by subject and date; the QR code appears instantly
- Student marks attendance from their own phone, no login needed
- Live updates on the teacher screen
- Monthly summary with percentage per student and a warning below 75%
- Download the monthly report as an Excel file

## Anti-cheating measures

| Problem | Protection |
|---|---|
| Someone types a friend's roll number | Each student has a personal PIN |
| One phone marks many students | A device ID is saved per phone, and the database allows one student per phone per class |
| A QR screenshot is forwarded to someone outside the room | The QR code changes every 30 seconds and each code is valid for 60 seconds |
| Marking after class ends | Each class is open for 5 minutes, then the database refuses new marks |

All of these checks run **inside the database** (in a Postgres function), not in the browser, so editing the page in developer tools does not bypass them.

## Tech stack

- **Frontend:** HTML, CSS, JavaScript (single file, no framework)
- **Backend and database:** Supabase (PostgreSQL, Auth, Row Level Security, SQL functions)
- **Libraries:** supabase-js, qrcodejs, SheetJS (Excel export)
- **Hosting:** Netlify

## How it works

1. The teacher logs in and clicks **Start class**. A row is created in `classes` with a closing time 5 minutes ahead.
2. The browser creates a random token every 30 seconds and stores it in `class_tokens`. The QR code contains the class ID and the current token.
3. The student scans the QR, enters roll number and PIN, and the page calls the database function `mark_present`.
4. `mark_present` checks, in order: the class is open, the token is recent, the roll number and PIN match, and the phone has not marked a different student. Then it writes the attendance row.
5. Students have no direct access to any table. They can only call two functions, `get_class` and `mark_present`.

## Database design

- `students` (id, name, roll_no, pin)
- `classes` (id, subject, class_date, closes_at)
- `attendance` (id, student_id, class_id, status, device_id), with a unique rule on (student_id, class_id)
- `class_tokens` (id, class_id, token, created_at)

Row Level Security is enabled on every table. Logged-in teachers have full access through policies. The full schema is in [`schema.sql`](schema.sql).

## Run it yourself

1. Create a free project on [Supabase](https://supabase.com).
2. Run `schema.sql` in the Supabase SQL Editor.
3. In Authentication, create a teacher user and turn off public sign-ups.
4. Open `index.html` and replace `SB_URL` and `SB_KEY` with your project URL and anon (publishable) key.
5. Open the file with a local server (for example the VS Code Live Server extension), or upload it to Netlify.

## Known limitations and future improvements

- A student who shares their PIN with a friend sitting in the room can still be marked by someone else.
- Clearing browser data resets the phone ID.
- PINs are stored as plain text (readable only by teachers). A production version should hash them.
- There is no limit on wrong PIN attempts.
- A single teacher role; multiple classes per teacher and per-teacher data separation are not implemented.
- Adding location checks and per-student accounts would strengthen verification.

## What I learned

_Write 3 or 4 sentences in your own words here: what was hardest, what bug you fixed, and what you would build next._
