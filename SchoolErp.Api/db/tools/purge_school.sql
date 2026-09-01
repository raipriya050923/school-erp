-- ============================================================================
--  purge_school.sql — permanently remove one school and everything under it
-- ============================================================================
--
--  THIS IS A HARD DELETE. It is not the soft delete the application performs
--  (which only stamps deleted_at). Nothing here is recoverable without a backup.
--
--  TAKE A BACKUP FIRST:
--      mysqldump -uroot -p school_erp > school_erp_before_purge.sql
--
--  HOW TO USE
--    1. Set @sid below to the school you mean to destroy.
--    2. Run PART 1 on its own and read the output. Confirm the school NAME is
--       the one you intend and the row counts look like the right school.
--    3. Only then run PART 2. It ends in ROLLBACK on purpose — read the
--       verification output, then change that last line to COMMIT to commit.
--
--  WHY FOREIGN_KEY_CHECKS IS DISABLED
--    The school-scoped tables reference each other through some forty NO ACTION
--    foreign keys, so no single delete order satisfies them all. Disabling the
--    checks removes the ordering problem — but it also means ON DELETE CASCADE
--    does NOT fire. That is why part 2a deletes, by hand, the child tables that
--    have no school_id of their own. Dropping those statements would silently
--    leave orphaned rows pointing at ids that no longer exist.
--
--  The table list in part 2b was generated from information_schema (every table
--  carrying a school_id column), not written from memory. Regenerate it after a
--  migration adds tables:
--      SELECT TABLE_NAME FROM information_schema.COLUMNS
--       WHERE TABLE_SCHEMA='school_erp' AND COLUMN_NAME='school_id'
--         AND TABLE_NAME<>'schools' ORDER BY TABLE_NAME;
-- ============================================================================

SET @sid := 0;   -- <<<< THE SCHOOL TO DESTROY. 0 is a deliberate no-op.


-- ============================================================================
--  PART 1 — DRY RUN. Read this before running PART 2.
-- ============================================================================

SELECT id, school_code, name, status, created_at
FROM schools WHERE id = @sid;

-- Row counts for the main child tables, as a sanity check on the target.
SELECT 'users'                AS table_name, COUNT(*) AS rows_to_delete FROM users               WHERE school_id = @sid
UNION ALL SELECT 'students',            COUNT(*) FROM students            WHERE school_id = @sid
UNION ALL SELECT 'staff',               COUNT(*) FROM staff               WHERE school_id = @sid
UNION ALL SELECT 'classes',             COUNT(*) FROM classes             WHERE school_id = @sid
UNION ALL SELECT 'sections',            COUNT(*) FROM sections            WHERE school_id = @sid
UNION ALL SELECT 'daily_attendance',    COUNT(*) FROM daily_attendance    WHERE school_id = @sid
UNION ALL SELECT 'student_mark',        COUNT(*) FROM student_mark        WHERE school_id = @sid
UNION ALL SELECT 'fee_invoice',         COUNT(*) FROM fee_invoice         WHERE school_id = @sid
UNION ALL SELECT 'timetable_slot',      COUNT(*) FROM timetable_slot      WHERE school_id = @sid
UNION ALL SELECT 'teacher_assignments', COUNT(*) FROM teacher_assignments WHERE school_id = @sid;

-- Platform-level records that go too: the super-admin's billing for this school.
SELECT 'school_subscriptions' AS table_name, COUNT(*) AS rows_to_delete FROM school_subscriptions WHERE school_id = @sid
UNION ALL SELECT 'platform_invoices', COUNT(*) FROM platform_invoices WHERE school_id = @sid
UNION ALL SELECT 'platform_payments', COUNT(*) FROM platform_payments WHERE school_id = @sid
UNION ALL SELECT 'support_tickets',   COUNT(*) FROM support_tickets   WHERE school_id = @sid;

-- WARNING CHECK. platform_announcements is NOT school-scoped, so it is not
-- purged, yet its created_by points at users.id with NO ACTION. If this returns
-- any row, one of this school's users authored a platform announcement, and
-- deleting them leaves a dangling created_by. Reassign or delete those first.
SELECT pa.id, pa.created_by
FROM platform_announcements pa
WHERE pa.created_by IN (SELECT id FROM users WHERE school_id = @sid);


-- ============================================================================
--  PART 2 — THE PURGE
-- ============================================================================

START TRANSACTION;
SET FOREIGN_KEY_CHECKS = 0;

-- ---- 2a. Children with no school_id of their own ---------------------------
-- Reachable only through a school-scoped parent. Cascades do not fire while
-- FOREIGN_KEY_CHECKS is off, so each of these is deleted explicitly.

