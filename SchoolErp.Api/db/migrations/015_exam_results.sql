-- 015: stored results and the class-teacher approval gate
--
-- Totals, percentage and grade were worked out in C# every time the Class Results page loaded and
-- never written down. That makes them impossible to cite: a mark corrected next week silently
-- rewrites a result a parent was shown, and nothing records what was approved or when.
--
-- Two tables, plus the grade bands the calculation reads.
--
--   grade_scales        already existed but was empty — the bands were hardcoded in the service.
--   exam_result         one row per (exam, student): what they scored, out of what, and the grade.
--   exam_section_result the approval gate: a class teacher signs off their section, and only then
--                       may an admin publish the exam.
--
-- Safe to re-run: every write is INSERT IGNORE or CREATE TABLE IF NOT EXISTS.

/* ---- grade bands, per school ---- */
--
-- Bands are half-open at the top (`max_percent` is inclusive) and must not overlap. These mirror
-- the scale the service had compiled into it, so no result changes value on migrating.

INSERT IGNORE INTO grade_scales (school_id, grade, min_percent, max_percent, grade_point, remarks)
SELECT s.id, g.grade, g.min_percent, g.max_percent, g.grade_point, g.remarks
FROM schools s
CROSS JOIN (
    SELECT 'A+' AS grade, 90.00 AS min_percent, 100.00 AS max_percent, 4.00 AS grade_point, 'Outstanding' AS remarks
    UNION ALL SELECT 'A',  80.00, 89.99, 3.60, 'Excellent'
    UNION ALL SELECT 'B',  70.00, 79.99, 3.20, 'Very good'
    UNION ALL SELECT 'C',  60.00, 69.99, 2.80, 'Good'
    UNION ALL SELECT 'D',  50.00, 59.99, 2.40, 'Satisfactory'
    UNION ALL SELECT 'E',  33.00, 49.99, 1.60, 'Needs improvement'
    UNION ALL SELECT 'F',   0.00, 32.99, 0.00, 'Not graded'
) g
WHERE s.deleted_at IS NULL;

/* ---- one result row per student per exam ---- */
--
-- `exam_results` (plural) already existed but hangs off `exams`, the unused legacy table; the
-- live exam table is `exam`. Rather than repoint a foreign key under a table with rows in it,
-- this is the singular sibling of exam / exam_paper / student_mark.

CREATE TABLE IF NOT EXISTS exam_result (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    school_id        BIGINT UNSIGNED NOT NULL,
    exam_id          BIGINT UNSIGNED NOT NULL,
    student_id       BIGINT UNSIGNED NOT NULL,
    -- Denormalised so a result survives a student changing section mid-year: it records the
    -- section they actually sat the exam in.
    class_label      VARCHAR(50) NULL,
    section_label    VARCHAR(50) NULL,
    obtained         DECIMAL(8,2) NOT NULL DEFAULT 0,
    full_marks       DECIMAL(8,2) NOT NULL DEFAULT 0,
    percent          DECIMAL(5,2) NOT NULL DEFAULT 0,
    grade            VARCHAR(5) NULL,
    subjects_total   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    subjects_entered SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    -- 0 while any paper is unmarked: the percentage is real but provisional, and a grade
    -- computed over missing marks reads as a fail the student did not earn.
    is_complete      TINYINT(1) NOT NULL DEFAULT 0,
    computed_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_exam_result (exam_id, student_id),
    KEY idx_er_section (school_id, exam_id, class_label, section_label),
    CONSTRAINT fk_exres_exam FOREIGN KEY (exam_id) REFERENCES exam (id) ON DELETE CASCADE,
    CONSTRAINT fk_exres_student FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ---- the approval gate, one row per section of an exam ---- */

CREATE TABLE IF NOT EXISTS exam_section_result (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    school_id     BIGINT UNSIGNED NOT NULL,
    exam_id       BIGINT UNSIGNED NOT NULL,
    class_label   VARCHAR(50) NOT NULL,
    section_label VARCHAR(50) NOT NULL,
    -- pending  : marks still being entered, or changed since the last approval
    -- approved : the class teacher has signed the sheet off; the admin may now publish
    status        ENUM('pending','approved') NOT NULL DEFAULT 'pending',
    approved_by   BIGINT UNSIGNED NULL,
    approved_at   DATETIME NULL,
    remarks       VARCHAR(255) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_esr (exam_id, class_label, section_label),
    KEY idx_esr_school (school_id, exam_id),
    CONSTRAINT fk_esr_exam FOREIGN KEY (exam_id) REFERENCES exam (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SELECT (SELECT COUNT(*) FROM grade_scales) AS grade_bands,
       (SELECT COUNT(*) FROM exam_result) AS results,
       (SELECT COUNT(*) FROM exam_section_result) AS approvals;
