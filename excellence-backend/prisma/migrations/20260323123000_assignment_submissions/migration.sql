CREATE TABLE "assignment_submissions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "assignment_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "institute_id" UUID NOT NULL,
    "file_url" TEXT,
    "submission_text" TEXT,
    "status" VARCHAR(20) DEFAULT 'submitted',
    "marks_obtained" DECIMAL(6,2),
    "remarks" TEXT,
    "submitted_at" TIMESTAMPTZ DEFAULT now(),
    "reviewed_at" TIMESTAMPTZ,
    "reviewed_by_id" UUID,
    CONSTRAINT "assignment_submissions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "assignment_submissions_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "assignments"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "assignment_submissions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "assignment_submissions_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "assignment_submissions_reviewed_by_id_fkey" FOREIGN KEY ("reviewed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "assignment_submissions_assignment_id_student_id_key" ON "assignment_submissions"("assignment_id", "student_id");
CREATE INDEX "assignment_submissions_assignment_id_idx" ON "assignment_submissions"("assignment_id");
CREATE INDEX "assignment_submissions_student_id_idx" ON "assignment_submissions"("student_id");
CREATE INDEX "assignment_submissions_institute_id_idx" ON "assignment_submissions"("institute_id");
