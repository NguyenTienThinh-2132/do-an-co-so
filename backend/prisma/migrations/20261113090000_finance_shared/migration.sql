-- CreateTable
CREATE TABLE "finance_books" (
    "id" UUID NOT NULL,
    "opening_balance_vnd" BIGINT NOT NULL DEFAULT 0,
    "budget_vnd" BIGINT NOT NULL DEFAULT 0,
    "revision" INTEGER NOT NULL DEFAULT 0,
    "is_demo" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "finance_books_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "finance_jars" (
    "id" UUID NOT NULL,
    "book_id" UUID NOT NULL,
    "default_code" TEXT,
    "title" TEXT NOT NULL,
    "normalized_title" TEXT NOT NULL,
    "subtitle" TEXT NOT NULL DEFAULT '',
    "style_key" TEXT NOT NULL,
    "allocation_bps" INTEGER NOT NULL DEFAULT 0,
    "deleted_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "finance_jars_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "finance_transactions" (
    "id" UUID NOT NULL,
    "book_id" UUID NOT NULL,
    "jar_id" UUID,
    "title" TEXT NOT NULL,
    "amount_vnd" BIGINT NOT NULL,
    "category" TEXT NOT NULL,
    "occurred_at" TIMESTAMPTZ(3) NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "finance_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "finance_allocations" (
    "id" UUID NOT NULL,
    "book_id" UUID NOT NULL,
    "amount_vnd" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "finance_allocations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "finance_allocation_items" (
    "allocation_id" UUID NOT NULL,
    "jar_id" UUID NOT NULL,
    "amount_vnd" BIGINT NOT NULL,
    "ratio_bps" INTEGER NOT NULL,

    CONSTRAINT "finance_allocation_items_pkey" PRIMARY KEY ("allocation_id","jar_id")
);

-- CreateTable
CREATE TABLE "finance_requests" (
    "book_id" UUID NOT NULL,
    "request_key" TEXT NOT NULL,
    "operation" TEXT NOT NULL,
    "payload_hash" TEXT NOT NULL,
    "response" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "finance_requests_pkey" PRIMARY KEY ("book_id","request_key")
);

-- CreateIndex
CREATE INDEX "finance_jars_book_id_idx" ON "finance_jars"("book_id");

-- CreateIndex
CREATE UNIQUE INDEX "finance_jars_book_id_default_code_key" ON "finance_jars"("book_id", "default_code");

-- CreateIndex
CREATE INDEX "finance_transactions_book_id_occurred_at_id_idx" ON "finance_transactions"("book_id", "occurred_at", "id");

-- CreateIndex
CREATE INDEX "finance_allocations_book_id_created_at_id_idx" ON "finance_allocations"("book_id", "created_at", "id");

-- AddForeignKey
ALTER TABLE "finance_jars" ADD CONSTRAINT "finance_jars_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "finance_books"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "finance_transactions" ADD CONSTRAINT "finance_transactions_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "finance_books"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "finance_transactions" ADD CONSTRAINT "finance_transactions_jar_id_fkey" FOREIGN KEY ("jar_id") REFERENCES "finance_jars"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "finance_allocations" ADD CONSTRAINT "finance_allocations_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "finance_books"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "finance_allocation_items" ADD CONSTRAINT "finance_allocation_items_allocation_id_fkey" FOREIGN KEY ("allocation_id") REFERENCES "finance_allocations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "finance_allocation_items" ADD CONSTRAINT "finance_allocation_items_jar_id_fkey" FOREIGN KEY ("jar_id") REFERENCES "finance_jars"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "finance_requests" ADD CONSTRAINT "finance_requests_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "finance_books"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE UNIQUE INDEX finance_jars_active_title_key ON finance_jars(book_id, normalized_title) WHERE deleted_at IS NULL;
ALTER TABLE finance_books ADD CONSTRAINT finance_books_nonnegative CHECK (opening_balance_vnd >= 0 AND budget_vnd >= 0 AND revision >= 0);
ALTER TABLE finance_jars ADD CONSTRAINT finance_jars_bps CHECK (allocation_bps BETWEEN 0 AND 10000), ADD CONSTRAINT finance_jars_title CHECK (length(trim(title)) BETWEEN 1 AND 50);
ALTER TABLE finance_transactions ADD CONSTRAINT finance_transactions_amount CHECK (amount_vnd <> 0 AND abs(amount_vnd) <= 999999999999), ADD CONSTRAINT finance_transactions_category CHECK (category IN ('food','transport','shopping','education','housing','other'));
ALTER TABLE finance_allocations ADD CONSTRAINT finance_allocations_positive CHECK (amount_vnd > 0 AND amount_vnd <= 999999999999);
ALTER TABLE finance_allocation_items ADD CONSTRAINT finance_items_valid CHECK (amount_vnd >= 0 AND ratio_bps BETWEEN 0 AND 10000);
