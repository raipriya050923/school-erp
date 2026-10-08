-- 021: students submit their own fee payments for verification
--
-- Fees could only be recorded by an administrator sitting at the console, so a parent who paid
-- by UPI or bank transfer had to phone the office and hope it was entered. This lets them enter
-- it themselves — amount, method, reference, date — and leaves the school to confirm it.
--
-- A claim is NOT money, so it does not go into `fee_payment`. That table is what an invoice's
-- `paid` total is summed from and what the school's collection figures rest on; putting
-- unverified rows in it would make every existing query wrong unless it learned to filter, and
-- one missed filter would overstate collections. A submission earns a `fee_payment` row only
-- when an administrator verifies it, and `payment_id` below records which one.
--
-- Safe to re-run.

CREATE TABLE IF NOT EXISTS fee_payment_submission (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    invoice_id  BIGINT UNSIGNED NOT NULL,
    student_id  BIGINT UNSIGNED NOT NULL,

    amount      DECIMAL(12,2) NOT NULL,
    -- Free text rather than an ENUM, matching fee_payment.method: schools keep adding ways to
    -- be paid, and a new one should not need a schema change.
    method      VARCHAR(30)  NOT NULL,
    -- The UPI/UTR/cheque number the school will check against its own statement. Not unique:
    -- it belongs to the bank's numbering, and a mistyped one has to be correctable.
    reference   VARCHAR(120) NULL,
    paid_date   DATE NOT NULL,
    note        VARCHAR(255) NULL,

    -- pending | verified | rejected
    status      VARCHAR(20) NOT NULL DEFAULT 'pending',

    -- users.id of whoever submitted it. Nullable because a student's login can be removed while
    -- the payment they declared still has to stay auditable.
    submitted_by BIGINT UNSIGNED NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    reviewed_by  BIGINT UNSIGNED NULL,
    reviewed_at  DATETIME NULL,
    -- Why it was rejected, shown back to the parent. Without it "rejected" is unactionable.
    review_note  VARCHAR(255) NULL,
    -- The fee_payment row this became, once verified.
    payment_id   BIGINT UNSIGNED NULL,

    INDEX idx_fps_school  (school_id, status),
    INDEX idx_fps_student (student_id, status),
    INDEX idx_fps_invoice (invoice_id),
    CONSTRAINT fk_fps_school  FOREIGN KEY (school_id)  REFERENCES schools(id)  ON DELETE CASCADE,
    CONSTRAINT fk_fps_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- No FK to fee_invoice: that table is created by 004 without a primary-key-backed parent in
-- some older installs, and a submission outliving a deleted invoice is preferable to the
-- migration failing outright. The application always scopes reads by school_id and invoice_id.

SELECT COUNT(*) AS submissions FROM fee_payment_submission;
