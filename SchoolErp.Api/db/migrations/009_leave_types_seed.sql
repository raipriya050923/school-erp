-- 009: seed staff leave types
--
-- `leave_types` and `leave_applications` were defined in the schema but never used, so there was
-- no leave workflow at all — a teacher could only be flagged 'on_leave' by hand on their record.
-- This gives each school the default staff leave categories; the apply form reads them from here.
--
-- Safe to re-run: uq_lt (school_id, name) makes the INSERT IGNORE a no-op second time.

INSERT IGNORE INTO leave_types (school_id, name, applicable_to, max_days_per_year, is_paid)
SELECT s.id, d.name, 'staff', d.max_days, d.is_paid
FROM schools s
CROSS JOIN (
    SELECT 'Sick Leave'   AS name, 12   AS max_days, 1 AS is_paid
    UNION ALL SELECT 'Casual Leave',  12,   1
    UNION ALL SELECT 'Annual Leave',  15,   1
    UNION ALL SELECT 'Unpaid Leave',  NULL, 0
) d
WHERE s.deleted_at IS NULL;

SELECT school_id, COUNT(*) AS leave_types FROM leave_types GROUP BY school_id ORDER BY school_id;
