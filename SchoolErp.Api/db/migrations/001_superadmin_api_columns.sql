-- =====================================================================
-- Migration for the Super Admin .NET API
-- Adds columns the API repositories reference that the base schema lacks.
-- Run against the `school_erp` database after school_erp_schema.sql.
-- =====================================================================

USE school_erp;

-- The billing "Send Reminder" feature stamps when a reminder was last emailed.
ALTER TABLE platform_invoices
  ADD COLUMN reminded_at DATETIME NULL AFTER paid_at;

-- (support_tickets already has raised_by; users.full_name / user_type already exist.)
-- No other structural changes required for the Super Admin endpoints.
