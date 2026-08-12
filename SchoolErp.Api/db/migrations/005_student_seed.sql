-- =====================================================================
-- Migration 005 — Student-portal demo data
-- =====================================================================
-- Seeds exam marks for Aarav Thapa (student 1) for the published Quarterly
-- Assessment (exam 3) so the Student "Exams & Results" page shows results.
--   mysql -u root -p school_erp < SchoolErp.Api/db/migrations/005_student_seed.sql
-- =====================================================================

USE school_erp;
SET SQL_SAFE_UPDATES = 0;

DELETE FROM student_mark WHERE school_id = 1 AND student_id = 1 AND exam_id = 3;
INSERT INTO student_mark (school_id, exam_id, student_id, subject, marks, full_marks) VALUES
  (1, 3, 1, 'English',          78, 100),
  (1, 3, 1, 'Mathematics',      91, 100),
  (1, 3, 1, 'Science',          84, 100),
  (1, 3, 1, 'Nepali',           72, 100),
  (1, 3, 1, 'Social Studies',   80, 100),
  (1, 3, 1, 'Computer Science', 66, 75);

SET SQL_SAFE_UPDATES = 1;

SELECT 'marks for Aarav (exam 3)' AS metric, COUNT(*) AS n FROM student_mark WHERE student_id=1 AND exam_id=3;
