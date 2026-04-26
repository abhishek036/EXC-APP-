-- AlterTable: make youtube_url nullable in lectures
ALTER TABLE "lectures" ALTER COLUMN "youtube_url" DROP NOT NULL;
