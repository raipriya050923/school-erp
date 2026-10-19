-- 024: outbound mail settings as data, so the platform owner can change them
--
-- SMTP host, port, sender and mailbox password live in appsettings.json today. That means a
-- changed mailbox needs a redeploy, and — worse — the password sits in a file that is tracked
-- in git, where it stays in the history for ever even after it is edited out.
--
-- This moves them into one row that the platform console writes.
--
--   * Exactly one row, id = 1. Mail is platform-wide: every school's messages leave from the
--     same mailbox, and a per-school sender is a separate feature with its own verification
--     problem (you cannot send as a domain you do not control).
--   * password_encrypted is ciphertext, never the password. The API protects it with ASP.NET
--     Data Protection on the way in and never returns it on the way out — the console shows
--     whether one is set, not what it is.
--   * Every column is nullable and the row may be absent entirely. With no row the application
--     falls back to appsettings.json, so an environment that has not been through the console
--     keeps working exactly as before.
--
-- Safe to re-run: CREATE TABLE IF NOT EXISTS and an INSERT guarded on the row not existing.

CREATE TABLE IF NOT EXISTS email_settings (
    -- Pinned to 1 by the CHECK below: this is a settings row, not a collection.
    id                 TINYINT UNSIGNED NOT NULL DEFAULT 1,

    smtp_host          VARCHAR(190) NULL,
    smtp_port          INT          NOT NULL DEFAULT 587,

    -- SSL on connect (465) versus STARTTLS upgrade (587). Not interchangeable, and which one
    -- works is a property of the host and the machine's certificate store rather than a
    -- preference — so both are stored rather than derived from the port.
    use_ssl            TINYINT(1)   NOT NULL DEFAULT 0,
    use_start_tls      TINYINT(1)   NOT NULL DEFAULT 1,

    -- The login, when it differs from the From address. Most hosted providers want them equal.
    user_name          VARCHAR(190) NULL,
    sender_email       VARCHAR(190) NULL,
    sender_name        VARCHAR(120) NULL,

    -- Where the console's "send a test" goes when no address is given.
    test_recipient     VARCHAR(190) NULL,

    -- Ciphertext. Never the password, and never returned by the API.
    password_encrypted TEXT         NULL,

    updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Who last changed it. Mail going out as the wrong sender is the kind of thing someone has
    -- to be asked about afterwards.
    updated_by         BIGINT UNSIGNED NULL,

    PRIMARY KEY (id),
    CONSTRAINT chk_email_settings_single CHECK (id = 1),
    CONSTRAINT fk_es_user FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- The empty row, so the console has something to edit and the application has one shape to
-- read. Left entirely NULL: a blank host is what keeps the appsettings.json fallback in play,
-- and seeding a host here would silently take over from a working configuration.
INSERT INTO email_settings (id, smtp_port, use_ssl, use_start_tls)
SELECT 1, 587, 0, 1
WHERE NOT EXISTS (SELECT 1 FROM email_settings WHERE id = 1);
