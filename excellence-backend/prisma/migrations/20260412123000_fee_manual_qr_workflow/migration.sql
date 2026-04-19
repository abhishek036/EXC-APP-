-- Manual QR fee workflow + review metadata + audit trail

ALTER TABLE IF EXISTS fee_records
  ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS approved_by UUID,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS fee_records
  ALTER COLUMN status TYPE VARCHAR(30),
  ALTER COLUMN status SET DEFAULT 'unpaid';

UPDATE fee_records fr
SET paid_amount = COALESCE(p.total_paid, 0)
FROM (
  SELECT fee_record_id, SUM(amount_paid)::NUMERIC(10,2) AS total_paid
  FROM fee_payments
  GROUP BY fee_record_id
) p
WHERE fr.id = p.fee_record_id;

UPDATE fee_records
SET status = CASE
  WHEN COALESCE(status, '') = 'paid' THEN 'paid'
  WHEN COALESCE(status, '') IN ('pending', 'partial') THEN 'unpaid'
  WHEN COALESCE(status, '') = '' THEN 'unpaid'
  ELSE status
END;

ALTER TABLE IF EXISTS fee_payments
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS batch_id UUID,
  ADD COLUMN IF NOT EXISTS payment_channel VARCHAR(30) DEFAULT 'manual_qr',
  ADD COLUMN IF NOT EXISTS screenshot_url TEXT,
  ADD COLUMN IF NOT EXISTS status VARCHAR(30) DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS approved_by UUID,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

UPDATE fee_payments fp
SET
  student_id = fr.student_id,
  batch_id = fr.batch_id,
  status = COALESCE(fp.status, 'approved')
FROM fee_records fr
WHERE fp.fee_record_id = fr.id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fee_records_approved_by_fkey'
  ) THEN
    ALTER TABLE fee_records
      ADD CONSTRAINT fee_records_approved_by_fkey
      FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fee_payments_student_id_fkey'
  ) THEN
    ALTER TABLE fee_payments
      ADD CONSTRAINT fee_payments_student_id_fkey
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fee_payments_batch_id_fkey'
  ) THEN
    ALTER TABLE fee_payments
      ADD CONSTRAINT fee_payments_batch_id_fkey
      FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fee_payments_approved_by_fkey'
  ) THEN
    ALTER TABLE fee_payments
      ADD CONSTRAINT fee_payments_approved_by_fkey
      FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS fee_payment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institute_id UUID NOT NULL REFERENCES institutes(id) ON DELETE CASCADE,
  fee_record_id UUID NOT NULL REFERENCES fee_records(id) ON DELETE CASCADE,
  payment_id UUID REFERENCES fee_payments(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(40) NOT NULL,
  from_status VARCHAR(30),
  to_status VARCHAR(30),
  meta JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fee_payment_events_institute_record
  ON fee_payment_events (institute_id, fee_record_id);

CREATE INDEX IF NOT EXISTS idx_fee_payment_events_payment
  ON fee_payment_events (payment_id);

CREATE INDEX IF NOT EXISTS idx_fee_payment_events_actor
  ON fee_payment_events (actor_id);

CREATE INDEX IF NOT EXISTS idx_fee_payments_status
  ON fee_payments (status);

CREATE INDEX IF NOT EXISTS idx_fee_records_status
  ON fee_records (status);
