-- 014: qualification details
--
-- staff_qualifications held a bare name per row ("B.Ed", "M.A. English"), which records that a
-- teacher holds a degree but not who awarded it or when. Admins need both to verify a hire, so
-- each row gains the awarding university or board and the year it was completed.
--
-- Both columns are nullable: the rows already in the table have no such detail to backfill, and
-- an admin adding a qualification in a hurry should not be blocked on remembering the year.
--
-- Safe to re-run: each ALTER is guarded on information_schema.

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'staff_qualifications' AND column_name = 'institution') = 0,
    'ALTER TABLE staff_qualifications ADD COLUMN institution VARCHAR(150) NULL AFTER qualification',
    'SELECT ''staff_qualifications.institution already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'staff_qualifications' AND column_name = 'completion_year') = 0,
    'ALTER TABLE staff_qualifications ADD COLUMN completion_year SMALLINT UNSIGNED NULL AFTER institution',
    'SELECT ''staff_qualifications.completion_year already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- The table was created with the server default collation while everything around it is
-- utf8mb4_unicode_ci, which makes joins against staff and schools need an explicit COLLATE.
SET @sql = IF(
    (SELECT table_collation FROM information_schema.tables
     WHERE table_schema = DATABASE() AND table_name = 'staff_qualifications') <> 'utf8mb4_unicode_ci',
    'ALTER TABLE staff_qualifications CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci',
    'SELECT ''staff_qualifications already utf8mb4_unicode_ci''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SELECT staff_id, qualification, institution, completion_year FROM staff_qualifications ORDER BY staff_id, sort_order;
