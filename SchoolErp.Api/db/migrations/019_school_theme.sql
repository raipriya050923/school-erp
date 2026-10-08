-- 019: a school picks its own shell colour
--
-- Every tenant looked identical: the same white rail, the same royal blue. A school is a brand —
-- it has house colours on its gate and its uniform — and a multi-tenant ERP that cannot reflect
-- that reads as somebody else's software.
--
-- Stored as a name, not a hex value: the palettes are designed sets (rail, hover, icon chip,
-- active pill, brand mark) that have to stay in step, and letting a school post a raw colour
-- would produce combinations nobody checked for contrast.
--
--   classic  the light rail the product shipped with
--   brand    royal blue rail, white active pill
--   forest   deep green rail, green accent
--   mist     pale blue-grey rail with coloured module icons
--
-- Safe to re-run: guarded on information_schema.

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'schools' AND column_name = 'theme') = 0,
    'ALTER TABLE schools ADD COLUMN theme VARCHAR(20) NOT NULL DEFAULT ''classic'' AFTER logo_url',
    'SELECT ''schools.theme already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Existing schools keep the look they have. Changing it under them without asking would be a
-- surprise, and every one of them was set up against the light rail.
UPDATE schools SET theme = 'classic' WHERE theme IS NULL OR theme = '';

SELECT theme, COUNT(*) AS schools FROM schools WHERE deleted_at IS NULL GROUP BY theme;
