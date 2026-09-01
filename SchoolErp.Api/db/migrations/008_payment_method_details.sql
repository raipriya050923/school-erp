-- 008: richer payment capture on platform payments
--
-- Adds the payment methods the console actually offers (UPI, debit/credit card), the bank name
-- that a bank transfer needs, and a path to an uploaded payment screenshot.
--
-- The ENUM keeps every existing value so historical rows stay valid; only new ones are added.

ALTER TABLE platform_payments
  MODIFY COLUMN method ENUM(
    'card','bank_transfer','esewa','khalti','paypal','stripe','cash','other',
    'upi','debit_card','credit_card'
  ) NOT NULL;

ALTER TABLE platform_payments
  ADD COLUMN bank_name VARCHAR(120) NULL AFTER method,
  ADD COLUMN proof_url VARCHAR(500) NULL AFTER transaction_ref;
