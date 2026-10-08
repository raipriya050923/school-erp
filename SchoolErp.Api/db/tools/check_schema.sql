-- ============================================================================
--  check_schema.sql — what the running code needs that this database lacks
-- ============================================================================
--
--  Read-only. Changes nothing, safe on production.
--
--  Migrations here are applied by hand (see SchoolErp.Api/README.md), so a
--  deploy can put new code in front of an older database. When that happens
--  MySQL raises "Unknown column ..." and the API turns it into a flat
--  500 {"error":"server_error","message":"An unexpected error occurred."} —
--  the real reason reaching the log and nowhere else. This script asks the
--  database directly instead, so the missing piece can be seen without log
--  access.
--
--  HOW TO USE
--      mysql -u <user> -p <database> < db/tools/check_schema.sql
--
--  Every row that comes back is something to fix; no rows means the schema
--  carries everything the current code writes.
-- ============================================================================

-- Columns the code writes, each with the migration that introduces it. The
-- base schema in database/school_erp_schema.sql predates all of them.
DROP TEMPORARY TABLE IF EXISTS required_columns;
CREATE TEMPORARY TABLE required_columns (
    tbl        VARCHAR(64),
    col        VARCHAR(64),
    migration  VARCHAR(64),
    used_by    VARCHAR(120)
);

INSERT INTO required_columns VALUES
  -- 002: the admin console shows class/section/guardian on the student itself
  ('students','class_name',           '002_admin_columns.sql',    'create/update student'),
  ('students','section_name',         '002_admin_columns.sql',    'create/update student'),
  ('students','guardian_name',        '002_admin_columns.sql',    'create/update student'),
  ('students','guardian_phone',       '002_admin_columns.sql',    'create/update student'),
  ('students','city',                 '002_admin_columns.sql',    'create/update student'),
  ('students','state',                '002_admin_columns.sql',    'create/update student'),
  ('students','pincode',              '002_admin_columns.sql',    'create/update student'),
  ('students','fee_due',              '002_admin_columns.sql',    'create/update student'),
  -- 010: geography master, the authoritative ids behind the city/state text
  ('students','state_id',             '010_geography_master.sql', 'create/update student'),
  ('students','city_id',              '010_geography_master.sql', 'create/update student'),
  ('staff','state_id',                '010_geography_master.sql', 'create/update teacher'),
  ('staff','city_id',                 '010_geography_master.sql', 'create/update teacher'),
  ('schools','country_id',            '010_geography_master.sql', 'create/update school'),
  ('schools','state_id',              '010_geography_master.sql', 'create/update school'),
  ('schools','city_id',               '010_geography_master.sql', 'create/update school'),
  -- 018: every provisioned login starts on a password the holder must replace
  ('users','must_change_password',    '018_must_change_password.sql', 'any account provisioning'),
  -- 020: transfer certificate number
  ('students','tc_no',                '020_student_tc_no.sql',    'create/update student');

-- Tables the code reads or writes that only a migration creates.
DROP TEMPORARY TABLE IF EXISTS required_tables;
CREATE TEMPORARY TABLE required_tables (
    tbl        VARCHAR(64),
    migration  VARCHAR(64),
    used_by    VARCHAR(120)
);

INSERT INTO required_tables VALUES
  ('countries',          '010_geography_master.sql', 'resolving a stateId/cityId on save'),
  ('states',             '010_geography_master.sql', 'resolving a stateId/cityId on save'),
  ('cities',             '010_geography_master.sql', 'resolving a stateId/cityId on save'),
  ('timetable_periods',  'database/school_erp_schema.sql', 'timetable grid columns');

-- ---------------------------------------------------------------- results

SELECT 'MISSING COLUMN' AS problem, r.tbl AS `table`, r.col AS `column`,
       r.migration AS `apply this`, r.used_by AS `breaks`
FROM required_columns r
LEFT JOIN information_schema.columns c
       ON c.table_schema = DATABASE() AND c.table_name = r.tbl AND c.column_name = r.col
WHERE c.column_name IS NULL

UNION ALL

SELECT 'MISSING TABLE', r.tbl, '-', r.migration, r.used_by
FROM required_tables r
LEFT JOIN information_schema.tables t
       ON t.table_schema = DATABASE() AND t.table_name = r.tbl
WHERE t.table_name IS NULL

ORDER BY `apply this`, `table`, `column`;

-- A second, quieter failure: the geography tables exist but are empty, so every
-- stateId/cityId a form sends is rejected as "not in the master list". Guarded,
-- because counting rows in a table that was never created aborts the script
-- before the report above has been read.
SET @geo := (SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name IN ('countries','states','cities'));
SET @sql := IF(@geo = 3,
    'SELECT COUNT(*) AS geography_cities_seeded FROM cities',
    'SELECT ''geography tables absent — see the report above'' AS geography_cities_seeded');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
