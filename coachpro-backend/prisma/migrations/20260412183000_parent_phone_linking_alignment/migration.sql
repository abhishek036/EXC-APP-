-- Parent-student phone-linking alignment (minimal + non-breaking)
-- 1) Normalize parent phone values to +91 format when safe.
-- 2) Add lookup index for one-parent-per-student service logic.

UPDATE users u
SET phone = '+91' || u.phone
WHERE u.role = 'parent'
  AND u.phone ~ '^[0-9]{10}$'
  AND NOT EXISTS (
    SELECT 1
    FROM users x
    WHERE x.institute_id = u.institute_id
      AND x.phone = '+91' || u.phone
      AND x.id <> u.id
  );

UPDATE parents p
SET phone = '+91' || p.phone
WHERE p.phone ~ '^[0-9]{10}$'
  AND NOT EXISTS (
    SELECT 1
    FROM parents x
    WHERE x.institute_id = p.institute_id
      AND x.phone = '+91' || p.phone
      AND x.id <> p.id
  );

CREATE INDEX IF NOT EXISTS idx_parent_students_student_id
  ON parent_students (student_id);