DELETE FROM exam_marks
 WHERE exam_schedule_id IN (SELECT id FROM exam_schedules
                             WHERE exam_id IN (SELECT id FROM exams WHERE school_id = @sid))
    OR student_id       IN (SELECT id FROM students WHERE school_id = @sid);

DELETE FROM exam_schedules WHERE exam_id IN (SELECT id FROM exams WHERE school_id = @sid);

DELETE FROM admit_cards
 WHERE exam_id    IN (SELECT id FROM exams    WHERE school_id = @sid)
    OR student_id IN (SELECT id FROM students WHERE school_id = @sid);

DELETE FROM exam_results
 WHERE exam_id    IN (SELECT id FROM exams    WHERE school_id = @sid)
    OR student_id IN (SELECT id FROM students WHERE school_id = @sid);

-- `exam` and `exams` are two different live tables in this schema; so are
-- `fee_invoice` and `fee_invoices`. Both of each are purged.
DELETE FROM exam_paper WHERE exam_id IN (SELECT id FROM exam WHERE school_id = @sid);

DELETE FROM homework_submissions
 WHERE homework_id IN (SELECT id FROM homework WHERE school_id = @sid)
    OR student_id  IN (SELECT id FROM students WHERE school_id = @sid);

DELETE FROM fee_invoice_items WHERE invoice_id IN (SELECT id FROM fee_invoices WHERE school_id = @sid);
DELETE FROM fee_invoice_line  WHERE invoice_id IN (SELECT id FROM fee_invoice  WHERE school_id = @sid);

DELETE FROM student_fee_discounts WHERE student_id IN (SELECT id FROM students WHERE school_id = @sid);

DELETE FROM student_guardians
 WHERE student_id  IN (SELECT id FROM students  WHERE school_id = @sid)
    OR guardian_id IN (SELECT id FROM guardians WHERE school_id = @sid);

DELETE FROM hostel_rooms WHERE hostel_id IN (SELECT id FROM hostels          WHERE school_id = @sid);
DELETE FROM route_stops  WHERE route_id  IN (SELECT id FROM transport_routes WHERE school_id = @sid);

DELETE FROM support_ticket_replies WHERE ticket_id IN (SELECT id FROM support_tickets WHERE school_id = @sid);

DELETE FROM message_recipients
 WHERE message_id   IN (SELECT id FROM messages WHERE school_id = @sid)
    OR recipient_id IN (SELECT id FROM users    WHERE school_id = @sid);

DELETE FROM role_permissions WHERE role_id IN (SELECT id FROM roles WHERE school_id = @sid);
DELETE FROM user_roles       WHERE user_id IN (SELECT id FROM users WHERE school_id = @sid);
DELETE FROM user_sessions    WHERE user_id IN (SELECT id FROM users WHERE school_id = @sid);
DELETE FROM password_resets  WHERE user_id IN (SELECT id FROM users WHERE school_id = @sid);


-- ---- 2b. Every table carrying school_id ------------------------------------

