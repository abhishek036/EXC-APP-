-- Add duration_minutes to lectures so timetable create/read paths match the Prisma schema.
ALTER TABLE "lectures"
ADD COLUMN "duration_minutes" INTEGER DEFAULT 60;
