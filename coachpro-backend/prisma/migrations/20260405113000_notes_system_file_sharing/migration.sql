ALTER TABLE "notes"
ADD COLUMN "description" TEXT,
ADD COLUMN "chapter_title" VARCHAR(150),
ADD COLUMN "chapter_order" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "is_deleted" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "deleted_at" TIMESTAMPTZ,
ADD COLUMN "updated_at" TIMESTAMPTZ;

UPDATE "notes" SET "updated_at" = NOW() WHERE "updated_at" IS NULL;

CREATE TABLE "note_files" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "note_id" UUID NOT NULL,
    "institute_id" UUID NOT NULL,
    "file_url" TEXT NOT NULL,
    "file_name" VARCHAR(255),
    "file_type" VARCHAR(20),
    "mime_type" VARCHAR(120),
    "file_size_kb" INTEGER,
    "storage_provider" VARCHAR(30),
    "storage_path" TEXT,
    "file_hash" VARCHAR(80),
    "version_no" INTEGER NOT NULL DEFAULT 1,
    "is_latest" BOOLEAN NOT NULL DEFAULT true,
    "is_deleted" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "note_files_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "note_files_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "notes"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "note_files_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "note_files_note_id_is_latest_idx" ON "note_files"("note_id", "is_latest");
CREATE INDEX "note_files_institute_file_type_idx" ON "note_files"("institute_id", "file_type");

INSERT INTO "note_files" (
    "note_id",
    "institute_id",
    "file_url",
    "file_name",
    "file_type",
    "file_size_kb",
    "version_no",
    "is_latest"
)
SELECT
    n."id",
    n."institute_id",
    n."file_url",
    split_part(n."file_url", '/', array_length(string_to_array(n."file_url", '/'), 1)),
    n."file_type",
    n."file_size_kb",
    1,
    true
FROM "notes" n;

CREATE TABLE "download_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "note_id" UUID NOT NULL,
    "note_file_id" UUID,
    "student_id" UUID,
    "institute_id" UUID NOT NULL,
    "action" VARCHAR(20) NOT NULL DEFAULT 'view',
    "ip_address" VARCHAR(64),
    "user_agent" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "download_logs_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "download_logs_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "notes"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "download_logs_note_file_id_fkey" FOREIGN KEY ("note_file_id") REFERENCES "note_files"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "download_logs_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "download_logs_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "download_logs_note_id_created_at_idx" ON "download_logs"("note_id", "created_at");
CREATE INDEX "download_logs_student_id_created_at_idx" ON "download_logs"("student_id", "created_at");
CREATE INDEX "download_logs_institute_id_action_idx" ON "download_logs"("institute_id", "action");

CREATE TABLE "note_bookmarks" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "note_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "institute_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "note_bookmarks_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "note_bookmarks_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "notes"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "note_bookmarks_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "note_bookmarks_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "note_bookmarks_note_id_student_id_key" ON "note_bookmarks"("note_id", "student_id");
CREATE INDEX "note_bookmarks_student_id_created_at_idx" ON "note_bookmarks"("student_id", "created_at");
CREATE INDEX "note_bookmarks_institute_id_idx" ON "note_bookmarks"("institute_id");
