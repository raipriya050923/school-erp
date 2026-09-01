-- 012: exam status — dates by default, with a manual override
--
-- Scheduled / ongoing / completed are fully determined by an exam's dates, so they are
-- derived at read time rather than stored (no nightly job, no stale badge). But an admin
-- sometimes needs to say otherwise: an exam finished early, results are published, the
-- whole thing is cancelled.
--
-- `exam.status` becomes that override. 'auto' means "follow the dates"; any other value
-- is an explicit choice that wins over them. Rows previously stored as 'scheduled' were
-- never deliberate — that was just the insert default — so they become 'auto'. Rows
-- already carrying a real decision (cancelled, completed, result_published) are kept.
--
-- Safe to re-run.

UPDATE exam SET status = 'auto' WHERE status = 'scheduled';

ALTER TABLE exam MODIFY COLUMN status VARCHAR(30) NOT NULL DEFAULT 'auto';

SELECT status, COUNT(*) AS n FROM exam GROUP BY status ORDER BY n DESC;
