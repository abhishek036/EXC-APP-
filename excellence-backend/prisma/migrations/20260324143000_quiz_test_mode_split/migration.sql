ALTER TABLE "quizzes"
ADD COLUMN IF NOT EXISTS "assessment_type" VARCHAR(10) NOT NULL DEFAULT 'QUIZ',
ADD COLUMN IF NOT EXISTS "scheduled_at" TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS "negative_marking" DECIMAL(4,2),
ADD COLUMN IF NOT EXISTS "allow_retry" BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS "show_instant_result" BOOLEAN DEFAULT true;

UPDATE "quizzes"
SET
  "assessment_type" = COALESCE("assessment_type", 'QUIZ'),
  "allow_retry" = COALESCE("allow_retry", true),
  "show_instant_result" = COALESCE("show_instant_result", true)
WHERE "assessment_type" IS NULL
   OR "allow_retry" IS NULL
   OR "show_instant_result" IS NULL;
