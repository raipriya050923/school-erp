-- 017: a teacher teaches more than one subject
--
-- `staff.specialization` held a single subject name, so a teacher was recorded as teaching
-- exactly one thing. Schools do not work that way — the same person commonly takes Science and
-- Computer Science, or Maths across two grades and Physics in the senior ones.
--
-- The consequence was not cosmetic: the Subjects & Teachers grid offers only teachers whose
-- specialization matches the subject exactly, so a Science teacher could never be picked for
-- Computer Science even though teacher_assignments has always been able to record it.
--
-- `staff.specialization` stays as a joined summary — the teacher portal, profile screen and
-- search all read that one column — but the rows here are the source of truth.
--
-- Safe to re-run: the table is created only if absent and the backfill is INSERT IGNORE.

CREATE TABLE IF NOT EXISTS staff_subjects (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    school_id  BIGINT UNSIGNED NOT NULL,
    staff_id   BIGINT UNSIGNED NOT NULL,
    subject_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_staff_subject (staff_id, subject_id),
    KEY idx_ss_school (school_id, subject_id),
    CONSTRAINT fk_ss_staff FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE,
    CONSTRAINT fk_ss_subject FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ---- what each teacher was recorded as specialising in ---- */

INSERT IGNORE INTO staff_subjects (school_id, staff_id, subject_id)
SELECT st.school_id, st.id, sub.id
FROM staff st
JOIN subjects sub ON sub.school_id = st.school_id AND sub.name = st.specialization
WHERE st.staff_type = 'teacher' AND st.deleted_at IS NULL;

/* ---- plus anything they are already assigned to teach ---- */
--
-- An assignment is the stronger evidence: someone timetabled for Computer Science teaches it,
-- whatever their specialization column happened to say.

INSERT IGNORE INTO staff_subjects (school_id, staff_id, subject_id)
SELECT DISTINCT ta.school_id, ta.staff_id, ta.subject_id
FROM teacher_assignments ta
JOIN staff st ON st.id = ta.staff_id AND st.deleted_at IS NULL;

SELECT st.school_id,
       CONCAT(st.first_name, ' ', st.last_name) AS teacher,
       GROUP_CONCAT(sub.name ORDER BY sub.name SEPARATOR ', ') AS subjects
FROM staff_subjects ss
JOIN staff st ON st.id = ss.staff_id
JOIN subjects sub ON sub.id = ss.subject_id
GROUP BY st.id
ORDER BY st.school_id, teacher;
