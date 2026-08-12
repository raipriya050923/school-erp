-- =====================================================================
-- Migration 004 — transactional demo tables for the remaining screens
-- =====================================================================
-- Attendance, Exams+Papers+Marks, Timetable, Fees. Lightweight demo tables
-- matching the UI so Teacher + Admin transactional screens can be API-backed.
--   mysql -u root -p school_erp < SchoolErp.Api/db/migrations/004_transactional.sql
-- =====================================================================

USE school_erp;
SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;

/* ---------- attendance ---------- */
CREATE TABLE IF NOT EXISTS daily_attendance (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id       BIGINT UNSIGNED NOT NULL,
    student_id      BIGINT UNSIGNED NOT NULL,
    class_label     VARCHAR(50) NULL,
    section_label   VARCHAR(20) NULL,
    attendance_date DATE NOT NULL,
    status          VARCHAR(10) NOT NULL DEFAULT 'present',  -- present | absent | late | holiday
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_att (student_id, attendance_date),
    INDEX idx_att_sec (school_id, class_label, section_label, attendance_date)
) ENGINE=InnoDB;

/* ---------- exams ---------- */
CREATE TABLE IF NOT EXISTS exam (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    name       VARCHAR(150) NOT NULL,
    type       VARCHAR(40)  NULL,
    start_date DATE NULL,
    end_date   DATE NULL,
    classes    VARCHAR(60) NULL,
    status     VARCHAR(30) NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exam_paper (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_id     BIGINT UNSIGNED NOT NULL,
    class_label VARCHAR(50) NULL,
    subject     VARCHAR(100) NOT NULL,
    exam_date   DATE NULL,
    time_label  VARCHAR(40) NULL,
    room        VARCHAR(40) NULL,
    full_marks  INT NOT NULL DEFAULT 100,
    INDEX idx_paper_exam (exam_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS student_mark (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    exam_id    BIGINT UNSIGNED NOT NULL,
    student_id BIGINT UNSIGNED NOT NULL,
    subject    VARCHAR(100) NOT NULL,
    marks      DECIMAL(6,2) NULL,
    full_marks DECIMAL(6,2) NOT NULL DEFAULT 100,
    UNIQUE KEY uq_mark (exam_id, student_id, subject)
) ENGINE=InnoDB;

/* ---------- timetable ---------- */
CREATE TABLE IF NOT EXISTS timetable_slot (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    class_label      VARCHAR(50) NULL,
    section_label    VARCHAR(20) NULL,
    day_of_week      TINYINT NOT NULL,   -- 1 = Sunday ... 6 = Friday
    period_no        TINYINT NOT NULL,
    time_label       VARCHAR(20) NULL,
    subject          VARCHAR(100) NULL,
    room             VARCHAR(40) NULL,
    teacher_staff_id BIGINT UNSIGNED NULL,
    INDEX idx_tt_teacher (school_id, teacher_staff_id, day_of_week)
) ENGINE=InnoDB;

/* ---------- fees ---------- */
CREATE TABLE IF NOT EXISTS fee_invoice (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    student_id   BIGINT UNSIGNED NOT NULL,
    student_name VARCHAR(150) NULL,
    class_label  VARCHAR(50) NULL,
    invoice_no   VARCHAR(40) NULL,
    month        VARCHAR(30) NULL,
    amount       DECIMAL(12,2) NOT NULL DEFAULT 0,
    paid         DECIMAL(12,2) NOT NULL DEFAULT 0,
    due_date     DATE NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'unpaid',   -- unpaid | partial | paid | overdue
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fee_school (school_id, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fee_payment (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    invoice_id BIGINT UNSIGNED NOT NULL,
    school_id  BIGINT UNSIGNED NOT NULL,
    amount     DECIMAL(12,2) NOT NULL,
    method     VARCHAR(30) NULL,
    ref        VARCHAR(80) NULL,
    paid_date  DATE NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =====================================================================
-- SEED (school 1 = Sunrise)
-- =====================================================================

/* attendance: named students (ids 1..12) for June 2026 weekdays, deterministic */
DELETE FROM daily_attendance WHERE school_id = 1;
INSERT INTO daily_attendance (school_id, student_id, class_label, section_label, attendance_date, status)
SELECT 1, s.id, s.class_name, s.section_name,
       DATE_ADD('2026-06-01', INTERVAL n.d DAY),
       CASE
         WHEN DAYOFWEEK(DATE_ADD('2026-06-01', INTERVAL n.d DAY)) = 7 THEN 'holiday'  -- Saturday
         WHEN ((s.id * 7 + n.d) % 100) < 86 THEN 'present'
         WHEN ((s.id * 7 + n.d) % 100) < 94 THEN 'late'
         ELSE 'absent'
       END
FROM students s
JOIN (
  SELECT (t.d*10 + o.d) AS d
  FROM (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) t
  CROSS JOIN (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) o
) n ON n.d < 30
WHERE s.school_id = 1 AND s.id <= 12;

/* exams */
DELETE FROM student_mark WHERE school_id = 1;
DELETE FROM exam_paper WHERE exam_id IN (SELECT id FROM exam WHERE school_id = 1);
DELETE FROM exam WHERE school_id = 1;

INSERT INTO exam (id, school_id, name, type, start_date, end_date, classes, status) VALUES
  (1, 1, 'First Terminal Examination 2083', 'Term',      '2026-08-17', '2026-08-26', 'G6-G10', 'scheduled'),
  (2, 1, 'Unit Test — July',                'Unit Test', '2026-07-14', '2026-07-16', 'G6-G10', 'scheduled'),
  (3, 1, 'Quarterly Assessment 2083',       'Quarterly', '2026-06-08', '2026-06-15', 'G6-G10', 'result_published'),
  (4, 1, 'Annual Examination 2082',         'Final',     '2026-03-10', '2026-03-21', 'G6-G10', 'completed');

INSERT INTO exam_paper (exam_id, class_label, subject, exam_date, time_label, room, full_marks) VALUES
  (1, 'Grade 8', 'English',          '2026-08-17', '08:00 – 10:00', 'Hall A', 100),
  (1, 'Grade 8', 'Mathematics',      '2026-08-18', '08:00 – 10:00', 'Hall A', 100),
  (1, 'Grade 8', 'Science',          '2026-08-20', '08:00 – 10:00', 'Hall B', 100),
  (1, 'Grade 8', 'Nepali',           '2026-08-21', '08:00 – 10:00', 'Hall A', 100),
  (1, 'Grade 8', 'Social Studies',   '2026-08-24', '08:00 – 10:00', 'Hall B', 100),
  (1, 'Grade 8', 'Computer Science', '2026-08-26', '08:00 – 09:30', 'Lab 1',   75);

/* timetable for Rajesh (staff 1), Grade 8-A, Sun..Fri (1..6) */
DELETE FROM timetable_slot WHERE school_id = 1;
INSERT INTO timetable_slot (school_id, class_label, section_label, day_of_week, period_no, time_label, subject, room, teacher_staff_id) VALUES
  (1,'Grade 8','A',1,1,'09:00','Mathematics','R-204',1),
  (1,'Grade 9','A',1,3,'11:15','Mathematics','R-301',1),
  (1,'Grade 8','B',1,5,'13:30','Mathematics','R-205',1),
  (1,'Grade 10','A',2,2,'10:00','Opt. Mathematics','R-401',1),
  (1,'Grade 8','A',2,4,'12:15','Mathematics','R-204',1),
  (1,'Grade 9','A',3,1,'09:00','Mathematics','R-301',1),
  (1,'Grade 8','B',3,2,'10:00','Mathematics','R-205',1),
  (1,'Grade 10','A',3,6,'14:30','Opt. Mathematics','R-401',1),
  (1,'Grade 8','A',4,3,'11:15','Mathematics','R-204',1),
  (1,'Grade 9','A',4,5,'13:30','Mathematics','R-301',1),
  (1,'Grade 8','B',5,1,'09:00','Mathematics','R-205',1),
  (1,'Grade 8','A',5,2,'10:00','Mathematics','R-204',1),
  (1,'Grade 10','A',5,4,'12:15','Opt. Mathematics','R-401',1),
  (1,'Grade 9','A',6,2,'10:00','Mathematics','R-301',1),
  (1,'Grade 8','A',6,3,'11:15','Mathematics','R-204',1);

/* fees: invoices for the named students (from the UI) */
DELETE FROM fee_payment WHERE school_id = 1;
DELETE FROM fee_invoice WHERE school_id = 1;
INSERT INTO fee_invoice (school_id, student_id, student_name, class_label, invoice_no, month, amount, paid, due_date, status) VALUES
  (1, 1,'Aarav Thapa',     'Grade 8-A', 'FI-26-0871','July 2026',12500,0,    '2026-07-10','unpaid'),
  (1, 2,'Sneha Shrestha',  'Grade 8-A', 'FI-26-0842','July 2026',12500,12500,'2026-07-10','paid'),
  (1, 3,'Bibek Gurung',    'Grade 8-A', 'FI-26-0853','July 2026',12500,6250, '2026-07-10','partial'),
  (1, 5,'Rohan Maharjan',  'Grade 9-A', 'FI-26-0790','June 2026',12500,0,    '2026-06-10','overdue'),
  (1, 4,'Priya Karki',     'Grade 9-B', 'FI-26-0866','July 2026',13500,13500,'2026-07-10','paid'),
  (1, 7,'Kiran Tamang',    'Grade 10-B','FI-26-0878','July 2026',14500,0,    '2026-07-10','unpaid'),
  (1, 6,'Anisha Rai',      'Grade 10-A','FI-26-0881','July 2026',14500,14500,'2026-07-10','paid'),
  (1, 9,'Sagar Basnet',    'Grade 6-B', 'FI-26-0885','July 2026',10500,4250, '2026-07-10','partial');

SET FOREIGN_KEY_CHECKS = 1;
SET SQL_SAFE_UPDATES = 1;

SELECT 'daily_attendance' AS entity, COUNT(*) AS n FROM daily_attendance WHERE school_id=1
UNION ALL SELECT 'exam', COUNT(*) FROM exam WHERE school_id=1
UNION ALL SELECT 'exam_paper', COUNT(*) FROM exam_paper
UNION ALL SELECT 'timetable_slot', COUNT(*) FROM timetable_slot WHERE school_id=1
UNION ALL SELECT 'fee_invoice', COUNT(*) FROM fee_invoice WHERE school_id=1;
