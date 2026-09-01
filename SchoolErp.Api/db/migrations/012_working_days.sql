-- 012: which days a school actually runs
--
-- The timetable assumed a fixed Sunday–Friday week. That is right for Nepal, wrong for schools
-- that rest on Sunday, and there was no way to say so. Stored as day numbers matching
-- timetable_slot.day_of_week (1 = Sunday … 7 = Saturday).

ALTER TABLE schools
  ADD COLUMN working_days VARCHAR(20) NOT NULL DEFAULT '1,2,3,4,5,6' AFTER timezone;
