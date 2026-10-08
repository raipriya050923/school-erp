-- 022: transport fee priced by distance, per student
--
-- Transport was a class price like any other: every child in Grade 1 paid the same ₹1,500,
-- whether the bus collected them from the next street or from twelve kilometres out, and a
-- child who walks to school was billed for a bus they never boarded.
--
-- Three things change:
--   * fee_types gains a pricing_mode, so a head can say "the amount comes from the student,
--     not from the class grid". Transport Fee is switched to it; everything else is untouched.
--   * transport_slabs holds the distance bands and their fares, per school, per academic year
--     and per head — the same shape as fee_structures, so the year selector and the copy-year
--     feature keep working the same way.
--   * student_transport records which students ride, how far, and the rare negotiated amount.
--
-- Safe to re-run: every write is INSERT IGNORE, CREATE TABLE IF NOT EXISTS, or guarded by an
-- information_schema check.

/* ---- a head can be priced per class or per student ---- */

-- An enum rather than a boolean because the way an amount is derived is a small vocabulary, not
-- a yes/no: a hostel or a meal plan may one day want its own mode, and "is_per_student = 1"
-- could not say which of them it meant.
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'fee_types' AND column_name = 'pricing_mode') = 0,
    'ALTER TABLE fee_types ADD COLUMN pricing_mode ENUM(''class'',''distance'') NOT NULL DEFAULT ''class'' AFTER frequency',
    'SELECT ''fee_types.pricing_mode already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Only the seeded Transport Fee is moved. A head a school added itself is left alone: renaming
-- something to "Transport" should not silently change how it is billed.
UPDATE fee_types SET pricing_mode = 'distance'
WHERE name = 'Transport Fee' AND pricing_mode = 'class';

/* ---- the distance bands ---- */

CREATE TABLE IF NOT EXISTS transport_slabs (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    fee_type_id      BIGINT UNSIGNED NOT NULL,
    -- The band covers everything above the previous band's ceiling up to and including this one,
    -- so the set is described by its upper bounds alone and no gap or overlap can be expressed.
    up_to_km         DECIMAL(6,2) NOT NULL,
    amount           DECIMAL(12,2) NOT NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_slab (school_id, academic_year_id, fee_type_id, up_to_km),
    CONSTRAINT fk_slab_school FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE CASCADE,
    CONSTRAINT fk_slab_year   FOREIGN KEY (academic_year_id) REFERENCES academic_years (id) ON DELETE CASCADE,
    CONSTRAINT fk_slab_type   FOREIGN KEY (fee_type_id) REFERENCES fee_types (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ---- who rides, and how far ---- */
--
-- student_transport already exists in the original schema, shaped for a routes-and-stops module
-- that was never built: route_id and stop_id NOT NULL against two tables that are also empty,
-- and no code anywhere reads it. Rather than take a second table name for the same idea, the
-- existing one is reshaped — the route columns are kept but made optional, so a route module can
-- still be built on them later, and the columns distance pricing needs are added beside them.
--
-- The CREATE below therefore only fires on a database that has never had the table.

CREATE TABLE IF NOT EXISTS student_transport (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    school_id      BIGINT UNSIGNED NOT NULL,
    student_id     BIGINT UNSIGNED NOT NULL,
    -- One row per student, kept even when they stop riding: is_active = 0 preserves the distance
    -- and the pickup point for the day they start again, which is usually the next term.
    is_active      TINYINT(1) NOT NULL DEFAULT 1,
    distance_km    DECIMAL(6,2) NULL,
    pickup_point   VARCHAR(120) NULL,
    -- A negotiated amount that ignores the slabs: staff children, siblings, a term of half fare.
    -- NULL means the slab decides, which is not the same as an override of 0 (rides free).
    amount_override DECIMAL(12,2) NULL,
    note           VARCHAR(200) NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_student_transport (student_id),
    KEY idx_st_school (school_id, is_active),
    CONSTRAINT fk_st_school  FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE CASCADE,
    CONSTRAINT fk_st_student FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ---- bring an existing student_transport up to the shape above ---- */
--
-- Each step is guarded by information_schema, so this is a no-op on a database where the CREATE
-- above just ran, and it upgrades one that carried the old routes-only shape.

-- A distance is a fact about where the child lives, not about a school year, so the row is no
-- longer per year. The old column stays for any route module that wants it, but stops being
-- required — nothing can supply it.
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'student_transport'
       AND column_name = 'academic_year_id' AND is_nullable = 'NO') = 1,
    'ALTER TABLE student_transport MODIFY COLUMN academic_year_id BIGINT UNSIGNED NULL',
    'SELECT ''student_transport.academic_year_id already optional''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'student_transport'
       AND column_name = 'route_id' AND is_nullable = 'NO') = 1,
    'ALTER TABLE student_transport MODIFY COLUMN route_id BIGINT UNSIGNED NULL',
    'SELECT ''student_transport.route_id already optional''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'student_transport'
       AND column_name = 'stop_id' AND is_nullable = 'NO') = 1,
    'ALTER TABLE student_transport MODIFY COLUMN stop_id BIGINT UNSIGNED NULL',
    'SELECT ''student_transport.stop_id already optional''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'student_transport' AND column_name = 'distance_km') = 0,
    'ALTER TABLE student_transport ADD COLUMN distance_km DECIMAL(6,2) NULL',
    'SELECT ''student_transport.distance_km already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'student_transport' AND column_name = 'pickup_point') = 0,
    'ALTER TABLE student_transport ADD COLUMN pickup_point VARCHAR(120) NULL',
    'SELECT ''student_transport.pickup_point already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'student_transport' AND column_name = 'amount_override') = 0,
    'ALTER TABLE student_transport ADD COLUMN amount_override DECIMAL(12,2) NULL',
    'SELECT ''student_transport.amount_override already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'student_transport' AND column_name = 'note') = 0,
    'ALTER TABLE student_transport ADD COLUMN note VARCHAR(200) NULL',
    'SELECT ''student_transport.note already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- One row per student, replacing the per-year key. Two rows for one child would make "how far do
-- they live" a question with two answers, and the invoice run would have to pick one.
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.statistics
     WHERE table_schema = DATABASE() AND table_name = 'student_transport' AND index_name = 'uq_student_transport') = 0,
    'ALTER TABLE student_transport ADD UNIQUE KEY uq_student_transport (student_id)',
    'SELECT ''student_transport.uq_student_transport already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- The old uq_st (academic_year_id, student_id) is deliberately left in place: it is the index
-- backing fk_strn_ay, so dropping it fails, and it now costs nothing. A unique key ignores rows
-- whose columns are NULL, and every row this feature writes leaves academic_year_id NULL.

/* ---- retire the flat class price for transport ---- */
--
-- Left in place deliberately. Deleting the old fee_structures rows would be the tidier schema,
-- but it would also throw away the only record of what the school used to charge before anyone
-- has entered a single slab. The invoice run ignores cells for a distance-priced head, so these
-- rows bill nobody; the Fee Structure screen stops offering them for editing.

SELECT
    (SELECT COUNT(*) FROM fee_types WHERE pricing_mode = 'distance') AS distance_priced_heads,
    (SELECT COUNT(*) FROM transport_slabs) AS slabs,
    (SELECT COUNT(*) FROM student_transport) AS riders;
