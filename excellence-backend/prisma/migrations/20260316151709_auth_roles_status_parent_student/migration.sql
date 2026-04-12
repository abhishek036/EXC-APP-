/*
  Warnings:

  - You are about to drop the column `is_primary` on the `parents` table. All the data in the column will be lost.
  - You are about to drop the column `relation` on the `parents` table. All the data in the column will be lost.
  - You are about to drop the column `student_id` on the `parents` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[join_code]` on the table `institutes` will be added. If there are existing duplicate values, this will fail.

*/
-- DropForeignKey
ALTER TABLE "parents" DROP CONSTRAINT "parents_student_id_fkey";

-- DropForeignKey
ALTER TABLE "teachers" DROP CONSTRAINT "teachers_user_id_fkey";

-- AlterTable
ALTER TABLE "institutes" ADD COLUMN     "join_code" VARCHAR(20);

-- AlterTable
ALTER TABLE "parents" DROP COLUMN "is_primary",
DROP COLUMN "relation",
DROP COLUMN "student_id";

-- AlterTable
ALTER TABLE "teachers" ADD COLUMN     "phone" VARCHAR(15),
ALTER COLUMN "user_id" DROP NOT NULL;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "status" VARCHAR(20) NOT NULL DEFAULT 'PENDING';

-- CreateTable
CREATE TABLE "parent_students" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "parent_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "relation" VARCHAR(20),
    "is_primary" BOOLEAN DEFAULT true,

    CONSTRAINT "parent_students_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "leads" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institute_id" UUID NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "phone" VARCHAR(15) NOT NULL,
    "status" VARCHAR(30) NOT NULL DEFAULT 'New',
    "created_at" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "leads_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institute_id" UUID NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "role" VARCHAR(100),
    "phone" VARCHAR(15),
    "salary" DECIMAL(10,2),
    "status" VARCHAR(30) DEFAULT 'active',
    "created_at" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "staff_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payroll" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institute_id" UUID NOT NULL,
    "staff_id" UUID NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "type" VARCHAR(30) NOT NULL,
    "month" VARCHAR(30),
    "date" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payroll_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "parent_students_parent_id_student_id_key" ON "parent_students"("parent_id", "student_id");

-- CreateIndex
CREATE UNIQUE INDEX "institutes_join_code_key" ON "institutes"("join_code");

-- AddForeignKey
ALTER TABLE "teachers" ADD CONSTRAINT "teachers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parent_students" ADD CONSTRAINT "parent_students_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "parents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parent_students" ADD CONSTRAINT "parent_students_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leads" ADD CONSTRAINT "leads_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff" ADD CONSTRAINT "staff_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payroll" ADD CONSTRAINT "payroll_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payroll" ADD CONSTRAINT "payroll_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;
