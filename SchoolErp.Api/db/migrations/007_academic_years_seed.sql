-- 007: seed academic years
--
-- `academic_years` was empty, so every school reported a null academic year and the year
-- selector in the top bar had nothing to show. This gives each existing school three years
-- (previous, current, next) on an April–March calendar, with the middle one flagged current.
--
-- Safe to re-run: the INSERT skips any school that already has rows.

INSERT INTO academic_years (school_id, name, start_date, end_date, is_current)
SELECT s.id,
       CONCAT(y.yr, '-', RIGHT(y.yr + 1, 2)),
       MAKEDATE(y.yr, 1) + INTERVAL 3 MONTH,                     -- 1 April
       MAKEDATE(y.yr + 1, 1) + INTERVAL 2 MONTH + INTERVAL 30 DAY, -- 31 March
       y.is_current
FROM schools s
CROSS JOIN (
    SELECT YEAR(CURDATE()) - 1 AS yr, 0 AS is_current
    UNION ALL SELECT YEAR(CURDATE()),     1
    UNION ALL SELECT YEAR(CURDATE()) + 1, 0
) y
WHERE s.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM academic_years a WHERE a.school_id = s.id);
