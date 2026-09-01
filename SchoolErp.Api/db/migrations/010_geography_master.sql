-- 010: platform-level geography master (countries / states / cities)
--
-- City and state were free text on every form, which produced 'UP' next to
-- 'RAJASTHAN', Nepali provinces mixed with Indian states, and rows like
-- 'slkjhgjk' and 'asdas'. Geography does not vary by tenant, so the master is
-- owned by the platform and read by every school — unlike subjects or leave
-- types, which are genuinely per-school.
--
-- The existing text columns are kept. The FK is authoritative from now on and
-- the API keeps the text in sync on write; rows whose old text matches nothing
-- are left with a NULL FK for manual cleanup rather than being guessed at.
--
-- Safe to re-run.

-- =====================================================================
-- 1. Tables
--
-- Collation is pinned to match the existing schema (utf8mb4_unicode_ci). MySQL
-- 8 would otherwise default these to utf8mb4_0900_ai_ci, and every join back to
-- schools/students/staff on a name would fail with an illegal mix of collations.
-- =====================================================================
DROP TABLE IF EXISTS cities;
DROP TABLE IF EXISTS states;
DROP TABLE IF EXISTS countries;

CREATE TABLE IF NOT EXISTS countries (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    iso2       CHAR(2)      NOT NULL,
    phone_code VARCHAR(8)   NULL,
    currency   CHAR(3)      NULL,
    is_active  TINYINT(1)   NOT NULL DEFAULT 1,
    UNIQUE KEY uq_country_iso  (iso2),
    UNIQUE KEY uq_country_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS states (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    country_id BIGINT UNSIGNED NOT NULL,
    name       VARCHAR(100) NOT NULL,
    code       VARCHAR(10)  NULL,
    is_active  TINYINT(1)   NOT NULL DEFAULT 1,
    UNIQUE KEY uq_state (country_id, name),
    CONSTRAINT fk_state_country FOREIGN KEY (country_id) REFERENCES countries(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS cities (
    id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    state_id  BIGINT UNSIGNED NOT NULL,
    name      VARCHAR(100) NOT NULL,
    is_active TINYINT(1)   NOT NULL DEFAULT 1,
    UNIQUE KEY uq_city (state_id, name),
    CONSTRAINT fk_city_state FOREIGN KEY (state_id) REFERENCES states(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 2. Seed — Nepal and India, the two countries already present in the data
-- =====================================================================

INSERT IGNORE INTO countries (name, iso2, phone_code, currency) VALUES
  ('Nepal', 'NP', '+977', 'NPR'),
  ('India', 'IN', '+91',  'INR');

SET @np := (SELECT id FROM countries WHERE iso2='NP');
SET @in := (SELECT id FROM countries WHERE iso2='IN');

INSERT IGNORE INTO states (country_id, name, code) VALUES
  (@np,'Koshi','P1'), (@np,'Madhesh','P2'), (@np,'Bagmati','P3'),
  (@np,'Gandaki','P4'), (@np,'Lumbini','P5'), (@np,'Karnali','P6'),
  (@np,'Sudurpashchim','P7');

INSERT IGNORE INTO states (country_id, name, code) VALUES
  (@in,'Andhra Pradesh','AP'), (@in,'Arunachal Pradesh','AR'), (@in,'Assam','AS'),
  (@in,'Bihar','BR'), (@in,'Chhattisgarh','CG'), (@in,'Goa','GA'),
  (@in,'Gujarat','GJ'), (@in,'Haryana','HR'), (@in,'Himachal Pradesh','HP'),
  (@in,'Jharkhand','JH'), (@in,'Karnataka','KA'), (@in,'Kerala','KL'),
  (@in,'Madhya Pradesh','MP'), (@in,'Maharashtra','MH'), (@in,'Manipur','MN'),
  (@in,'Meghalaya','ML'), (@in,'Mizoram','MZ'), (@in,'Nagaland','NL'),
  (@in,'Odisha','OD'), (@in,'Punjab','PB'), (@in,'Rajasthan','RJ'),
  (@in,'Sikkim','SK'), (@in,'Tamil Nadu','TN'), (@in,'Telangana','TS'),
  (@in,'Tripura','TR'), (@in,'Uttar Pradesh','UP'), (@in,'Uttarakhand','UK'),
  (@in,'West Bengal','WB'),
  (@in,'Andaman and Nicobar Islands','AN'), (@in,'Chandigarh','CH'),
  (@in,'Dadra and Nagar Haveli and Daman and Diu','DH'), (@in,'Delhi','DL'),
  (@in,'Jammu and Kashmir','JK'), (@in,'Ladakh','LA'),
  (@in,'Lakshadweep','LD'), (@in,'Puducherry','PY');

-- Cities: the districts/towns a school is realistically registered in.
INSERT IGNORE INTO cities (state_id, name)
SELECT s.id, c.name FROM states s JOIN (
  SELECT 'Koshi' st, 'Biratnagar' name UNION ALL SELECT 'Koshi','Dharan'
  UNION ALL SELECT 'Koshi','Itahari'      UNION ALL SELECT 'Koshi','Damak'
  UNION ALL SELECT 'Koshi','Birtamod'     UNION ALL SELECT 'Koshi','Illam'
  UNION ALL SELECT 'Madhesh','Janakpur'   UNION ALL SELECT 'Madhesh','Birgunj'
  UNION ALL SELECT 'Madhesh','Rajbiraj'   UNION ALL SELECT 'Madhesh','Jaleshwar'
  UNION ALL SELECT 'Bagmati','Kathmandu'  UNION ALL SELECT 'Bagmati','Lalitpur'
  UNION ALL SELECT 'Bagmati','Bhaktapur'  UNION ALL SELECT 'Bagmati','Hetauda'
  UNION ALL SELECT 'Bagmati','Chitwan'    UNION ALL SELECT 'Bagmati','Banepa'
  UNION ALL SELECT 'Bagmati','Dhulikhel'
  UNION ALL SELECT 'Gandaki','Pokhara'    UNION ALL SELECT 'Gandaki','Baglung'
  UNION ALL SELECT 'Gandaki','Gorkha'     UNION ALL SELECT 'Gandaki','Damauli'
  UNION ALL SELECT 'Lumbini','Butwal'     UNION ALL SELECT 'Lumbini','Bhairahawa'
  UNION ALL SELECT 'Lumbini','Nepalgunj'  UNION ALL SELECT 'Lumbini','Dang'
  UNION ALL SELECT 'Karnali','Surkhet'    UNION ALL SELECT 'Karnali','Jumla'
  UNION ALL SELECT 'Karnali','Birendranagar'
  UNION ALL SELECT 'Sudurpashchim','Dhangadhi' UNION ALL SELECT 'Sudurpashchim','Mahendranagar'
  UNION ALL SELECT 'Sudurpashchim','Dadeldhura'
) c ON c.st = s.name
WHERE s.country_id = @np;

INSERT IGNORE INTO cities (state_id, name)
SELECT s.id, c.name FROM states s JOIN (
  SELECT 'Delhi' st, 'New Delhi' name  UNION ALL SELECT 'Delhi','Dwarka'
  UNION ALL SELECT 'Delhi','Rohini'
  UNION ALL SELECT 'Maharashtra','Mumbai'   UNION ALL SELECT 'Maharashtra','Pune'
  UNION ALL SELECT 'Maharashtra','Nagpur'   UNION ALL SELECT 'Maharashtra','Nashik'
  UNION ALL SELECT 'Karnataka','Bengaluru'  UNION ALL SELECT 'Karnataka','Mysuru'
  UNION ALL SELECT 'Karnataka','Mangaluru'
  UNION ALL SELECT 'Tamil Nadu','Chennai'   UNION ALL SELECT 'Tamil Nadu','Coimbatore'
  UNION ALL SELECT 'Tamil Nadu','Madurai'
  UNION ALL SELECT 'Telangana','Hyderabad'  UNION ALL SELECT 'Telangana','Warangal'
  UNION ALL SELECT 'West Bengal','Kolkata'  UNION ALL SELECT 'West Bengal','Siliguri'
  UNION ALL SELECT 'West Bengal','Durgapur'
  UNION ALL SELECT 'Gujarat','Ahmedabad'    UNION ALL SELECT 'Gujarat','Surat'
  UNION ALL SELECT 'Gujarat','Vadodara'     UNION ALL SELECT 'Gujarat','Rajkot'
  UNION ALL SELECT 'Rajasthan','Jaipur'     UNION ALL SELECT 'Rajasthan','Jodhpur'
  UNION ALL SELECT 'Rajasthan','Udaipur'    UNION ALL SELECT 'Rajasthan','Kota'
  UNION ALL SELECT 'Uttar Pradesh','Lucknow'   UNION ALL SELECT 'Uttar Pradesh','Noida'
  UNION ALL SELECT 'Uttar Pradesh','Ghaziabad' UNION ALL SELECT 'Uttar Pradesh','Kanpur'
  UNION ALL SELECT 'Uttar Pradesh','Varanasi'  UNION ALL SELECT 'Uttar Pradesh','Agra'
  UNION ALL SELECT 'Haryana','Gurugram'     UNION ALL SELECT 'Haryana','Faridabad'
  UNION ALL SELECT 'Haryana','Ambala'       UNION ALL SELECT 'Haryana','Panipat'
  UNION ALL SELECT 'Punjab','Ludhiana'      UNION ALL SELECT 'Punjab','Amritsar'
  UNION ALL SELECT 'Punjab','Jalandhar'
  UNION ALL SELECT 'Kerala','Kochi'         UNION ALL SELECT 'Kerala','Thiruvananthapuram'
  UNION ALL SELECT 'Kerala','Kozhikode'
  UNION ALL SELECT 'Madhya Pradesh','Bhopal' UNION ALL SELECT 'Madhya Pradesh','Indore'
  UNION ALL SELECT 'Bihar','Patna'          UNION ALL SELECT 'Bihar','Gaya'
  UNION ALL SELECT 'Odisha','Bhubaneswar'   UNION ALL SELECT 'Odisha','Cuttack'
  UNION ALL SELECT 'Assam','Guwahati'
  UNION ALL SELECT 'Jharkhand','Ranchi'     UNION ALL SELECT 'Jharkhand','Jamshedpur'
  UNION ALL SELECT 'Chhattisgarh','Raipur'
  UNION ALL SELECT 'Uttarakhand','Dehradun' UNION ALL SELECT 'Uttarakhand','Haridwar'
  UNION ALL SELECT 'Himachal Pradesh','Shimla'
  UNION ALL SELECT 'Goa','Panaji'           UNION ALL SELECT 'Chandigarh','Chandigarh'
  UNION ALL SELECT 'Jammu and Kashmir','Srinagar'
  UNION ALL SELECT 'Jammu and Kashmir','Jammu'
  UNION ALL SELECT 'Andhra Pradesh','Visakhapatnam'
  UNION ALL SELECT 'Andhra Pradesh','Vijayawada'
) c ON c.st = s.name
WHERE s.country_id = @in;

-- =====================================================================
-- 3. Foreign keys on the records that carry an address
-- =====================================================================

DROP PROCEDURE IF EXISTS add_geo_col;
DELIMITER //
CREATE PROCEDURE add_geo_col(IN tbl VARCHAR(64), IN col VARCHAR(64), IN ddl VARCHAR(255))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = tbl AND column_name = col) THEN
        SET @s = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN ', ddl);
        PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
    END IF;
END //
DELIMITER ;

CALL add_geo_col('schools',  'country_id', 'country_id BIGINT UNSIGNED NULL');
CALL add_geo_col('schools',  'state_id',   'state_id   BIGINT UNSIGNED NULL');
CALL add_geo_col('schools',  'city_id',    'city_id    BIGINT UNSIGNED NULL');
CALL add_geo_col('students', 'state_id',   'state_id   BIGINT UNSIGNED NULL');
CALL add_geo_col('students', 'city_id',    'city_id    BIGINT UNSIGNED NULL');
CALL add_geo_col('staff',    'state_id',   'state_id   BIGINT UNSIGNED NULL');
CALL add_geo_col('staff',    'city_id',    'city_id    BIGINT UNSIGNED NULL');

DROP PROCEDURE add_geo_col;

-- =====================================================================
-- 4. Best-effort backfill. Only exact, case-insensitive name matches are
--    taken; anything else keeps a NULL FK and is reported below.
-- =====================================================================

UPDATE schools sc
JOIN states st ON st.name = sc.state
JOIN countries co ON co.id = st.country_id
SET sc.state_id = st.id, sc.country_id = co.id
WHERE sc.state_id IS NULL AND sc.state IS NOT NULL;

-- Second pass: schools that stored the code ('UP') rather than the name.
UPDATE schools sc
JOIN states st ON st.code = sc.state
JOIN countries co ON co.id = st.country_id
SET sc.state_id = st.id, sc.country_id = co.id
WHERE sc.state_id IS NULL AND sc.state IS NOT NULL;

UPDATE schools sc
JOIN cities ci ON ci.name = sc.city AND ci.state_id = sc.state_id
SET sc.city_id = ci.id
WHERE sc.city_id IS NULL AND sc.state_id IS NOT NULL;

-- Students and staff carry no country of their own; they follow their school's.
UPDATE students s
JOIN schools sc ON sc.id = s.school_id
JOIN cities ci  ON ci.name = s.city
JOIN states st  ON st.id = ci.state_id AND st.country_id = sc.country_id
SET s.city_id = ci.id, s.state_id = st.id
WHERE s.city_id IS NULL AND s.city IS NOT NULL;

UPDATE staff sf
JOIN schools sc ON sc.id = sf.school_id
JOIN cities ci  ON ci.name = sf.city
JOIN states st  ON st.id = ci.state_id AND st.country_id = sc.country_id
SET sf.city_id = ci.id, sf.state_id = st.id
WHERE sf.city_id IS NULL AND sf.city IS NOT NULL;

-- =====================================================================
-- 5. What could not be matched — clean these up by hand
-- =====================================================================

SELECT 'countries' AS seeded, COUNT(*) AS n FROM countries
UNION ALL SELECT 'states', COUNT(*) FROM states
UNION ALL SELECT 'cities', COUNT(*) FROM cities;

SELECT 'schools'  AS unmatched, id, CONCAT(IFNULL(city,''), ' / ', IFNULL(state,'')) AS was
FROM schools  WHERE state IS NOT NULL AND state <> '' AND state_id IS NULL
UNION ALL
SELECT 'students', id, CONCAT(IFNULL(city,''), ' / ', IFNULL(state,''))
FROM students WHERE city  IS NOT NULL AND city  <> '' AND city_id  IS NULL
UNION ALL
SELECT 'staff',    id, CONCAT(IFNULL(city,''), ' / ', IFNULL(state,''))
FROM staff    WHERE city  IS NOT NULL AND city  <> '' AND city_id  IS NULL;
