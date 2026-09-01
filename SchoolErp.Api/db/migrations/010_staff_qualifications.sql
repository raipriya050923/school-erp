-- 010: multiple qualifications per staff member
--
-- `staff.qualification` is a single VARCHAR and cannot hold "B.Ed, M.A. English, NET".
-- Each qualification now gets its own row; staff.qualification is kept in step as a joined
-- summary so the teacher profile and portal screens that already read it keep working.

CREATE TABLE IF NOT EXISTS staff_qualifications (
    id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id     BIGINT UNSIGNED NOT NULL,
    staff_id      BIGINT UNSIGNED NOT NULL,
    qualification VARCHAR(150) NOT NULL,
    sort_order    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_sq_staff (school_id, staff_id),
    CONSTRAINT fk_sq_staff FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Carry existing single values across so nothing is lost on the first edit.
INSERT INTO staff_qualifications (school_id, staff_id, qualification, sort_order)
SELECT s.school_id, s.id, TRIM(s.qualification), 0
FROM staff s
WHERE s.qualification IS NOT NULL AND TRIM(s.qualification) <> ''
  AND s.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM staff_qualifications q WHERE q.staff_id = s.id);
