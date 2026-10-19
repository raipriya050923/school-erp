-- 025: a second way to send mail — Microsoft Graph beside Hostinger SMTP
--
-- Migration 024 moved the SMTP settings into the database. This adds the other provider the
-- platform now has: Microsoft Graph, sending as noreply@kssinfonet.com with OAuth 2.0 client
-- credentials and Exchange Application RBAC. It is not SMTP with different values — there is
-- no mailbox password, the application authenticates as itself against Entra and posts the
-- message to Graph.
--
-- Both configurations live side by side in the same row and `provider` says which one is in
-- use. Keeping the inactive one's settings is the point: switching providers to see whether a
-- delivery problem follows the mail or the route is a thirty-second change, not a re-entry of
-- four fields under pressure.
--
--   * graph_client_secret_encrypted is ciphertext, like the SMTP password before it. The
--     handover is explicit that the secret must never be committed or logged; it is never
--     returned by the API either.
--   * tenant id, client id, from address and from name are not secrets — the handover lists
--     them as ordinary configuration — so they are stored in the clear and shown in the console.
--
-- Safe to re-run: every column is added behind an information_schema check.

/* ---- which provider is live ---- */

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'email_settings'
       AND column_name = 'provider') = 0,
    'ALTER TABLE email_settings
       ADD COLUMN provider ENUM(''smtp'',''graph'') NOT NULL DEFAULT ''smtp'' AFTER id',
    'SELECT ''email_settings.provider already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* ---- the Graph application's identity ---- */

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'email_settings'
       AND column_name = 'graph_tenant_id') = 0,
    'ALTER TABLE email_settings
       ADD COLUMN graph_tenant_id VARCHAR(100) NULL,
       ADD COLUMN graph_client_id VARCHAR(100) NULL,
       -- Ciphertext. The handover: "Client Secret must never be committed to Git/GitHub."
       ADD COLUMN graph_client_secret_encrypted TEXT NULL,
       -- Graph sends as a named mailbox rather than as whoever authenticated, so the address
       -- is part of the send URL and not merely a From header.
       ADD COLUMN graph_from_address VARCHAR(190) NULL,
       ADD COLUMN graph_from_name VARCHAR(120) NULL',
    'SELECT ''email_settings graph columns already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
