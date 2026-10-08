-- 020: transfer certificate number
--
-- `previous_school` recorded where a student came from but not the document that proves they
-- left it cleanly. A school will not normally admit a transferring student without the TC, and
-- the number is what an office quotes when the previous school is chased for it or when a
-- board asks during affiliation checks.
--
-- Nullable, and no unique key: it belongs to the issuing school's numbering, not ours, so two
-- students arriving from different schools can legitimately hold the same number, and a student
-- admitted at nursery has none at all.
--
-- Safe to re-run: guarded on information_schema.

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'students' AND column_name = 'tc_no') = 0,
    'ALTER TABLE students ADD COLUMN tc_no VARCHAR(50) NULL AFTER previous_school',
    'SELECT ''students.tc_no already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SELECT COUNT(*) AS students,
       SUM(previous_school IS NOT NULL AND previous_school <> '') AS with_previous_school,
       SUM(tc_no IS NOT NULL AND tc_no <> '') AS with_tc_no
FROM students WHERE deleted_at IS NULL;
