-- Additive only: preserve existing IDs, timestamps and business fields.
-- Existing and new rows begin at version 1; clients may not supply this field.
ALTER TABLE "tasks" ADD COLUMN "version" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_version_positive" CHECK ("version" >= 1);
