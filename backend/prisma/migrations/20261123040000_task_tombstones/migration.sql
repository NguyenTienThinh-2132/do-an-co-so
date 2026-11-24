-- Deletion metadata only; no business data is copied or removed by migration.
-- No FK to tasks: the source row no longer exists after a successful deletion.
CREATE TABLE "task_tombstones" (
    "task_id" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "deleted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "task_tombstones_pkey" PRIMARY KEY ("task_id"),
    CONSTRAINT "task_tombstones_version_check" CHECK ("version" >= 2)
);
