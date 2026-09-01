-- 011: make the timetable writable
--
-- `timetable_slot` had no uniqueness on the cell it represents, so the same class/section could
-- hold two subjects in one period. `timetable_periods` existed but was never populated, leaving
-- the grid with no column definitions.

-- One row per (school, class, section, day, period) — the cell is the identity.
-- Duplicates are collapsed first, keeping the lowest id, so the index can be created.
DELETE t1 FROM timetable_slot t1
JOIN timetable_slot t2
  ON t1.school_id = t2.school_id
 AND t1.class_label <=> t2.class_label
 AND t1.section_label <=> t2.section_label
 AND t1.day_of_week = t2.day_of_week
 AND t1.period_no = t2.period_no
 AND t1.id > t2.id;

ALTER TABLE timetable_slot
  ADD UNIQUE KEY uq_tt_cell (school_id, class_label, section_label, day_of_week, period_no);

-- Six teaching periods with a mid-morning break, for every school that has none.
INSERT INTO timetable_periods (school_id, name, start_time, end_time, is_break, sort_order)
SELECT s.id, p.name, p.start_time, p.end_time, p.is_break, p.sort_order
FROM schools s
CROSS JOIN (
    SELECT 'P1' AS name, '10:00:00' AS start_time, '10:45:00' AS end_time, 0 AS is_break, 1 AS sort_order
    UNION ALL SELECT 'P2', '10:45:00', '11:30:00', 0, 2
    UNION ALL SELECT 'P3', '11:30:00', '12:15:00', 0, 3
    UNION ALL SELECT 'Break', '12:15:00', '12:45:00', 1, 4
    UNION ALL SELECT 'P4', '12:45:00', '13:30:00', 0, 5
    UNION ALL SELECT 'P5', '13:30:00', '14:15:00', 0, 6
    UNION ALL SELECT 'P6', '14:15:00', '15:00:00', 0, 7
) p
WHERE s.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM timetable_periods tp WHERE tp.school_id = s.id);
