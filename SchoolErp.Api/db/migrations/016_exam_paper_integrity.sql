-- 016: stop exam papers outliving their exam
--
-- exam_paper and student_mark were created with an index on exam_id but no foreign key, so a
-- paper could be written against an exam that does not exist, and any delete path that missed a
-- table left rows behind. The service deletes both explicitly, which works until something else
-- does not — and nothing refused a paper filed against a deleted exam at all.
--
-- Orphans are cleared first so the constraints can be created.

DELETE p FROM exam_paper p LEFT JOIN exam e ON e.id = p.exam_id WHERE e.id IS NULL;
DELETE m FROM student_mark m LEFT JOIN exam e ON e.id = m.exam_id WHERE e.id IS NULL;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.table_constraints
     WHERE table_schema = DATABASE() AND table_name = 'exam_paper'
       AND constraint_name = 'fk_paper_exam') = 0,
    'ALTER TABLE exam_paper ADD CONSTRAINT fk_paper_exam FOREIGN KEY (exam_id) REFERENCES exam (id) ON DELETE CASCADE',
    'SELECT ''fk_paper_exam already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.table_constraints
     WHERE table_schema = DATABASE() AND table_name = 'student_mark'
       AND constraint_name = 'fk_mark_exam') = 0,
    'ALTER TABLE student_mark ADD CONSTRAINT fk_mark_exam FOREIGN KEY (exam_id) REFERENCES exam (id) ON DELETE CASCADE',
    'SELECT ''fk_mark_exam already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SELECT (SELECT COUNT(*) FROM exam_paper) AS papers,
       (SELECT COUNT(*) FROM student_mark) AS marks,
       (SELECT COUNT(*) FROM exam_paper p LEFT JOIN exam e ON e.id = p.exam_id WHERE e.id IS NULL) AS orphan_papers;
