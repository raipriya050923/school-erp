-- 013: fee structure master
--
-- Invoice amounts came from a Dictionary compiled into FeeRepository: five grade names with
-- fixed rates and a 12000 fallback for everything else. Every school got the same numbers, and
-- a school whose classes were not called "Grade 6".."Grade 10" got the fallback for all of them.
--
-- The schema already had the right tables (fee_types, fee_structures) but nothing wrote to them.
-- This migration puts them to work: fee_types becomes the per-school list of fee heads, and
-- fee_structures holds the amount for each (academic year, class, head).
--
-- Safe to re-run: every write is INSERT IGNORE or guarded by IF NOT EXISTS.

/* ---- fee_types gains the two columns a master screen needs ---- */

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'fee_types' AND column_name = 'is_active') = 0,
    'ALTER TABLE fee_types ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1',
    'SELECT ''fee_types.is_active already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Frequency lives on the head, not the cell: "Tuition Fee is monthly" is a property of the fee,
-- and repeating it in every class row would let one class drift out of step with the others.
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'fee_types' AND column_name = 'frequency') = 0,
    'ALTER TABLE fee_types ADD COLUMN frequency ENUM(''one_time'',''monthly'',''quarterly'',''half_yearly'',''yearly'') NOT NULL DEFAULT ''monthly''',
    'SELECT ''fee_types.frequency already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* ---- what an invoice was built from ---- */

-- fee_invoice_items exists but hangs off fee_invoices, the unused plural table. The live invoice
-- table is fee_invoice, so its lines need their own table.
CREATE TABLE IF NOT EXISTS fee_invoice_line (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    invoice_id  BIGINT UNSIGNED NOT NULL,
    fee_type_id BIGINT UNSIGNED NULL,
    description VARCHAR(150) NOT NULL,
    amount      DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id),
    KEY idx_fil_invoice (invoice_id),
    CONSTRAINT fk_fil_invoice FOREIGN KEY (invoice_id) REFERENCES fee_invoice (id) ON DELETE CASCADE,
    -- Heads are retired, not deleted, so this stays valid; NULL covers lines written before a
    -- head existed or carried over from the old flat amount.
    CONSTRAINT fk_fil_type FOREIGN KEY (fee_type_id) REFERENCES fee_types (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ---- default heads for every existing school ---- */

INSERT IGNORE INTO fee_types (school_id, name, description, is_refundable, is_active, frequency)
SELECT s.id, d.name, d.descr, 0, 1, d.freq
FROM schools s
CROSS JOIN (
    SELECT 'Tuition Fee'   AS name, 'Core monthly teaching fee'        AS descr, 'monthly'  AS freq
    UNION ALL SELECT 'Transport Fee', 'Bus service, billed monthly',        'monthly'
    UNION ALL SELECT 'Exam Fee',      'Charged once per academic year',     'yearly'
    UNION ALL SELECT 'Library Fee',   'Charged once per academic year',     'yearly'
    UNION ALL SELECT 'Admission Fee', 'Charged once, on admission',         'one_time'
) d
WHERE s.deleted_at IS NULL;

/* ---- carry the old hardcoded rates into the structure ---- */
--
-- Only Tuition Fee is seeded, at exactly the rate FeeRepository used to apply, so the first
-- invoice run after this migration bills the same amounts it would have billed before. Every
-- other head starts at zero and is priced by the school on the Fee Structure screen.

INSERT IGNORE INTO fee_structures
    (school_id, academic_year_id, class_id, fee_type_id, amount, frequency, due_day, late_fine_amount)
SELECT c.school_id, ay.id, c.id, ft.id,
       CASE c.name
           WHEN 'Grade 6'  THEN 10500
           WHEN 'Grade 7'  THEN 11500
           WHEN 'Grade 8'  THEN 12500
           WHEN 'Grade 9'  THEN 13500
           WHEN 'Grade 10' THEN 14500
           ELSE 12000
       END,
       'monthly', NULL, 0
FROM classes c
JOIN academic_years ay ON ay.school_id = c.school_id AND ay.is_current = 1
JOIN fee_types ft ON ft.school_id = c.school_id AND ft.name = 'Tuition Fee'
WHERE c.is_active = 1;

SELECT ft.school_id, COUNT(DISTINCT ft.id) AS heads, COUNT(fs.id) AS priced_cells
FROM fee_types ft
LEFT JOIN fee_structures fs ON fs.fee_type_id = ft.id
GROUP BY ft.school_id ORDER BY ft.school_id;
