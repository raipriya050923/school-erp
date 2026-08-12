-- =====================================================================
-- Migration 003 — classes/sections seed + Teacher-portal demo data
-- =====================================================================
--   mysql -u root -p school_erp < SchoolErp.Api/db/migrations/003_teacher_seed.sql
--
-- - Seeds Grade 6..10 with sections A/B for Sunrise (school 1) and assigns
--   class teachers (so the Admin "Classes" page and Teacher "My Classes"
--   both have data). Rajesh Koirala (staff 1) is class teacher of 4 sections.
-- - Creates a lightweight `teacher_homework` table matching the Teacher UI
--   and seeds Rajesh's homework.
-- =====================================================================

USE school_erp;
SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;

-- ---- classes + sections (fresh for school 1) ----
DELETE FROM sections WHERE school_id = 1;
DELETE FROM classes  WHERE school_id = 1;

INSERT INTO classes (school_id, name, numeric_level, is_active) VALUES
  (1, 'Grade 6', 6, 1), (1, 'Grade 7', 7, 1), (1, 'Grade 8', 8, 1),
  (1, 'Grade 9', 9, 1), (1, 'Grade 10', 10, 1);

-- sections A/B per class, class_teacher_id maps to staff ids 1..8
-- (Rajesh=1 is class teacher of Grade 8-A, 8-B, 9-A, 10-A to match the UI)
INSERT INTO sections (school_id, class_id, name, capacity, class_teacher_id, room_no, is_active)
SELECT 1, c.id, s.name, 45, s.tid, s.room, 1
FROM classes c
JOIN (
  SELECT 'Grade 6'  AS cname, 'A' AS name, 2 AS tid, 'R-101' AS room UNION ALL
  SELECT 'Grade 6',  'B', 8, 'R-102' UNION ALL
  SELECT 'Grade 7',  'A', 3, 'R-201' UNION ALL
  SELECT 'Grade 7',  'B', 4, 'R-202' UNION ALL
  SELECT 'Grade 8',  'A', 1, 'R-204' UNION ALL
  SELECT 'Grade 8',  'B', 1, 'R-205' UNION ALL
  SELECT 'Grade 9',  'A', 1, 'R-301' UNION ALL
  SELECT 'Grade 9',  'B', 6, 'R-302' UNION ALL
  SELECT 'Grade 10', 'A', 1, 'R-401' UNION ALL
  SELECT 'Grade 10', 'B', 8, 'R-402'
) s ON s.cname = c.name
WHERE c.school_id = 1;

-- ---- teacher_homework (demo table matching the Teacher UI) ----
CREATE TABLE IF NOT EXISTS teacher_homework (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    teacher_staff_id BIGINT UNSIGNED NOT NULL,
    title            VARCHAR(200) NOT NULL,
    subject          VARCHAR(100) NULL,
    class_label      VARCHAR(50)  NULL,
    assigned_date    DATE NULL,
    due_date         DATE NULL,
    submitted_count  INT NOT NULL DEFAULT 0,
    total_count      INT NOT NULL DEFAULT 0,
    status           VARCHAR(20) NOT NULL DEFAULT 'open',   -- open | grading | graded | closed
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_th_teacher (school_id, teacher_staff_id, due_date)
) ENGINE=InnoDB;

DELETE FROM teacher_homework WHERE school_id = 1;
INSERT INTO teacher_homework
  (school_id, teacher_staff_id, title, subject, class_label, assigned_date, due_date, submitted_count, total_count, status)
VALUES
  (1, 1, 'Algebra Worksheet — Linear Equations',   'Mathematics',      'Grade 8-A',  '2026-06-30', '2026-07-05', 30, 38, 'open'),
  (1, 1, 'Geometry: Triangle Congruence Proofs',    'Mathematics',      'Grade 9-A',  '2026-06-28', '2026-07-03', 36, 36, 'grading'),
  (1, 1, 'Trigonometry Practice Set 4',             'Opt. Mathematics', 'Grade 10-A', '2026-06-25', '2026-07-01', 31, 34, 'graded'),
  (1, 1, 'Fractions & Decimals Revision',           'Mathematics',      'Grade 8-B',  '2026-06-22', '2026-06-27', 37, 37, 'graded');

SET FOREIGN_KEY_CHECKS = 1;
SET SQL_SAFE_UPDATES = 1;

SELECT 'classes' AS entity, COUNT(*) AS n FROM classes WHERE school_id=1
UNION ALL SELECT 'sections', COUNT(*) FROM sections WHERE school_id=1
UNION ALL SELECT 'sections where Rajesh is class teacher', COUNT(*) FROM sections WHERE school_id=1 AND class_teacher_id=1
UNION ALL SELECT 'teacher_homework', COUNT(*) FROM teacher_homework WHERE school_id=1;