DELETE FROM academic_years                WHERE school_id = @sid;
DELETE FROM api_keys                      WHERE school_id = @sid;
DELETE FROM api_request_logs              WHERE school_id = @sid;
DELETE FROM audit_logs                    WHERE school_id = @sid;
DELETE FROM backups                       WHERE school_id = @sid;
DELETE FROM book_categories               WHERE school_id = @sid;
DELETE FROM book_issues                   WHERE school_id = @sid;
DELETE FROM books                         WHERE school_id = @sid;
DELETE FROM certificate_templates         WHERE school_id = @sid;
DELETE FROM class_subjects                WHERE school_id = @sid;
DELETE FROM classes                       WHERE school_id = @sid;
DELETE FROM communication_logs            WHERE school_id = @sid;
DELETE FROM daily_attendance              WHERE school_id = @sid;
DELETE FROM downloads                     WHERE school_id = @sid;
DELETE FROM events                        WHERE school_id = @sid;
DELETE FROM exam                          WHERE school_id = @sid;
DELETE FROM exam_result                   WHERE school_id = @sid;
DELETE FROM exam_section_result           WHERE school_id = @sid;
DELETE FROM exam_types                    WHERE school_id = @sid;
DELETE FROM exams                         WHERE school_id = @sid;
DELETE FROM fee_discounts                 WHERE school_id = @sid;
DELETE FROM fee_invoice                   WHERE school_id = @sid;
DELETE FROM fee_invoices                  WHERE school_id = @sid;
DELETE FROM fee_payment                   WHERE school_id = @sid;
DELETE FROM fee_payments                  WHERE school_id = @sid;
DELETE FROM fee_structures                WHERE school_id = @sid;
DELETE FROM fee_types                     WHERE school_id = @sid;
DELETE FROM grade_scales                  WHERE school_id = @sid;
DELETE FROM guardians                     WHERE school_id = @sid;
DELETE FROM homework                      WHERE school_id = @sid;
DELETE FROM hostel_allocations            WHERE school_id = @sid;
DELETE FROM hostels                       WHERE school_id = @sid;
DELETE FROM inventory_categories          WHERE school_id = @sid;
DELETE FROM inventory_items               WHERE school_id = @sid;
DELETE FROM inventory_suppliers           WHERE school_id = @sid;
DELETE FROM inventory_transactions        WHERE school_id = @sid;
DELETE FROM issued_certificates           WHERE school_id = @sid;
DELETE FROM leave_applications            WHERE school_id = @sid;
DELETE FROM leave_types                   WHERE school_id = @sid;
DELETE FROM lesson_plans                  WHERE school_id = @sid;
DELETE FROM messages                      WHERE school_id = @sid;
DELETE FROM notices                       WHERE school_id = @sid;
DELETE FROM notifications                 WHERE school_id = @sid;
DELETE FROM platform_announcement_schools WHERE school_id = @sid;
DELETE FROM platform_invoices             WHERE school_id = @sid;
DELETE FROM platform_payments             WHERE school_id = @sid;
DELETE FROM roles                         WHERE school_id = @sid;
DELETE FROM school_features               WHERE school_id = @sid;
DELETE FROM school_settings               WHERE school_id = @sid;
DELETE FROM school_subscriptions          WHERE school_id = @sid;
DELETE FROM sections                      WHERE school_id = @sid;
DELETE FROM staff                         WHERE school_id = @sid;
DELETE FROM staff_attendance              WHERE school_id = @sid;
DELETE FROM staff_qualifications          WHERE school_id = @sid;
DELETE FROM student_attendance            WHERE school_id = @sid;
DELETE FROM student_enrollments           WHERE school_id = @sid;
DELETE FROM student_mark                  WHERE school_id = @sid;
DELETE FROM student_transport             WHERE school_id = @sid;
DELETE FROM students                      WHERE school_id = @sid;
DELETE FROM study_materials               WHERE school_id = @sid;
DELETE FROM subjects                      WHERE school_id = @sid;
DELETE FROM support_tickets               WHERE school_id = @sid;
DELETE FROM teacher_assignments           WHERE school_id = @sid;
DELETE FROM teacher_homework              WHERE school_id = @sid;
DELETE FROM timetable_entries             WHERE school_id = @sid;
DELETE FROM timetable_periods             WHERE school_id = @sid;
DELETE FROM timetable_slot                WHERE school_id = @sid;
DELETE FROM transport_routes              WHERE school_id = @sid;
DELETE FROM users                         WHERE school_id = @sid;
DELETE FROM vehicles                      WHERE school_id = @sid;


-- ---- 2c. The school itself -------------------------------------------------

DELETE FROM schools WHERE id = @sid;

SET FOREIGN_KEY_CHECKS = 1;


-- ---- 2d. Verification — every count below must be 0 -------------------------
-- The last three look for orphans left behind anywhere in the database, not
-- just for this school, so they also catch a child delete that was missed.

SELECT 'schools'                AS check_name, COUNT(*) AS remaining FROM schools WHERE id        = @sid
UNION ALL SELECT 'users',                 COUNT(*) FROM users    WHERE school_id = @sid
UNION ALL SELECT 'students',              COUNT(*) FROM students WHERE school_id = @sid
UNION ALL SELECT 'staff',                 COUNT(*) FROM staff    WHERE school_id = @sid
UNION ALL SELECT 'orphan user_roles',     COUNT(*) FROM user_roles ur
                                           LEFT JOIN users u ON u.id = ur.user_id       WHERE u.id  IS NULL
UNION ALL SELECT 'orphan exam_paper',     COUNT(*) FROM exam_paper ep
                                           LEFT JOIN exam e ON e.id = ep.exam_id        WHERE e.id  IS NULL
UNION ALL SELECT 'orphan fee_inv_line',   COUNT(*) FROM fee_invoice_line fl
                                           LEFT JOIN fee_invoice fi ON fi.id = fl.invoice_id WHERE fi.id IS NULL
UNION ALL SELECT 'orphan student_guard',  COUNT(*) FROM student_guardians sg
                                           LEFT JOIN students s ON s.id = sg.student_id WHERE s.id  IS NULL;


-- Nothing is committed until you swap these two lines.
ROLLBACK;
-- COMMIT;
