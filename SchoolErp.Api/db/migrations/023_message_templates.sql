-- 023: message templates — one library for SMS and email, owned by the platform
--
-- Every outbound message the product sends is currently written in C#: WelcomeEmail and
-- PasswordResetEmail compose their own subject and body, so changing a word means a
-- deployment, and a school that wants its own wording cannot have it at all.
--
-- This moves the words into data:
--
--   * message_templates holds one row per (school, channel, code, locale). A row with
--     school_id NULL is the platform's default, which every school inherits. A row with a
--     school_id is that school's override of it.
--   * editable_by decides whether a school is allowed to override at all. The platform owns
--     this per template, not per school — an OTP body is never a school's to rewrite, while
--     a fee reminder usually is.
--   * message_log records what actually went out. SMS costs money per message and someone
--     will ask whether a parent received one; without this there is no answer.
--
-- On why the platform owns the text: India's DLT rules require every template to be
-- registered with the telecom regulator before delivery, and the sent text must match the
-- registered text exactly — a school editing one word silently stops delivery to every
-- Indian number. provider_template_id carries that registration. Schools in countries with
-- no such rule can still be let in, per template, via editable_by.
--
-- Safe to re-run: every write is CREATE TABLE IF NOT EXISTS, INSERT ... ON DUPLICATE KEY
-- UPDATE id = id, or guarded by an information_schema check.

/* ---- the library ---- */

CREATE TABLE IF NOT EXISTS message_templates (
    id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    -- NULL is the platform default that every school falls back to. A school_id row is an
    -- override of the default with the same (channel, code, locale).
    school_id            BIGINT UNSIGNED NULL,

    channel              ENUM('sms','email') NOT NULL,

    -- What the message is for, not what it says: 'otp_login', 'welcome', 'fee_reminder'.
    -- Code plus channel is what the sending code asks for; the body is free to change.
    code                 VARCHAR(50)  NOT NULL,

    -- 'en', 'ne'. A school may publish the same code in more than one language; resolution
    -- falls back to 'en' when the asked-for locale has no row.
    locale               VARCHAR(10)  NOT NULL DEFAULT 'en',

    -- Email only; NULL for SMS, which has no subject line.
    subject              VARCHAR(200) NULL,

    -- Placeholders are {{name}}. Kept deliberately short for SMS: a GSM-7 message is 160
    -- characters and a longer one is billed as two.
    body                 TEXT         NOT NULL,

    -- The id this template is registered under with the SMS provider / telecom regulator.
    -- NULL until registered, and only meaningful for channel = 'sms'.
    provider_template_id VARCHAR(80)  NULL,

    -- Who may change the body. Only meaningful on a platform row (school_id IS NULL): it is
    -- the platform granting or withholding permission, and the API refuses a school override
    -- of a template whose default says 'platform'.
    editable_by          ENUM('platform','school') NOT NULL DEFAULT 'platform',

    -- A school switching a message off for itself is the common case and needs no permission.
    is_active            TINYINT(1)   NOT NULL DEFAULT 1,

    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    -- One row per school per message per language. MySQL treats NULLs as distinct in a unique
    -- index, so this does NOT constrain the platform rows; uq_mt_platform below does that.
    UNIQUE KEY uq_mt_school (school_id, channel, code, locale),

    INDEX idx_mt_lookup (channel, code, locale),

    CONSTRAINT fk_mt_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- The platform defaults need their own uniqueness, which uq_mt_school cannot give them: in
-- MySQL every NULL school_id counts as distinct, so (NULL,'sms','otp_login','en') could be
-- inserted twice over. school_key folds NULL to 0 and makes the constraint real.
--
-- VIRTUAL, not STORED: MySQL refuses a foreign key with ON DELETE CASCADE on a column that a
-- STORED generated column is derived from, and losing the cascade would leave a deleted
-- school's overrides behind. A virtual column carries no such restriction and still indexes.
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'message_templates'
       AND column_name = 'school_key') = 0,
    'ALTER TABLE message_templates
       ADD COLUMN school_key BIGINT UNSIGNED AS (IFNULL(school_id, 0)) VIRTUAL,
       ADD UNIQUE KEY uq_mt_platform (school_key, channel, code, locale)',
    'SELECT ''message_templates.school_key already present''');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* ---- what actually went out ---- */

CREATE TABLE IF NOT EXISTS message_log (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    -- NULL for a message that belongs to no tenant — a platform notice, or an OTP sent
    -- before the sender's school is known.
    school_id           BIGINT UNSIGNED NULL,

    channel             ENUM('sms','email') NOT NULL,
    code                VARCHAR(50)  NOT NULL,

    -- The phone or address it went to. Kept as sent, so a wrong number stays diagnosable.
    recipient           VARCHAR(190) NOT NULL,

    -- The rendered text, not the template: the template may be edited afterwards, and the
    -- question is always what this person was actually told.
    subject             VARCHAR(200) NULL,
    body                TEXT         NOT NULL,

    status              ENUM('queued','sent','failed') NOT NULL DEFAULT 'queued',
    provider_message_id VARCHAR(120) NULL,
    error               VARCHAR(500) NULL,

    -- Smallest currency unit (paisa), so costs stay integers. NULL when the provider does
    -- not report one.
    cost_minor          INT          NULL,

    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at             TIMESTAMP    NULL,

    PRIMARY KEY (id),
    INDEX idx_ml_school_date (school_id, created_at),
    INDEX idx_ml_recipient (recipient),
    INDEX idx_ml_status (status, created_at),

    CONSTRAINT fk_ml_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

/* ---- the platform defaults ----
   ON DUPLICATE KEY UPDATE id = id so re-running leaves an edited default alone: the platform
   may have reworded these since, and a migration should not undo that. */

INSERT INTO message_templates
    (school_id, channel, code, locale, subject, body, editable_by, is_active)
VALUES
    -- Carries a login code, so it is never a school's to reword, in any country.
    (NULL, 'sms', 'otp_login', 'en', NULL,
     '{{code}} is your {{school_name}} login code. It expires in {{minutes}} minutes. Do not share it with anyone.',
     'platform', 1),

    -- Deliberately carries no password: an SMS sits in plaintext on the handset for ever and
    -- in the provider''s logs. The portal link is where a password gets set.
    (NULL, 'sms', 'welcome', 'en', NULL,
     'Welcome to {{school_name}}, {{name}}. Your username is {{username}}. Set your password at {{portal_url}}',
     'platform', 1),

    (NULL, 'sms', 'fee_reminder', 'en', NULL,
     'Dear {{guardian_name}}, fees of {{amount}} for {{student_name}} are due on {{due_date}}. - {{school_name}}',
     'school', 1),

    (NULL, 'email', 'welcome', 'en',
     'Welcome to {{school_name}}',
     'Hello {{name}},\n\nYour {{school_name}} account is ready.\n\nUsername: {{username}}\nSign in: {{portal_url}}\n\nPlease change your password after signing in.',
     'platform', 1),

    (NULL, 'email', 'fee_reminder', 'en',
     'Fees due for {{student_name}} - {{school_name}}',
     'Dear {{guardian_name}},\n\nFees of {{amount}} for {{student_name}} are due on {{due_date}}.\n\n{{school_name}}',
     'school', 1)
ON DUPLICATE KEY UPDATE id = id;
