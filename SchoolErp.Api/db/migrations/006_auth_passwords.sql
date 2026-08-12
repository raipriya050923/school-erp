-- =====================================================================
-- Migration 006 — real bcrypt password hashes for auth
-- =====================================================================
-- Sets every seeded user's password to the bcrypt hash of "Password@123"
-- so the /api/auth/login endpoint can verify credentials.
--   mysql -u root -p school_erp < SchoolErp.Api/db/migrations/006_auth_passwords.sql
-- =====================================================================

USE school_erp;
SET SQL_SAFE_UPDATES = 0;

-- bcrypt (work factor 11) hash of 'Password@123'
UPDATE users SET password_hash = '$2a$11$FRqslbZ8hV5AeC310L.D/eoiaL0bqUBoTn8aEV9BSknKKiHoCxyPW';

-- make sure the password_resets table can store our tokens (schema already has it)
SET SQL_SAFE_UPDATES = 1;

SELECT 'users updated' AS metric, COUNT(*) AS n FROM users;
