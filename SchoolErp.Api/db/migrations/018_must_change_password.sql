-- 018: force a password change on first login
--
-- Every account is provisioned with a password an admin has read off a screen — in development
-- that is the shared `Accounts:FixedPassword`, so at present every login on the system is
-- Admin@123. The hash is a real bcrypt hash, but a password the school handed out is not a
-- secret, and nothing recorded whether the holder ever replaced it.
--
--   must_change_password  set when an account is minted or its password is reset by someone
--                         else; cleared the moment the holder chooses their own.
--   password_changed_at   when they last did, so an audit can tell a fresh account from a
--                         dormant one.
--
-- Safe to re-run: each ALTER is guarded on information_schema.

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'must_change_password') = 0,
    'ALTER TABLE users ADD COLUMN must_change_password TINYINT(1) NOT NULL DEFAULT 0 AFTER password_hash',
    'SELECT ''users.must_change_password already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'password_changed_at') = 0,
    'ALTER TABLE users ADD COLUMN password_changed_at DATETIME NULL AFTER must_change_password',
    'SELECT ''users.password_changed_at already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Existing accounts are left alone deliberately. They all currently share the development
-- password, so flagging them would force a change on every test login at once and make the
-- seeded accounts unusable for development. Run this when the system is ready for it:
--
--   UPDATE users SET must_change_password = 1 WHERE deleted_at IS NULL AND user_type <> 'super_admin';

SELECT COUNT(*) AS users,
       SUM(must_change_password) AS must_change,
       SUM(password_changed_at IS NOT NULL) AS have_changed
FROM users WHERE deleted_at IS NULL;
