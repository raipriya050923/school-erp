-- =====================================================================
-- Migration 002 — denormalised columns for the School Admin portal API
-- =====================================================================
-- The Angular admin UI shows class/section/guardian directly on a student
-- row and a comma-list of classes on a teacher. The normalised schema keeps
-- those in student_enrollments / teacher_assignments; for the demo API we add
-- lightweight denormalised columns so the pages map 1:1 without heavy joins.
--
--   mysql -u root -p school_erp < SchoolErp.Api/db/migrations/002_admin_columns.sql
-- =====================================================================

USE school_erp;
SET SQL_SAFE_UPDATES = 0;

-- ---- students: add columns if missing (guarded for MySQL 8 / 5.7) ----
DELIMITER //
DROP PROCEDURE IF EXISTS add_col //
CREATE PROCEDURE add_col(IN tbl VARCHAR(64), IN col VARCHAR(64), IN ddl VARCHAR(255))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND COLUMN_NAME = col) = 0 THEN
    SET @s = CONCAT('ALTER TABLE ', tbl, ' ADD COLUMN ', ddl);
    PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
  END IF;
END //
DELIMITER ;

CALL add_col('students', 'class_name',     "class_name VARCHAR(50) NULL AFTER roll_no");
CALL add_col('students', 'section_name',   "section_name VARCHAR(20) NULL AFTER class_name");
CALL add_col('students', 'guardian_name',  "guardian_name VARCHAR(150) NULL");
CALL add_col('students', 'guardian_phone', "guardian_phone VARCHAR(20) NULL");
CALL add_col('students', 'city',           "city VARCHAR(100) NULL");
CALL add_col('students', 'state',          "state VARCHAR(100) NULL");
CALL add_col('students', 'pincode',        "pincode VARCHAR(20) NULL");
CALL add_col('students', 'fee_due',        "fee_due DECIMAL(12,2) NOT NULL DEFAULT 0");

CALL add_col('staff', 'classes_taught', "classes_taught VARCHAR(120) NULL");
CALL add_col('staff', 'city',           "city VARCHAR(100) NULL");
CALL add_col('staff', 'state',          "state VARCHAR(100) NULL");
CALL add_col('staff', 'pincode',        "pincode VARCHAR(20) NULL");

DROP PROCEDURE IF EXISTS add_col;

-- ---- populate the 12 named Sunrise students (from the front-end roster) ----
UPDATE students SET class_name='Grade 8',  section_name='A', guardian_name='Bikash Thapa',     guardian_phone='9841022334', city='Kathmandu', fee_due=12500 WHERE admission_no='ADM-2081-012';
UPDATE students SET class_name='Grade 8',  section_name='A', guardian_name='Ram Shrestha',     guardian_phone='9802011223', city='Kathmandu', fee_due=0     WHERE admission_no='ADM-2081-034';
UPDATE students SET class_name='Grade 8',  section_name='A', guardian_name='Hari Gurung',      guardian_phone='9851133445', city='Kathmandu', fee_due=6250  WHERE admission_no='ADM-2081-055';
UPDATE students SET class_name='Grade 9',  section_name='B', guardian_name='Suman Karki',      guardian_phone='9808055667', city='Lalitpur',  fee_due=0     WHERE admission_no='ADM-2080-101';
UPDATE students SET class_name='Grade 9',  section_name='A', guardian_name='Raju Maharjan',    guardian_phone='9865077889', city='Kathmandu', fee_due=18750 WHERE admission_no='ADM-2080-118';
UPDATE students SET class_name='Grade 10', section_name='A', guardian_name='Deepak Rai',       guardian_phone='9812099001', city='Bhaktapur', fee_due=0     WHERE admission_no='ADM-2079-201';
UPDATE students SET class_name='Grade 10', section_name='B', guardian_name='Lakpa Tamang',     guardian_phone='9843012131', city='Kathmandu', fee_due=12500 WHERE admission_no='ADM-2079-215';
UPDATE students SET class_name='Grade 6',  section_name='A', guardian_name='Gopal Adhikari',   guardian_phone='9809014151', city='Bhaktapur', fee_due=0     WHERE admission_no='ADM-2082-004';
UPDATE students SET class_name='Grade 6',  section_name='B', guardian_name='Krishna Basnet',   guardian_phone='9855016171', city='Kathmandu', fee_due=6250  WHERE admission_no='ADM-2082-019';
UPDATE students SET class_name='Grade 7',  section_name='A', guardian_name='Mohan Pandey',     guardian_phone='9801018191', city='Kathmandu', fee_due=0     WHERE admission_no='ADM-2081-077';
UPDATE students SET class_name='Grade 9',  section_name='B', guardian_name='Pasang Lama',      guardian_phone='9846020212', city='Kathmandu', fee_due=0     WHERE admission_no='ADM-2080-134';
UPDATE students SET class_name='Grade 6',  section_name='A', guardian_name='Naresh Bhattarai', guardian_phone='9811022232', city='Kathmandu', fee_due=12500 WHERE admission_no='ADM-2082-031';

-- ---- give the bulk filler students a class/section so lists are meaningful ----
-- cycle Grade 6..10, section A/B, guardian derived from name
UPDATE students
SET class_name  = ELT(1 + (id % 5), 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'),
    section_name = IF(id % 2 = 0, 'A', 'B'),
    guardian_name = CONCAT('Guardian of ', first_name),
    guardian_phone = CONCAT('98', LPAD(id % 100000000, 8, '0')),
    city = 'Kathmandu'
WHERE class_name IS NULL AND admission_no LIKE 'F-%';

-- ---- teachers: classes taught + city (from the front-end teacher list) ----
UPDATE staff SET classes_taught='G8, G9, G10', city='Kathmandu' WHERE employee_code='EMP-014';
UPDATE staff SET classes_taught='G6, G7',      city='Kathmandu' WHERE employee_code='EMP-008';
UPDATE staff SET classes_taught='G7, G8',      city='Lalitpur'  WHERE employee_code='EMP-021';
UPDATE staff SET classes_taught='G6, G7, G8',  city='Kathmandu' WHERE employee_code='EMP-011';
UPDATE staff SET classes_taught='G8, G9',      city='Bhaktapur' WHERE employee_code='EMP-030';
UPDATE staff SET classes_taught='G9, G10',     city='Kathmandu' WHERE employee_code='EMP-017';
UPDATE staff SET classes_taught='G6-G10',      city='Kathmandu' WHERE employee_code='EMP-025';
UPDATE staff SET classes_taught='G9, G10',     city='Lalitpur'  WHERE employee_code='EMP-019';

SET SQL_SAFE_UPDATES = 1;

SELECT 'students with class' AS metric, COUNT(*) AS n FROM students WHERE class_name IS NOT NULL
UNION ALL SELECT 'teachers with classes_taught', COUNT(*) FROM staff WHERE classes_taught IS NOT NULL;
