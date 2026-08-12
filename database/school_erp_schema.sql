-- =====================================================================
-- SCHOOL ERP - Multi-Tenant SaaS Database Schema (MySQL 8.0+)
-- =====================================================================
-- Tenancy model : Shared database, shared schema.
--                 Every tenant-scoped table carries `school_id`.
-- Charset       : utf8mb4 (full Unicode incl. emojis in messages)
-- Engine        : InnoDB (FK support, row-level locking)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS school_erp
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE school_erp;

SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================================
-- SECTION 1 : PLATFORM / SUPER ADMIN
-- =====================================================================

-- 1.1 Schools (Tenants)
CREATE TABLE schools (
    id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_code       VARCHAR(20)  NOT NULL UNIQUE,          -- short tenant code e.g. GHS001
    name              VARCHAR(150) NOT NULL,
    subdomain         VARCHAR(63)  NOT NULL UNIQUE,          -- tenant subdomain e.g. ghs.myerp.com
    custom_domain     VARCHAR(255) NULL UNIQUE,
    logo_url          VARCHAR(500) NULL,
    email             VARCHAR(150) NOT NULL,
    phone             VARCHAR(20)  NOT NULL,
    address_line1     VARCHAR(255) NULL,
    address_line2     VARCHAR(255) NULL,
    city              VARCHAR(100) NULL,
    state             VARCHAR(100) NULL,
    country           VARCHAR(100) NULL,
    postal_code       VARCHAR(20)  NULL,
    timezone          VARCHAR(64)  NOT NULL DEFAULT 'Asia/Kathmandu',
    currency          CHAR(3)      NOT NULL DEFAULT 'NPR',
    registration_no   VARCHAR(100) NULL,                     -- govt. registration number
    affiliation_board VARCHAR(100) NULL,                     -- CBSE / NEB / State board etc.
    status            ENUM('pending','active','suspended','terminated') NOT NULL DEFAULT 'pending',
    onboarded_at      DATETIME NULL,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at        TIMESTAMP NULL,
    INDEX idx_schools_status (status)
) ENGINE=InnoDB;

