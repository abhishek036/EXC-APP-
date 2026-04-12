ALTER TABLE "assignments"
ADD COLUMN "instructions" TEXT,
ADD COLUMN "max_marks" DECIMAL(6,2),
ADD COLUMN "allow_late_submission" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "late_grace_minutes" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "max_attempts" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN "allow_text_submission" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "allow_file_submission" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "max_file_size_kb" INTEGER NOT NULL DEFAULT 20480,
ADD COLUMN "allowed_file_types" TEXT[] NOT NULL DEFAULT ARRAY['pdf','jpg','jpeg','png','doc','docx']::TEXT[],
ADD COLUMN "correct_solution_url" TEXT,
ADD COLUMN "updated_at" TIMESTAMPTZ;

UPDATE "assignments" SET "updated_at" = NOW() WHERE "updated_at" IS NULL;

ALTER TABLE "assignment_submissions"
ADD COLUMN "attempt_no" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN "is_draft" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "is_latest" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "is_late" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "file_name" VARCHAR(255),
ADD COLUMN "file_mime_type" VARCHAR(120),
ADD COLUMN "file_size_kb" INTEGER,
ADD COLUMN "scan_status" VARCHAR(20) DEFAULT 'pending',
ADD COLUMN "draft_saved_at" TIMESTAMPTZ;

DROP INDEX IF EXISTS "assignment_submissions_assignment_id_student_id_key";
CREATE UNIQUE INDEX "assignment_submissions_assignment_id_student_id_attempt_no_key"
ON "assignment_submissions"("assignment_id", "student_id", "attempt_no");
CREATE INDEX "assignment_submissions_assignment_student_latest_idx"
ON "assignment_submissions"("assignment_id", "student_id", "is_latest");
CREATE INDEX "assignment_submissions_assignment_status_idx"
ON "assignment_submissions"("assignment_id", "status");

CREATE TABLE "assignment_feedbacks" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "assignment_id" UUID NOT NULL,
    "assignment_submission_id" UUID NOT NULL,
    "institute_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "reviewer_user_id" UUID,
    "marks_obtained" DECIMAL(6,2),
    "feedback_text" TEXT,
    "feedback_audio_url" TEXT,
    "annotated_file_url" TEXT,
    "rubric_json" JSONB,
    "revision_no" INTEGER NOT NULL DEFAULT 1,
    "is_latest" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "assignment_feedbacks_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "assignment_feedbacks_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "assignments"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "assignment_feedbacks_assignment_submission_id_fkey" FOREIGN KEY ("assignment_submission_id") REFERENCES "assignment_submissions"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "assignment_feedbacks_submission_revision_key"
ON "assignment_feedbacks"("assignment_submission_id", "revision_no");
CREATE INDEX "assignment_feedbacks_assignment_student_latest_idx"
ON "assignment_feedbacks"("assignment_id", "student_id", "is_latest");
CREATE INDEX "assignment_feedbacks_institute_latest_idx"
ON "assignment_feedbacks"("institute_id", "is_latest");
