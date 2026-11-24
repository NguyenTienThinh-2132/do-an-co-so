-- CreateEnum
CREATE TYPE "TaskPriority" AS ENUM ('low', 'medium', 'high');

-- CreateEnum
CREATE TYPE "TaskStatus" AS ENUM ('pending', 'inProgress', 'completed');

-- CreateTable
CREATE TABLE "tasks" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "category_id" TEXT,
    "start_at" TIMESTAMPTZ(3) NOT NULL,
    "end_at" TIMESTAMPTZ(3) NOT NULL,
    "priority" "TaskPriority" NOT NULL DEFAULT 'medium',
    "status" "TaskStatus" NOT NULL DEFAULT 'pending',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "tasks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "tasks_start_at_id_idx" ON "tasks"("start_at", "id");

-- CreateIndex
CREATE INDEX "tasks_end_at_idx" ON "tasks"("end_at");

-- Domain invariants for the TV3 demo.
ALTER TABLE "tasks"
  ADD CONSTRAINT "tasks_title_not_blank"
    CHECK ("title" ~ '[^[:space:]]'),
  ADD CONSTRAINT "tasks_end_after_start"
    CHECK ("end_at" > "start_at");