-- 1.2 Subscription plans
CREATE TABLE subscription_plans (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(80)  NOT NULL,                    -- Basic / Standard / Premium
    slug           VARCHAR(80)  NOT NULL UNIQUE,
    description    TEXT NULL,
    price_monthly  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    price_yearly   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    max_students   INT UNSIGNED NULL,                        -- NULL = unlimited
    max_staff      INT UNSIGNED NULL,
    max_storage_mb INT UNSIGNED NULL,
    trial_days     SMALLINT UNSIGNED NOT NULL DEFAULT 14,
    is_active      TINYINT(1) NOT NULL DEFAULT 1,
    sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 1.3 Feature catalogue (feature flags / modules)
CREATE TABLE features (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(80)  NOT NULL UNIQUE,                -- e.g. HOSTEL, TRANSPORT, WHATSAPP
    name        VARCHAR(120) NOT NULL,
    description TEXT NULL,
    is_active   TINYINT(1) NOT NULL DEFAULT 1,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 1.4 Plan <-> Feature mapping
CREATE TABLE plan_features (
    plan_id    BIGINT UNSIGNED NOT NULL,
    feature_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (plan_id, feature_id),
    CONSTRAINT fk_pf_plan    FOREIGN KEY (plan_id)    REFERENCES subscription_plans(id) ON DELETE CASCADE,
    CONSTRAINT fk_pf_feature FOREIGN KEY (feature_id) REFERENCES features(id)          ON DELETE CASCADE
) ENGINE=InnoDB;

-- 1.5 Per-school feature overrides (enable/disable beyond plan)
CREATE TABLE school_features (
    school_id  BIGINT UNSIGNED NOT NULL,
    feature_id BIGINT UNSIGNED NOT NULL,
    is_enabled TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (school_id, feature_id),
    CONSTRAINT fk_sf_school  FOREIGN KEY (school_id)  REFERENCES schools(id)  ON DELETE CASCADE,
    CONSTRAINT fk_sf_feature FOREIGN KEY (feature_id) REFERENCES features(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 1.6 School subscriptions
CREATE TABLE school_subscriptions (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id      BIGINT UNSIGNED NOT NULL,
    plan_id        BIGINT UNSIGNED NOT NULL,
    billing_cycle  ENUM('monthly','yearly') NOT NULL DEFAULT 'yearly',
    start_date     DATE NOT NULL,
    end_date       DATE NOT NULL,
    price          DECIMAL(12,2) NOT NULL,                   -- price locked at purchase time
    status         ENUM('trial','active','past_due','cancelled','expired') NOT NULL DEFAULT 'trial',
    auto_renew     TINYINT(1) NOT NULL DEFAULT 1,
    cancelled_at   DATETIME NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_ss_school_status (school_id, status),
    CONSTRAINT fk_ss_school FOREIGN KEY (school_id) REFERENCES schools(id),
    CONSTRAINT fk_ss_plan   FOREIGN KEY (plan_id)   REFERENCES subscription_plans(id)
) ENGINE=InnoDB;

-- 1.7 Platform invoices (SaaS billing to schools)
CREATE TABLE platform_invoices (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id       BIGINT UNSIGNED NOT NULL,
    subscription_id BIGINT UNSIGNED NOT NULL,
    invoice_no      VARCHAR(40) NOT NULL UNIQUE,
    amount          DECIMAL(12,2) NOT NULL,
    tax_amount      DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_amount    DECIMAL(12,2) NOT NULL,
    due_date        DATE NOT NULL,
    status          ENUM('draft','sent','paid','overdue','void') NOT NULL DEFAULT 'draft',
    issued_at       DATETIME NULL,
    paid_at         DATETIME NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pi_school (school_id, status),
    CONSTRAINT fk_pi_school FOREIGN KEY (school_id)       REFERENCES schools(id),
    CONSTRAINT fk_pi_sub    FOREIGN KEY (subscription_id) REFERENCES school_subscriptions(id)
) ENGINE=InnoDB;

-- 1.8 Platform payments
CREATE TABLE platform_payments (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    invoice_id     BIGINT UNSIGNED NOT NULL,
    school_id      BIGINT UNSIGNED NOT NULL,
    amount         DECIMAL(12,2) NOT NULL,
    method         ENUM('card','bank_transfer','esewa','khalti','paypal','stripe','cash','other') NOT NULL,
    transaction_ref VARCHAR(120) NULL,
    status         ENUM('pending','success','failed','refunded') NOT NULL DEFAULT 'pending',
    paid_at        DATETIME NULL,
    remarks        VARCHAR(255) NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pp_school (school_id),
    CONSTRAINT fk_pp_invoice FOREIGN KEY (invoice_id) REFERENCES platform_invoices(id),
    CONSTRAINT fk_pp_school  FOREIGN KEY (school_id)  REFERENCES schools(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 2 : USERS, ROLES & PERMISSIONS (all portals)
-- =====================================================================

-- 2.1 Users — one row per login across every portal.
--     school_id NULL  => platform-level user (super admin / support)
CREATE TABLE users (
    id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id         BIGINT UNSIGNED NULL,
    user_type         ENUM('super_admin','school_admin','teacher','staff','student','parent') NOT NULL,
    username          VARCHAR(80)  NOT NULL,
    email             VARCHAR(150) NULL,
    phone             VARCHAR(20)  NULL,
    password_hash     VARCHAR(255) NOT NULL,
    full_name         VARCHAR(150) NOT NULL,
    avatar_url        VARCHAR(500) NULL,
    email_verified_at DATETIME NULL,
    two_fa_secret     VARCHAR(64) NULL,
    is_active         TINYINT(1) NOT NULL DEFAULT 1,
    last_login_at     DATETIME NULL,
    last_login_ip     VARCHAR(45) NULL,
    failed_attempts   TINYINT UNSIGNED NOT NULL DEFAULT 0,
    locked_until      DATETIME NULL,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at        TIMESTAMP NULL,
    UNIQUE KEY uq_users_username_school (school_id, username),
    UNIQUE KEY uq_users_email_school    (school_id, email),
    INDEX idx_users_type (school_id, user_type),
    CONSTRAINT fk_users_school FOREIGN KEY (school_id) REFERENCES schools(id)
) ENGINE=InnoDB;

-- 2.2 Password resets / OTP
CREATE TABLE password_resets (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id    BIGINT UNSIGNED NOT NULL,
    token      VARCHAR(120) NOT NULL,
    channel    ENUM('email','sms') NOT NULL DEFAULT 'email',
    expires_at DATETIME NOT NULL,
    used_at    DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pr_token (token),
    CONSTRAINT fk_pr_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.3 Login sessions / devices
CREATE TABLE user_sessions (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT UNSIGNED NOT NULL,
    token_hash   VARCHAR(255) NOT NULL,
    device_info  VARCHAR(255) NULL,
    ip_address   VARCHAR(45) NULL,
    expires_at   DATETIME NOT NULL,
    revoked_at   DATETIME NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_us_user (user_id),
    CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.4 Roles (school_id NULL => platform roles; per-school custom roles allowed)
CREATE TABLE roles (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NULL,
    name        VARCHAR(80) NOT NULL,
    slug        VARCHAR(80) NOT NULL,
    description VARCHAR(255) NULL,
    is_system   TINYINT(1) NOT NULL DEFAULT 0,               -- system roles cannot be deleted
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_roles_slug_school (school_id, slug),
    CONSTRAINT fk_roles_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.5 Permissions (global catalogue)
CREATE TABLE permissions (
    id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    module VARCHAR(80) NOT NULL,                             -- e.g. students, fees, exams
    action VARCHAR(80) NOT NULL,                             -- view / create / edit / delete / export
    slug   VARCHAR(160) NOT NULL UNIQUE                      -- e.g. students.create
) ENGINE=InnoDB;

CREATE TABLE role_permissions (
    role_id       BIGINT UNSIGNED NOT NULL,
    permission_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id)       REFERENCES roles(id)       ON DELETE CASCADE,
    CONSTRAINT fk_rp_perm FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE user_roles (
    user_id BIGINT UNSIGNED NOT NULL,
    role_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 3 : PLATFORM OPERATIONS (support, announcements, audit, etc.)
-- =====================================================================

-- 3.1 Support tickets (schools -> platform)
CREATE TABLE support_tickets (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    raised_by   BIGINT UNSIGNED NOT NULL,                    -- users.id
    assigned_to BIGINT UNSIGNED NULL,                        -- platform staff users.id
    ticket_no   VARCHAR(30) NOT NULL UNIQUE,
    subject     VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    priority    ENUM('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
    status      ENUM('open','in_progress','waiting','resolved','closed') NOT NULL DEFAULT 'open',
    closed_at   DATETIME NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_st_school_status (school_id, status),
    CONSTRAINT fk_st_school   FOREIGN KEY (school_id)   REFERENCES schools(id),
    CONSTRAINT fk_st_raised   FOREIGN KEY (raised_by)   REFERENCES users(id),
    CONSTRAINT fk_st_assigned FOREIGN KEY (assigned_to) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE support_ticket_replies (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_id  BIGINT UNSIGNED NOT NULL,
    user_id    BIGINT UNSIGNED NOT NULL,
    message    TEXT NOT NULL,
    attachment_url VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_str_ticket FOREIGN KEY (ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE,
    CONSTRAINT fk_str_user   FOREIGN KEY (user_id)   REFERENCES users(id)
) ENGINE=InnoDB;

-- 3.2 Platform announcements (super admin -> schools)
CREATE TABLE platform_announcements (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    body         TEXT NOT NULL,
    audience     ENUM('all_schools','selected_schools') NOT NULL DEFAULT 'all_schools',
    starts_at    DATETIME NOT NULL,
    ends_at      DATETIME NULL,
    is_published TINYINT(1) NOT NULL DEFAULT 0,
    created_by   BIGINT UNSIGNED NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pa_creator FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE platform_announcement_schools (
    announcement_id BIGINT UNSIGNED NOT NULL,
    school_id       BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (announcement_id, school_id),
    CONSTRAINT fk_pas_ann    FOREIGN KEY (announcement_id) REFERENCES platform_announcements(id) ON DELETE CASCADE,
    CONSTRAINT fk_pas_school FOREIGN KEY (school_id)       REFERENCES schools(id)                ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3.3 In-app notifications (any portal)
CREATE TABLE notifications (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NULL,
    user_id    BIGINT UNSIGNED NOT NULL,
    title      VARCHAR(200) NOT NULL,
    body       TEXT NULL,
    type       VARCHAR(60) NOT NULL DEFAULT 'general',       -- fee_due, homework, exam, notice...
    ref_table  VARCHAR(60) NULL,                             -- polymorphic reference
    ref_id     BIGINT UNSIGNED NULL,
    read_at    DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notif_user (user_id, read_at),
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3.4 Audit logs (platform + school scoped)
CREATE TABLE audit_logs (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NULL,                         -- NULL = platform action
    user_id    BIGINT UNSIGNED NULL,
    action     VARCHAR(80)  NOT NULL,                        -- create / update / delete / login...
    module     VARCHAR(80)  NOT NULL,
    ref_table  VARCHAR(60)  NULL,
    ref_id     BIGINT UNSIGNED NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_al_school_module (school_id, module, created_at),
    INDEX idx_al_user (user_id)
) ENGINE=InnoDB;

-- 3.5 Backups
CREATE TABLE backups (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NULL,                        -- NULL = full platform backup
    file_name   VARCHAR(255) NOT NULL,
    file_url    VARCHAR(500) NULL,
    size_bytes  BIGINT UNSIGNED NULL,
    backup_type ENUM('manual','scheduled') NOT NULL DEFAULT 'scheduled',
    status      ENUM('running','completed','failed') NOT NULL DEFAULT 'running',
    started_at  DATETIME NOT NULL,
    finished_at DATETIME NULL,
    created_by  BIGINT UNSIGNED NULL,
    CONSTRAINT fk_bk_school FOREIGN KEY (school_id) REFERENCES schools(id)
) ENGINE=InnoDB;

-- 3.6 Global settings (platform-wide key/value)
CREATE TABLE global_settings (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `key`       VARCHAR(120) NOT NULL UNIQUE,
    `value`     TEXT NULL,
    value_type  ENUM('string','int','bool','json') NOT NULL DEFAULT 'string',
    updated_by  BIGINT UNSIGNED NULL,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3.7 Per-school settings (tenant configuration)
CREATE TABLE school_settings (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    `key`      VARCHAR(120) NOT NULL,
    `value`    TEXT NULL,
    value_type ENUM('string','int','bool','json') NOT NULL DEFAULT 'string',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ss_key (school_id, `key`),
    CONSTRAINT fk_setting_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3.8 API keys & logs
CREATE TABLE api_keys (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NULL,
    name        VARCHAR(120) NOT NULL,
    key_hash    VARCHAR(255) NOT NULL,
    scopes      JSON NULL,
    rate_limit  INT UNSIGNED NULL,
    last_used_at DATETIME NULL,
    expires_at  DATETIME NULL,
    revoked_at  DATETIME NULL,
    created_by  BIGINT UNSIGNED NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ak_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE api_request_logs (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    api_key_id  BIGINT UNSIGNED NULL,
    school_id   BIGINT UNSIGNED NULL,
    method      VARCHAR(10) NOT NULL,
    endpoint    VARCHAR(255) NOT NULL,
    status_code SMALLINT UNSIGNED NOT NULL,
    duration_ms INT UNSIGNED NULL,
    ip_address  VARCHAR(45) NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_arl_key (api_key_id, created_at)
) ENGINE=InnoDB;

-- 3.9 System health snapshots
CREATE TABLE system_health_logs (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cpu_percent     DECIMAL(5,2) NULL,
    memory_percent  DECIMAL(5,2) NULL,
    disk_percent    DECIMAL(5,2) NULL,
    db_connections  INT UNSIGNED NULL,
    queue_pending   INT UNSIGNED NULL,
    status          ENUM('healthy','degraded','down') NOT NULL DEFAULT 'healthy',
    notes           VARCHAR(255) NULL,
    recorded_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_shl_time (recorded_at)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 4 : ACADEMIC STRUCTURE (per school)
-- =====================================================================

CREATE TABLE academic_years (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    name       VARCHAR(40) NOT NULL,                         -- e.g. 2025-2026
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL,
    is_current TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ay_name (school_id, name),
    CONSTRAINT fk_ay_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE classes (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    name       VARCHAR(50) NOT NULL,                         -- e.g. Grade 5
    numeric_level SMALLINT NULL,                             -- for ordering: 1..12
    is_active  TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY uq_class_name (school_id, name),
    CONSTRAINT fk_class_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE sections (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    class_id         BIGINT UNSIGNED NOT NULL,
    name             VARCHAR(20) NOT NULL,                   -- A / B / C
    capacity         SMALLINT UNSIGNED NULL,
    class_teacher_id BIGINT UNSIGNED NULL,                   -- staff.id
    room_no          VARCHAR(30) NULL,
    is_active        TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY uq_section (class_id, name),
    CONSTRAINT fk_sec_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_sec_class  FOREIGN KEY (class_id)  REFERENCES classes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE subjects (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    name       VARCHAR(100) NOT NULL,
    code       VARCHAR(30)  NULL,
    subject_type ENUM('theory','practical','both') NOT NULL DEFAULT 'theory',
    is_active  TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY uq_subject (school_id, name),
    CONSTRAINT fk_subj_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Subjects taught in a class (per academic year)
CREATE TABLE class_subjects (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    class_id         BIGINT UNSIGNED NOT NULL,
    subject_id       BIGINT UNSIGNED NOT NULL,
    is_optional      TINYINT(1) NOT NULL DEFAULT 0,
    full_marks       SMALLINT UNSIGNED NULL,
    pass_marks       SMALLINT UNSIGNED NULL,
    UNIQUE KEY uq_cs (academic_year_id, class_id, subject_id),
    CONSTRAINT fk_cs_school  FOREIGN KEY (school_id)        REFERENCES schools(id)        ON DELETE CASCADE,
    CONSTRAINT fk_cs_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_cs_class   FOREIGN KEY (class_id)         REFERENCES classes(id),
    CONSTRAINT fk_cs_subject FOREIGN KEY (subject_id)       REFERENCES subjects(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 5 : PEOPLE — STAFF / TEACHERS / STUDENTS / PARENTS
-- =====================================================================

-- 5.1 Staff (all employees; teachers included via staff_type)
CREATE TABLE staff (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id      BIGINT UNSIGNED NOT NULL,
    user_id        BIGINT UNSIGNED NULL,                     -- login account (nullable until created)
    employee_code  VARCHAR(30) NOT NULL,
    staff_type     ENUM('teacher','admin','accountant','librarian','driver','support','other') NOT NULL,
    first_name     VARCHAR(80) NOT NULL,
    last_name      VARCHAR(80) NOT NULL,
    gender         ENUM('male','female','other') NULL,
    dob            DATE NULL,
    blood_group    VARCHAR(5) NULL,
    email          VARCHAR(150) NULL,
    phone          VARCHAR(20) NULL,
    address        VARCHAR(255) NULL,
    photo_url      VARCHAR(500) NULL,
    qualification  VARCHAR(255) NULL,
    specialization VARCHAR(255) NULL,                        -- for teachers: subject expertise
    designation    VARCHAR(100) NULL,
    department     VARCHAR(100) NULL,
    joining_date   DATE NULL,
    leaving_date   DATE NULL,
    salary         DECIMAL(12,2) NULL,
    bank_account   VARCHAR(50) NULL,
    bank_name      VARCHAR(100) NULL,
    emergency_contact VARCHAR(20) NULL,
    documents      JSON NULL,                                -- [{name, url}, ...]
    status         ENUM('active','on_leave','resigned','terminated') NOT NULL DEFAULT 'active',
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at     TIMESTAMP NULL,
    UNIQUE KEY uq_staff_code (school_id, employee_code),
    INDEX idx_staff_type (school_id, staff_type, status),
    CONSTRAINT fk_staff_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_staff_user   FOREIGN KEY (user_id)   REFERENCES users(id)
) ENGINE=InnoDB;

-- Teacher <-> class-section-subject assignment (per academic year)
CREATE TABLE teacher_assignments (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    staff_id         BIGINT UNSIGNED NOT NULL,               -- must be staff_type = teacher
    class_id         BIGINT UNSIGNED NOT NULL,
    section_id       BIGINT UNSIGNED NOT NULL,
    subject_id       BIGINT UNSIGNED NOT NULL,
    UNIQUE KEY uq_ta (academic_year_id, section_id, subject_id, staff_id),
    INDEX idx_ta_teacher (staff_id, academic_year_id),
    CONSTRAINT fk_ta_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_ta_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_ta_staff   FOREIGN KEY (staff_id)         REFERENCES staff(id),
    CONSTRAINT fk_ta_class   FOREIGN KEY (class_id)         REFERENCES classes(id),
    CONSTRAINT fk_ta_section FOREIGN KEY (section_id)       REFERENCES sections(id),
    CONSTRAINT fk_ta_subject FOREIGN KEY (subject_id)       REFERENCES subjects(id)
) ENGINE=InnoDB;

-- 5.2 Students
CREATE TABLE students (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    user_id          BIGINT UNSIGNED NULL,                   -- student portal login
    admission_no     VARCHAR(30) NOT NULL,
    roll_no          VARCHAR(20) NULL,
    first_name       VARCHAR(80) NOT NULL,
    last_name        VARCHAR(80) NOT NULL,
    gender           ENUM('male','female','other') NULL,
    dob              DATE NULL,
    blood_group      VARCHAR(5) NULL,
    religion         VARCHAR(50) NULL,
    caste_category   VARCHAR(50) NULL,
    nationality      VARCHAR(50) NULL,
    photo_url        VARCHAR(500) NULL,
    email            VARCHAR(150) NULL,
    phone            VARCHAR(20) NULL,
    current_address  VARCHAR(255) NULL,
    permanent_address VARCHAR(255) NULL,
    admission_date   DATE NULL,
    previous_school  VARCHAR(200) NULL,
    medical_notes    TEXT NULL,
    documents        JSON NULL,                              -- birth cert, transfer cert...
    status           ENUM('active','inactive','transferred','graduated','dropped') NOT NULL DEFAULT 'active',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at       TIMESTAMP NULL,
    UNIQUE KEY uq_student_admission (school_id, admission_no),
    INDEX idx_student_status (school_id, status),
    CONSTRAINT fk_stu_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_stu_user   FOREIGN KEY (user_id)   REFERENCES users(id)
) ENGINE=InnoDB;

-- Enrollment: which class/section a student is in for a given academic year
CREATE TABLE student_enrollments (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    student_id       BIGINT UNSIGNED NOT NULL,
    class_id         BIGINT UNSIGNED NOT NULL,
    section_id       BIGINT UNSIGNED NOT NULL,
    roll_no          VARCHAR(20) NULL,
    enrolled_on      DATE NOT NULL,
    result_status    ENUM('ongoing','promoted','detained','passed_out') NOT NULL DEFAULT 'ongoing',
    UNIQUE KEY uq_enrollment (academic_year_id, student_id),
    INDEX idx_enr_section (academic_year_id, section_id),
    CONSTRAINT fk_enr_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_enr_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_enr_student FOREIGN KEY (student_id)       REFERENCES students(id) ON DELETE CASCADE,
    CONSTRAINT fk_enr_class   FOREIGN KEY (class_id)         REFERENCES classes(id),
    CONSTRAINT fk_enr_section FOREIGN KEY (section_id)       REFERENCES sections(id)
) ENGINE=InnoDB;

-- 5.3 Guardians / Parents
CREATE TABLE guardians (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    user_id     BIGINT UNSIGNED NULL,                        -- parent portal login (future)
    first_name  VARCHAR(80) NOT NULL,
    last_name   VARCHAR(80) NOT NULL,
    relation    ENUM('father','mother','guardian','other') NOT NULL,
    email       VARCHAR(150) NULL,
    phone       VARCHAR(20) NOT NULL,
    occupation  VARCHAR(100) NULL,
    address     VARCHAR(255) NULL,
    photo_url   VARCHAR(500) NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_guardian_phone (school_id, phone),
    CONSTRAINT fk_g_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_g_user   FOREIGN KEY (user_id)   REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE student_guardians (
    student_id  BIGINT UNSIGNED NOT NULL,
    guardian_id BIGINT UNSIGNED NOT NULL,
    is_primary  TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (student_id, guardian_id),
    CONSTRAINT fk_sg_student  FOREIGN KEY (student_id)  REFERENCES students(id)  ON DELETE CASCADE,
    CONSTRAINT fk_sg_guardian FOREIGN KEY (guardian_id) REFERENCES guardians(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 6 : ATTENDANCE
-- =====================================================================

CREATE TABLE student_attendance (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    student_id       BIGINT UNSIGNED NOT NULL,
    section_id       BIGINT UNSIGNED NOT NULL,
    attendance_date  DATE NOT NULL,
    status           ENUM('present','absent','late','half_day','excused') NOT NULL,
    remarks          VARCHAR(255) NULL,
    marked_by        BIGINT UNSIGNED NULL,                   -- users.id (teacher)
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_sa (student_id, attendance_date),
    INDEX idx_sa_section_date (section_id, attendance_date),
    CONSTRAINT fk_sa_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_sa_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_sa_student FOREIGN KEY (student_id)       REFERENCES students(id) ON DELETE CASCADE,
    CONSTRAINT fk_sa_section FOREIGN KEY (section_id)       REFERENCES sections(id)
) ENGINE=InnoDB;

CREATE TABLE staff_attendance (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id       BIGINT UNSIGNED NOT NULL,
    staff_id        BIGINT UNSIGNED NOT NULL,
    attendance_date DATE NOT NULL,
    status          ENUM('present','absent','late','half_day','on_leave') NOT NULL,
    check_in        TIME NULL,
    check_out       TIME NULL,
    remarks         VARCHAR(255) NULL,
    marked_by       BIGINT UNSIGNED NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_sta (staff_id, attendance_date),
    CONSTRAINT fk_sta_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_sta_staff  FOREIGN KEY (staff_id)  REFERENCES staff(id)   ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 7 : TIMETABLE
-- =====================================================================

-- Period slot definitions (e.g. Period 1 = 09:00-09:45)
CREATE TABLE timetable_periods (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    name       VARCHAR(40) NOT NULL,                         -- Period 1, Lunch Break
    start_time TIME NOT NULL,
    end_time   TIME NOT NULL,
    is_break   TINYINT(1) NOT NULL DEFAULT 0,
    sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT fk_tp_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE timetable_entries (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    section_id       BIGINT UNSIGNED NOT NULL,
    period_id        BIGINT UNSIGNED NOT NULL,
    day_of_week      TINYINT UNSIGNED NOT NULL,              -- 1 = Monday ... 7 = Sunday
    subject_id       BIGINT UNSIGNED NULL,
    teacher_id       BIGINT UNSIGNED NULL,                   -- staff.id
    room_no          VARCHAR(30) NULL,
    UNIQUE KEY uq_tte (academic_year_id, section_id, day_of_week, period_id),
    INDEX idx_tte_teacher (teacher_id, day_of_week),
    CONSTRAINT fk_tte_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_tte_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_tte_section FOREIGN KEY (section_id)       REFERENCES sections(id) ON DELETE CASCADE,
    CONSTRAINT fk_tte_period  FOREIGN KEY (period_id)        REFERENCES timetable_periods(id),
    CONSTRAINT fk_tte_subject FOREIGN KEY (subject_id)       REFERENCES subjects(id),
    CONSTRAINT fk_tte_teacher FOREIGN KEY (teacher_id)       REFERENCES staff(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 8 : HOMEWORK, STUDY MATERIAL & LESSON PLANS
-- =====================================================================

CREATE TABLE homework (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    section_id       BIGINT UNSIGNED NOT NULL,
    subject_id       BIGINT UNSIGNED NOT NULL,
    teacher_id       BIGINT UNSIGNED NOT NULL,               -- staff.id
    title            VARCHAR(200) NOT NULL,
    description      TEXT NULL,
    attachment_url   VARCHAR(500) NULL,
    assigned_date    DATE NOT NULL,
    due_date         DATE NOT NULL,
    max_marks        SMALLINT UNSIGNED NULL,
    status           ENUM('draft','published','closed') NOT NULL DEFAULT 'published',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_hw_section (section_id, due_date),
    CONSTRAINT fk_hw_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_hw_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_hw_section FOREIGN KEY (section_id)       REFERENCES sections(id),
    CONSTRAINT fk_hw_subject FOREIGN KEY (subject_id)       REFERENCES subjects(id),
    CONSTRAINT fk_hw_teacher FOREIGN KEY (teacher_id)       REFERENCES staff(id)
) ENGINE=InnoDB;

CREATE TABLE homework_submissions (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    homework_id    BIGINT UNSIGNED NOT NULL,
    student_id     BIGINT UNSIGNED NOT NULL,
    submitted_at   DATETIME NULL,
    attachment_url VARCHAR(500) NULL,
    remarks        TEXT NULL,
    marks_obtained DECIMAL(6,2) NULL,
    feedback       TEXT NULL,
    status         ENUM('pending','submitted','late','graded','returned') NOT NULL DEFAULT 'pending',
    graded_by      BIGINT UNSIGNED NULL,                     -- staff.id
    graded_at      DATETIME NULL,
    UNIQUE KEY uq_hws (homework_id, student_id),
    CONSTRAINT fk_hws_hw      FOREIGN KEY (homework_id) REFERENCES homework(id) ON DELETE CASCADE,
    CONSTRAINT fk_hws_student FOREIGN KEY (student_id)  REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE study_materials (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    class_id         BIGINT UNSIGNED NOT NULL,
    section_id       BIGINT UNSIGNED NULL,                   -- NULL = whole class
    subject_id       BIGINT UNSIGNED NOT NULL,
    uploaded_by      BIGINT UNSIGNED NOT NULL,               -- staff.id
    title            VARCHAR(200) NOT NULL,
    description      TEXT NULL,
    material_type    ENUM('notes','presentation','video','link','worksheet','other') NOT NULL DEFAULT 'notes',
    file_url         VARCHAR(500) NULL,
    external_link    VARCHAR(500) NULL,
    is_published     TINYINT(1) NOT NULL DEFAULT 1,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_sm_class_subject (class_id, subject_id),
    CONSTRAINT fk_sm_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_sm_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_sm_class   FOREIGN KEY (class_id)         REFERENCES classes(id),
    CONSTRAINT fk_sm_subject FOREIGN KEY (subject_id)       REFERENCES subjects(id),
    CONSTRAINT fk_sm_staff   FOREIGN KEY (uploaded_by)      REFERENCES staff(id)
) ENGINE=InnoDB;

CREATE TABLE lesson_plans (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    teacher_id       BIGINT UNSIGNED NOT NULL,               -- staff.id
    class_id         BIGINT UNSIGNED NOT NULL,
    subject_id       BIGINT UNSIGNED NOT NULL,
    title            VARCHAR(200) NOT NULL,
    objectives       TEXT NULL,
    content          TEXT NULL,
    teaching_method  VARCHAR(255) NULL,
    resources        TEXT NULL,
    plan_date        DATE NOT NULL,
    duration_minutes SMALLINT UNSIGNED NULL,
    status           ENUM('draft','submitted','approved','completed') NOT NULL DEFAULT 'draft',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lp_teacher (teacher_id, plan_date),
    CONSTRAINT fk_lp_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_lp_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_lp_teacher FOREIGN KEY (teacher_id)       REFERENCES staff(id),
    CONSTRAINT fk_lp_class   FOREIGN KEY (class_id)         REFERENCES classes(id),
    CONSTRAINT fk_lp_subject FOREIGN KEY (subject_id)       REFERENCES subjects(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 9 : EXAMINATIONS
-- =====================================================================

-- Exam terms/types: First Term, Mid Term, Final, Unit Test...
CREATE TABLE exam_types (
    id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id BIGINT UNSIGNED NOT NULL,
    name      VARCHAR(80) NOT NULL,
    weight_percent DECIMAL(5,2) NULL,                        -- weight in final result
    UNIQUE KEY uq_et (school_id, name),
    CONSTRAINT fk_et_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE exams (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    exam_type_id     BIGINT UNSIGNED NOT NULL,
    name             VARCHAR(150) NOT NULL,                  -- e.g. First Terminal Exam 2026
    start_date       DATE NULL,
    end_date         DATE NULL,
    status           ENUM('scheduled','ongoing','completed','result_published') NOT NULL DEFAULT 'scheduled',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ex_school FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_ex_ay     FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_ex_type   FOREIGN KEY (exam_type_id)     REFERENCES exam_types(id)
) ENGINE=InnoDB;

-- Subject-wise schedule within an exam, per class
CREATE TABLE exam_schedules (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_id     BIGINT UNSIGNED NOT NULL,
    class_id    BIGINT UNSIGNED NOT NULL,
    subject_id  BIGINT UNSIGNED NOT NULL,
    exam_date   DATE NOT NULL,
    start_time  TIME NULL,
    end_time    TIME NULL,
    room_no     VARCHAR(30) NULL,
    full_marks  DECIMAL(6,2) NOT NULL DEFAULT 100.00,
    pass_marks  DECIMAL(6,2) NOT NULL DEFAULT 40.00,
    UNIQUE KEY uq_es (exam_id, class_id, subject_id),
    CONSTRAINT fk_es_exam    FOREIGN KEY (exam_id)    REFERENCES exams(id) ON DELETE CASCADE,
    CONSTRAINT fk_es_class   FOREIGN KEY (class_id)   REFERENCES classes(id),
    CONSTRAINT fk_es_subject FOREIGN KEY (subject_id) REFERENCES subjects(id)
) ENGINE=InnoDB;

-- Grading scale (A+ = 90-100, GPA 4.0 etc.)
CREATE TABLE grade_scales (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    grade       VARCHAR(5)  NOT NULL,                        -- A+, A, B+...
    min_percent DECIMAL(5,2) NOT NULL,
    max_percent DECIMAL(5,2) NOT NULL,
    grade_point DECIMAL(3,2) NULL,
    remarks     VARCHAR(100) NULL,
    CONSTRAINT fk_gs_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Marks entry
CREATE TABLE exam_marks (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_schedule_id BIGINT UNSIGNED NOT NULL,
    student_id       BIGINT UNSIGNED NOT NULL,
    theory_marks     DECIMAL(6,2) NULL,
    practical_marks  DECIMAL(6,2) NULL,
    total_marks      DECIMAL(6,2) NULL,
    grade            VARCHAR(5) NULL,
    is_absent        TINYINT(1) NOT NULL DEFAULT 0,
    remarks          VARCHAR(255) NULL,
    entered_by       BIGINT UNSIGNED NULL,                   -- staff.id
    entered_at       DATETIME NULL,
    verified_by      BIGINT UNSIGNED NULL,
    UNIQUE KEY uq_em (exam_schedule_id, student_id),
    INDEX idx_em_student (student_id),
    CONSTRAINT fk_em_schedule FOREIGN KEY (exam_schedule_id) REFERENCES exam_schedules(id) ON DELETE CASCADE,
    CONSTRAINT fk_em_student  FOREIGN KEY (student_id)       REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Consolidated result per student per exam (computed & cached)
CREATE TABLE exam_results (
    id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_id       BIGINT UNSIGNED NOT NULL,
    student_id    BIGINT UNSIGNED NOT NULL,
    total_marks   DECIMAL(8,2) NULL,
    percentage    DECIMAL(5,2) NULL,
    gpa           DECIMAL(3,2) NULL,
    grade         VARCHAR(5) NULL,
    rank_in_class SMALLINT UNSIGNED NULL,
    result_status ENUM('pass','fail','withheld') NULL,
    published_at  DATETIME NULL,
    UNIQUE KEY uq_er (exam_id, student_id),
    CONSTRAINT fk_er_exam    FOREIGN KEY (exam_id)    REFERENCES exams(id) ON DELETE CASCADE,
    CONSTRAINT fk_er_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Admit cards
CREATE TABLE admit_cards (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_id      BIGINT UNSIGNED NOT NULL,
    student_id   BIGINT UNSIGNED NOT NULL,
    card_no      VARCHAR(40) NOT NULL,
    issued_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ac (exam_id, student_id),
    CONSTRAINT fk_ac_exam    FOREIGN KEY (exam_id)    REFERENCES exams(id) ON DELETE CASCADE,
    CONSTRAINT fk_ac_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 10 : FEE MANAGEMENT
-- =====================================================================

-- Fee heads: Tuition, Admission, Exam, Transport, Library...
CREATE TABLE fee_types (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(255) NULL,
    is_refundable TINYINT(1) NOT NULL DEFAULT 0,
    UNIQUE KEY uq_ft (school_id, name),
    CONSTRAINT fk_ft_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Class-wise fee structure per academic year
CREATE TABLE fee_structures (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    class_id         BIGINT UNSIGNED NOT NULL,
    fee_type_id      BIGINT UNSIGNED NOT NULL,
    amount           DECIMAL(12,2) NOT NULL,
    frequency        ENUM('one_time','monthly','quarterly','half_yearly','yearly') NOT NULL DEFAULT 'monthly',
    due_day          TINYINT UNSIGNED NULL,                  -- day of month payment is due
    late_fine_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    UNIQUE KEY uq_fs (academic_year_id, class_id, fee_type_id),
    CONSTRAINT fk_fs_school FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_fs_ay     FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_fs_class  FOREIGN KEY (class_id)         REFERENCES classes(id),
    CONSTRAINT fk_fs_type   FOREIGN KEY (fee_type_id)      REFERENCES fee_types(id)
) ENGINE=InnoDB;

-- Discounts / scholarships
CREATE TABLE fee_discounts (
    id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id     BIGINT UNSIGNED NOT NULL,
    name          VARCHAR(100) NOT NULL,                     -- Sibling discount, Scholarship 50%
    discount_type ENUM('percent','fixed') NOT NULL,
    value         DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_fd_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE student_fee_discounts (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id       BIGINT UNSIGNED NOT NULL,
    discount_id      BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    fee_type_id      BIGINT UNSIGNED NULL,                   -- NULL = applies to all fee types
    remarks          VARCHAR(255) NULL,
    UNIQUE KEY uq_sfd (student_id, discount_id, academic_year_id, fee_type_id),
    CONSTRAINT fk_sfd_student  FOREIGN KEY (student_id)       REFERENCES students(id) ON DELETE CASCADE,
    CONSTRAINT fk_sfd_discount FOREIGN KEY (discount_id)      REFERENCES fee_discounts(id) ON DELETE CASCADE,
    CONSTRAINT fk_sfd_ay       FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Generated fee invoices per student (monthly / term-wise)
CREATE TABLE fee_invoices (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    student_id       BIGINT UNSIGNED NOT NULL,
    invoice_no       VARCHAR(40) NOT NULL,
    billing_month    DATE NULL,                              -- first day of month for monthly fees
    subtotal         DECIMAL(12,2) NOT NULL,
    discount_amount  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    fine_amount      DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_amount     DECIMAL(12,2) NOT NULL,
    paid_amount      DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    due_date         DATE NOT NULL,
    status           ENUM('unpaid','partial','paid','overdue','cancelled') NOT NULL DEFAULT 'unpaid',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_fi_no (school_id, invoice_no),
    INDEX idx_fi_student (student_id, status),
    CONSTRAINT fk_fi_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_fi_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_fi_student FOREIGN KEY (student_id)       REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE fee_invoice_items (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    invoice_id  BIGINT UNSIGNED NOT NULL,
    fee_type_id BIGINT UNSIGNED NOT NULL,
    description VARCHAR(200) NULL,
    amount      DECIMAL(12,2) NOT NULL,
    CONSTRAINT fk_fii_invoice FOREIGN KEY (invoice_id)  REFERENCES fee_invoices(id) ON DELETE CASCADE,
    CONSTRAINT fk_fii_type    FOREIGN KEY (fee_type_id) REFERENCES fee_types(id)
) ENGINE=InnoDB;

CREATE TABLE fee_payments (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    invoice_id   BIGINT UNSIGNED NOT NULL,
    student_id   BIGINT UNSIGNED NOT NULL,
    receipt_no   VARCHAR(40) NOT NULL,
    amount       DECIMAL(12,2) NOT NULL,
    method       ENUM('cash','cheque','card','bank_transfer','esewa','khalti','online','other') NOT NULL,
    transaction_ref VARCHAR(120) NULL,
    payment_date DATE NOT NULL,
    collected_by BIGINT UNSIGNED NULL,                       -- users.id (accountant)
    remarks      VARCHAR(255) NULL,
    status       ENUM('success','pending','failed','refunded') NOT NULL DEFAULT 'success',
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_fp_receipt (school_id, receipt_no),
    INDEX idx_fp_student (student_id),
    CONSTRAINT fk_fp_school  FOREIGN KEY (school_id)  REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_fp_invoice FOREIGN KEY (invoice_id) REFERENCES fee_invoices(id),
    CONSTRAINT fk_fp_student FOREIGN KEY (student_id) REFERENCES students(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 11 : LIBRARY
-- =====================================================================

CREATE TABLE book_categories (
    id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id BIGINT UNSIGNED NOT NULL,
    name      VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_bc (school_id, name),
    CONSTRAINT fk_bc_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE books (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    category_id  BIGINT UNSIGNED NULL,
    title        VARCHAR(255) NOT NULL,
    author       VARCHAR(150) NULL,
    publisher    VARCHAR(150) NULL,
    isbn         VARCHAR(20)  NULL,
    edition      VARCHAR(50)  NULL,
    shelf_location VARCHAR(50) NULL,
    price        DECIMAL(10,2) NULL,
    total_copies INT UNSIGNED NOT NULL DEFAULT 1,
    available_copies INT UNSIGNED NOT NULL DEFAULT 1,
    cover_url    VARCHAR(500) NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_books_title (school_id, title),
    CONSTRAINT fk_books_school FOREIGN KEY (school_id)   REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_books_cat    FOREIGN KEY (category_id) REFERENCES book_categories(id)
) ENGINE=InnoDB;

CREATE TABLE book_issues (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    book_id      BIGINT UNSIGNED NOT NULL,
    -- borrower is either a student or a staff member
    student_id   BIGINT UNSIGNED NULL,
    staff_id     BIGINT UNSIGNED NULL,
    issue_date   DATE NOT NULL,
    due_date     DATE NOT NULL,
    return_date  DATE NULL,
    fine_amount  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    fine_paid    TINYINT(1) NOT NULL DEFAULT 0,
    status       ENUM('issued','returned','overdue','lost') NOT NULL DEFAULT 'issued',
    issued_by    BIGINT UNSIGNED NULL,                       -- users.id (librarian)
    remarks      VARCHAR(255) NULL,
    INDEX idx_bi_book (book_id, status),
    INDEX idx_bi_student (student_id),
    CONSTRAINT fk_bi_school  FOREIGN KEY (school_id)  REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_bi_book    FOREIGN KEY (book_id)    REFERENCES books(id),
    CONSTRAINT fk_bi_student FOREIGN KEY (student_id) REFERENCES students(id),
    CONSTRAINT fk_bi_staff   FOREIGN KEY (staff_id)   REFERENCES staff(id),
    CONSTRAINT chk_bi_borrower CHECK (student_id IS NOT NULL OR staff_id IS NOT NULL)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 12 : TRANSPORT
-- =====================================================================

CREATE TABLE vehicles (
    id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id     BIGINT UNSIGNED NOT NULL,
    vehicle_no    VARCHAR(30) NOT NULL,
    vehicle_type  ENUM('bus','van','other') NOT NULL DEFAULT 'bus',
    capacity      SMALLINT UNSIGNED NULL,
    driver_id     BIGINT UNSIGNED NULL,                      -- staff.id
    helper_name   VARCHAR(100) NULL,
    helper_phone  VARCHAR(20) NULL,
    insurance_expiry DATE NULL,
    is_active     TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY uq_vehicle (school_id, vehicle_no),
    CONSTRAINT fk_v_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_v_driver FOREIGN KEY (driver_id) REFERENCES staff(id)
) ENGINE=InnoDB;

CREATE TABLE transport_routes (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    name       VARCHAR(120) NOT NULL,
    vehicle_id BIGINT UNSIGNED NULL,
    monthly_fee DECIMAL(10,2) NULL,                          -- default route fee
    is_active  TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_tr_school  FOREIGN KEY (school_id)  REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_tr_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id)
) ENGINE=InnoDB;

CREATE TABLE route_stops (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    route_id     BIGINT UNSIGNED NOT NULL,
    name         VARCHAR(120) NOT NULL,
    pickup_time  TIME NULL,
    drop_time    TIME NULL,
    monthly_fee  DECIMAL(10,2) NULL,                         -- stop-specific fee override
    sort_order   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT fk_rs_route FOREIGN KEY (route_id) REFERENCES transport_routes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE student_transport (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    student_id       BIGINT UNSIGNED NOT NULL,
    route_id         BIGINT UNSIGNED NOT NULL,
    stop_id          BIGINT UNSIGNED NOT NULL,
    start_date       DATE NULL,
    end_date         DATE NULL,
    is_active        TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY uq_st (academic_year_id, student_id),
    CONSTRAINT fk_strn_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_strn_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_strn_student FOREIGN KEY (student_id)       REFERENCES students(id) ON DELETE CASCADE,
    CONSTRAINT fk_strn_route   FOREIGN KEY (route_id)         REFERENCES transport_routes(id),
    CONSTRAINT fk_strn_stop    FOREIGN KEY (stop_id)          REFERENCES route_stops(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 13 : INVENTORY / ASSETS
-- =====================================================================

CREATE TABLE inventory_categories (
    id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id BIGINT UNSIGNED NOT NULL,
    name      VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_ic (school_id, name),
    CONSTRAINT fk_ic_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE inventory_suppliers (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    name         VARCHAR(150) NOT NULL,
    contact_person VARCHAR(100) NULL,
    phone        VARCHAR(20) NULL,
    email        VARCHAR(150) NULL,
    address      VARCHAR(255) NULL,
    CONSTRAINT fk_is_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE inventory_items (
    id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id     BIGINT UNSIGNED NOT NULL,
    category_id   BIGINT UNSIGNED NULL,
    name          VARCHAR(150) NOT NULL,
    item_code     VARCHAR(50) NULL,
    unit          VARCHAR(30) NULL,                          -- pcs / box / litre
    quantity      INT NOT NULL DEFAULT 0,
    reorder_level INT UNSIGNED NULL,
    unit_price    DECIMAL(12,2) NULL,
    is_asset      TINYINT(1) NOT NULL DEFAULT 0,             -- fixed asset vs consumable
    CONSTRAINT fk_ii_school FOREIGN KEY (school_id)   REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_ii_cat    FOREIGN KEY (category_id) REFERENCES inventory_categories(id)
) ENGINE=InnoDB;

CREATE TABLE inventory_transactions (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    item_id     BIGINT UNSIGNED NOT NULL,
    supplier_id BIGINT UNSIGNED NULL,
    txn_type    ENUM('purchase','issue','return','damage','adjustment') NOT NULL,
    quantity    INT NOT NULL,                                -- positive in, negative out
    unit_price  DECIMAL(12,2) NULL,
    issued_to   BIGINT UNSIGNED NULL,                        -- staff.id when issued
    txn_date    DATE NOT NULL,
    remarks     VARCHAR(255) NULL,
    created_by  BIGINT UNSIGNED NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_it_item (item_id, txn_date),
    CONSTRAINT fk_it_school   FOREIGN KEY (school_id)   REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_it_item     FOREIGN KEY (item_id)     REFERENCES inventory_items(id),
    CONSTRAINT fk_it_supplier FOREIGN KEY (supplier_id) REFERENCES inventory_suppliers(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 14 : HOSTEL (optional module)
-- =====================================================================

CREATE TABLE hostels (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    name        VARCHAR(120) NOT NULL,
    hostel_type ENUM('boys','girls','mixed') NOT NULL,
    warden_id   BIGINT UNSIGNED NULL,                        -- staff.id
    address     VARCHAR(255) NULL,
    CONSTRAINT fk_h_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_h_warden FOREIGN KEY (warden_id) REFERENCES staff(id)
) ENGINE=InnoDB;

CREATE TABLE hostel_rooms (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    hostel_id   BIGINT UNSIGNED NOT NULL,
    room_no     VARCHAR(30) NOT NULL,
    room_type   VARCHAR(50) NULL,                            -- dorm / double / single
    capacity    SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    monthly_fee DECIMAL(10,2) NULL,
    UNIQUE KEY uq_hr (hostel_id, room_no),
    CONSTRAINT fk_hr_hostel FOREIGN KEY (hostel_id) REFERENCES hostels(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE hostel_allocations (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id        BIGINT UNSIGNED NOT NULL,
    academic_year_id BIGINT UNSIGNED NOT NULL,
    student_id       BIGINT UNSIGNED NOT NULL,
    room_id          BIGINT UNSIGNED NOT NULL,
    allocated_on     DATE NOT NULL,
    vacated_on       DATE NULL,
    is_active        TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY uq_ha (academic_year_id, student_id),
    CONSTRAINT fk_ha_school  FOREIGN KEY (school_id)        REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_ha_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE,
    CONSTRAINT fk_ha_student FOREIGN KEY (student_id)       REFERENCES students(id) ON DELETE CASCADE,
    CONSTRAINT fk_ha_room    FOREIGN KEY (room_id)          REFERENCES hostel_rooms(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 15 : COMMUNICATION, NOTICES & EVENTS
-- =====================================================================

-- Internal messages (user to user / broadcast)
CREATE TABLE messages (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id  BIGINT UNSIGNED NOT NULL,
    sender_id  BIGINT UNSIGNED NOT NULL,                     -- users.id
    subject    VARCHAR(200) NULL,
    body       TEXT NOT NULL,
    attachment_url VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_msg_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_sender FOREIGN KEY (sender_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE message_recipients (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    message_id   BIGINT UNSIGNED NOT NULL,
    recipient_id BIGINT UNSIGNED NOT NULL,                   -- users.id
    read_at      DATETIME NULL,
    UNIQUE KEY uq_mr (message_id, recipient_id),
    INDEX idx_mr_recipient (recipient_id, read_at),
    CONSTRAINT fk_mr_msg  FOREIGN KEY (message_id)   REFERENCES messages(id) ON DELETE CASCADE,
    CONSTRAINT fk_mr_user FOREIGN KEY (recipient_id) REFERENCES users(id)    ON DELETE CASCADE
) ENGINE=InnoDB;

-- Outbound SMS / Email / WhatsApp log
CREATE TABLE communication_logs (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    channel      ENUM('sms','email','whatsapp','push') NOT NULL,
    recipient    VARCHAR(150) NOT NULL,                      -- phone or email
    user_id      BIGINT UNSIGNED NULL,                       -- linked user if known
    template_key VARCHAR(80) NULL,                           -- fee_reminder, absent_alert...
    subject      VARCHAR(200) NULL,
    body         TEXT NULL,
    provider     VARCHAR(60) NULL,                           -- twilio, sparrow, smtp...
    provider_ref VARCHAR(120) NULL,
    status       ENUM('queued','sent','delivered','failed') NOT NULL DEFAULT 'queued',
    error_message VARCHAR(255) NULL,
    sent_at      DATETIME NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cl_school (school_id, channel, status),
    CONSTRAINT fk_cl_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Notice board (school-level notices)
CREATE TABLE notices (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    title        VARCHAR(200) NOT NULL,
    body         TEXT NOT NULL,
    attachment_url VARCHAR(500) NULL,
    audience     ENUM('all','students','teachers','staff','parents','class') NOT NULL DEFAULT 'all',
    class_id     BIGINT UNSIGNED NULL,                       -- when audience = class
    publish_date DATE NOT NULL,
    expiry_date  DATE NULL,
    is_published TINYINT(1) NOT NULL DEFAULT 1,
    created_by   BIGINT UNSIGNED NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notice_school (school_id, publish_date),
    CONSTRAINT fk_n_school  FOREIGN KEY (school_id)  REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_n_class   FOREIGN KEY (class_id)   REFERENCES classes(id),
    CONSTRAINT fk_n_creator FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB;

-- Events & academic calendar
CREATE TABLE events (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    title       VARCHAR(200) NOT NULL,
    description TEXT NULL,
    event_type  ENUM('holiday','exam','event','meeting','vacation','other') NOT NULL DEFAULT 'event',
    start_date  DATE NOT NULL,
    end_date    DATE NULL,
    start_time  TIME NULL,
    end_time    TIME NULL,
    venue       VARCHAR(200) NULL,
    audience    ENUM('all','students','teachers','staff','parents') NOT NULL DEFAULT 'all',
    is_holiday  TINYINT(1) NOT NULL DEFAULT 0,
    created_by  BIGINT UNSIGNED NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_events_school_date (school_id, start_date),
    CONSTRAINT fk_ev_school  FOREIGN KEY (school_id)  REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_ev_creator FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 16 : CERTIFICATES
-- =====================================================================

CREATE TABLE certificate_templates (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    name         VARCHAR(120) NOT NULL,                      -- Transfer Cert, Character Cert...
    cert_type    ENUM('transfer','character','bonafide','marksheet','sports','participation','custom') NOT NULL,
    body_html    MEDIUMTEXT NULL,                            -- template with placeholders
    background_url VARCHAR(500) NULL,
    is_active    TINYINT(1) NOT NULL DEFAULT 1,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ct_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE issued_certificates (
    id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id    BIGINT UNSIGNED NOT NULL,
    template_id  BIGINT UNSIGNED NOT NULL,
    student_id   BIGINT UNSIGNED NULL,
    staff_id     BIGINT UNSIGNED NULL,                       -- staff certificates (experience letter)
    serial_no    VARCHAR(50) NOT NULL,
    issue_date   DATE NOT NULL,
    file_url     VARCHAR(500) NULL,                          -- generated PDF
    issued_by    BIGINT UNSIGNED NOT NULL,                   -- users.id
    remarks      VARCHAR(255) NULL,
    UNIQUE KEY uq_cert_serial (school_id, serial_no),
    CONSTRAINT fk_icert_school   FOREIGN KEY (school_id)   REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_icert_template FOREIGN KEY (template_id) REFERENCES certificate_templates(id),
    CONSTRAINT fk_icert_student  FOREIGN KEY (student_id)  REFERENCES students(id),
    CONSTRAINT fk_icert_staff    FOREIGN KEY (staff_id)    REFERENCES staff(id),
    CONSTRAINT chk_icert_target CHECK (student_id IS NOT NULL OR staff_id IS NOT NULL)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 17 : LEAVE MANAGEMENT (students + staff)
-- =====================================================================

CREATE TABLE leave_types (
    id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id     BIGINT UNSIGNED NOT NULL,
    name          VARCHAR(80) NOT NULL,                      -- Sick, Casual, Annual...
    applicable_to ENUM('staff','student','both') NOT NULL DEFAULT 'both',
    max_days_per_year SMALLINT UNSIGNED NULL,
    is_paid       TINYINT(1) NOT NULL DEFAULT 1,             -- for staff leaves
    UNIQUE KEY uq_lt (school_id, name),
    CONSTRAINT fk_lt_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE leave_applications (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id      BIGINT UNSIGNED NOT NULL,
    leave_type_id  BIGINT UNSIGNED NOT NULL,
    applicant_user_id BIGINT UNSIGNED NOT NULL,              -- users.id (student or staff)
    from_date      DATE NOT NULL,
    to_date        DATE NOT NULL,
    days           DECIMAL(4,1) NOT NULL,
    reason         TEXT NOT NULL,
    attachment_url VARCHAR(500) NULL,
    status         ENUM('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
    reviewed_by    BIGINT UNSIGNED NULL,                     -- users.id
    reviewed_at    DATETIME NULL,
    review_remarks VARCHAR(255) NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_la_applicant (applicant_user_id, status),
    CONSTRAINT fk_la_school FOREIGN KEY (school_id)         REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_la_type   FOREIGN KEY (leave_type_id)     REFERENCES leave_types(id),
    CONSTRAINT fk_la_user   FOREIGN KEY (applicant_user_id) REFERENCES users(id),
    CONSTRAINT fk_la_reviewer FOREIGN KEY (reviewed_by)     REFERENCES users(id)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 18 : DOWNLOADS / SHARED FILES (student portal downloads)
-- =====================================================================

CREATE TABLE downloads (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id   BIGINT UNSIGNED NOT NULL,
    title       VARCHAR(200) NOT NULL,
    description VARCHAR(500) NULL,
    file_url    VARCHAR(500) NOT NULL,
    audience    ENUM('all','students','teachers','staff','parents') NOT NULL DEFAULT 'all',
    class_id    BIGINT UNSIGNED NULL,
    uploaded_by BIGINT UNSIGNED NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dl_school FOREIGN KEY (school_id)   REFERENCES schools(id) ON DELETE CASCADE,
    CONSTRAINT fk_dl_class  FOREIGN KEY (class_id)    REFERENCES classes(id),
    CONSTRAINT fk_dl_user   FOREIGN KEY (uploaded_by) REFERENCES users(id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- SECTION 19 : SEED DATA
-- =====================================================================

-- System roles
INSERT INTO roles (school_id, name, slug, description, is_system) VALUES
(NULL, 'Super Admin',   'super-admin',   'Platform owner with full access',        1),
(NULL, 'Platform Support', 'platform-support', 'Support staff for the SaaS platform', 1),
(NULL, 'School Admin',  'school-admin',  'Full access within own school',          1),
(NULL, 'Teacher',       'teacher',       'Teacher portal access',                  1),
(NULL, 'Student',       'student',       'Student portal access',                  1),
(NULL, 'Parent',        'parent',        'Parent portal access (future)',          1),
(NULL, 'Accountant',    'accountant',    'Fee & finance module access',            1),
(NULL, 'Librarian',     'librarian',     'Library module access',                  1);

-- Feature catalogue
INSERT INTO features (code, name, description) VALUES
('CORE',        'Core Academics',      'Students, classes, subjects, attendance'),
('EXAMS',       'Examination',         'Exam scheduling, marks entry, results'),
('FEES',        'Fee Management',      'Fee structures, invoicing, payments'),
('LIBRARY',     'Library',             'Book catalogue and issue/return'),
('TRANSPORT',   'Transport',           'Routes, vehicles, student transport'),
('HOSTEL',      'Hostel',              'Hostel rooms and allocation'),
('INVENTORY',   'Inventory / Assets',  'Stock and asset management'),
('SMS',         'SMS Notifications',   'Outbound SMS integration'),
('EMAIL',       'Email Notifications', 'Outbound email integration'),
('WHATSAPP',    'WhatsApp',            'WhatsApp messaging integration'),
('CERTIFICATES','Certificates',        'Certificate templates and issuance'),
('REPORTS',     'Advanced Reports',    'Analytics and export');

-- Subscription plans
INSERT INTO subscription_plans (name, slug, description, price_monthly, price_yearly, max_students, max_staff, max_storage_mb, trial_days) VALUES
('Basic',    'basic',    'Core academics + attendance + exams',          49.00, 490.00,  300,  30,  2048, 14),
('Standard', 'standard', 'Basic + fees, library, communication',         99.00, 990.00, 1000, 100, 10240, 14),
('Premium',  'premium',  'All modules incl. transport, hostel, reports',199.00,1990.00, NULL, NULL, 51200, 14);

-- Map features to plans
INSERT INTO plan_features (plan_id, feature_id)
SELECT p.id, f.id FROM subscription_plans p JOIN features f
  ON (p.slug = 'basic'    AND f.code IN ('CORE','EXAMS'))
  OR (p.slug = 'standard' AND f.code IN ('CORE','EXAMS','FEES','LIBRARY','SMS','EMAIL','CERTIFICATES'))
  OR (p.slug = 'premium');                                   -- premium gets everything

-- Base permissions (extend as modules are built)
INSERT INTO permissions (module, action, slug) VALUES
('students','view','students.view'),('students','create','students.create'),
('students','edit','students.edit'),('students','delete','students.delete'),
('attendance','view','attendance.view'),('attendance','mark','attendance.mark'),
('exams','view','exams.view'),('exams','manage','exams.manage'),('exams','marks_entry','exams.marks_entry'),
('fees','view','fees.view'),('fees','collect','fees.collect'),('fees','manage','fees.manage'),
('library','view','library.view'),('library','manage','library.manage'),
('transport','view','transport.view'),('transport','manage','transport.manage'),
('reports','view','reports.view'),('reports','export','reports.export'),
('settings','view','settings.view'),('settings','manage','settings.manage'),
('users','view','users.view'),('users','manage','users.manage');

-- =====================================================================
-- END OF SCHEMA
-- =====================================================================
