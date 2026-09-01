-- 011: seed subjects
--
-- `subjects` was empty for every school, so the exam "Add Subject" dropdown was a hardcoded
-- list in the Angular template — the same eight names for every tenant, regardless of what the
-- school actually teaches. This gives each existing school the five-subject default set; the
-- API now reads the dropdown from here, and SchoolService seeds the same list for new schools.
--
-- Safe to re-run: uq_subject (school_id, name) makes the INSERT IGNORE a no-op second time.

INSERT IGNORE INTO subjects (school_id, name, code, subject_type, is_active)
SELECT s.id, d.name, d.code, 'theory', 1
FROM schools s
CROSS JOIN (
    SELECT 'English'          AS name, 'ENG' AS code
    UNION ALL SELECT 'Mathematics',      'MAT'
    UNION ALL SELECT 'Science',          'SCI'
    UNION ALL SELECT 'Social Studies',   'SOC'
    UNION ALL SELECT 'Computer Science', 'CSC'
) d
WHERE s.deleted_at IS NULL;

SELECT school_id, COUNT(*) AS subjects FROM subjects GROUP BY school_id ORDER BY school_id;
