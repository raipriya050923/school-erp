-- =====================================================================
-- SCHOOL ERP — DUMMY / SEED DATA
-- =====================================================================
-- Run order:
--   1. school_erp_schema.sql            (creates DB + tables + base seed)
--   2. SchoolErp.Api/db/migrations/001_superadmin_api_columns.sql
--   3. THIS FILE
--
--   mysql -u root -p school_erp < database/seed_dummy_data.sql
--
-- Mirrors the Angular front-end dummy data so the Super Admin API returns
-- the same schools, plans, subscriptions, invoices and tickets you see in
-- the UI, and seeds login accounts for EVERY role.
--
-- Demo password for every user below is:  Password@123
--   (password_hash is an illustrative bcrypt string — replace when auth is wired)
-- =====================================================================

USE school_erp;

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_SAFE_UPDATES = 0;   -- allow the un-keyed DELETEs below (Workbench safe-update mode)

-- Ensure the API's `reminded_at` column exists (migration 001) --------
-- Self-healing: adds it only if missing, so the seed runs standalone.
SET @has_reminded := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME  = 'platform_invoices'
    AND COLUMN_NAME = 'reminded_at');
SET @ddl := IF(@has_reminded = 0,
  'ALTER TABLE platform_invoices ADD COLUMN reminded_at DATETIME NULL AFTER paid_at',
  'DO 0');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Clean previous seed (safe to re-run) --------------------------------
DELETE FROM support_ticket_replies;
DELETE FROM support_tickets;
DELETE FROM platform_payments;
DELETE FROM platform_invoices;
DELETE FROM school_subscriptions;
DELETE FROM student_guardians;
DELETE FROM guardians;
DELETE FROM students;
DELETE FROM staff;
DELETE FROM users;
DELETE FROM schools;

ALTER TABLE schools           AUTO_INCREMENT = 1;
ALTER TABLE users             AUTO_INCREMENT = 1;
ALTER TABLE staff             AUTO_INCREMENT = 1;
ALTER TABLE students          AUTO_INCREMENT = 1;
ALTER TABLE guardians         AUTO_INCREMENT = 1;
ALTER TABLE school_subscriptions AUTO_INCREMENT = 1;
ALTER TABLE platform_invoices AUTO_INCREMENT = 1;
ALTER TABLE support_tickets   AUTO_INCREMENT = 1;

SET @pw := '$2a$11$3Qw0kL8mZp2Xr9dHbY7uOe5fJc1Vg6sN4tR0aP7yU2iK8xW3zL9C';

-- =====================================================================
-- 1. SCHOOLS  (ids 1..8)
-- =====================================================================
INSERT INTO schools
  (id, school_code, name, subdomain, email, phone, city, state, country,
   affiliation_board, timezone, currency, status, onboarded_at, created_at, updated_at)
VALUES
  (1,'SPS001','Sunrise Public School','sunrise','admin@sunrise.edu.np','01-4412001','Kathmandu','Bagmati','Nepal','NEB','Asia/Kathmandu','NPR','active','2024-03-12','2024-03-12',NOW()),
  (2,'GVA002','Green Valley Academy','greenvalley','admin@greenvalley.edu.np','061-522002','Pokhara','Gandaki','Nepal','NEB','Asia/Kathmandu','NPR','active','2024-06-01','2024-06-01',NOW()),
  (3,'HMS003','Himalaya Model School','himalaya','admin@himalaya.edu.np','01-5523003','Lalitpur','Bagmati','Nepal','NEB','Asia/Kathmandu','NPR','active','2024-08-20','2024-08-20',NOW()),
  (4,'EIS004','Everest Intl School','everest','admin@everest.edu.np','01-6612004','Bhaktapur','Bagmati','Nepal','CBSE','Asia/Kathmandu','NPR','active','2024-11-05','2024-11-05',NOW()),
  (5,'RWS005','Riverdale World School','riverdale','admin@riverdale.edu.np','071-540005','Butwal','Lumbini','Nepal','CBSE','Asia/Kathmandu','NPR','active','2026-06-18','2026-06-18',NOW()),
  (6,'BLA006','Blue Lotus Academy','bluelotus','admin@bluelotus.edu.np','021-460006','Biratnagar','Koshi','Nepal','NEB','Asia/Kathmandu','NPR','active','2026-06-25','2026-06-25',NOW()),
  (7,'NHS007','Nagarjun Hill School','nagarjun','admin@nagarjun.edu.np','01-4990007','Kathmandu','Bagmati','Nepal','NEB','Asia/Kathmandu','NPR','suspended','2025-01-15','2025-01-15',NOW()),
  (8,'SDS008','Shree Deep Sikshalaya','shreedeep','admin@shreedeep.edu.np','025-570008','Dharan','Koshi','Nepal','NEB','Asia/Kathmandu','NPR','active','2025-04-02','2025-04-02',NOW());

-- =====================================================================
-- 2. USERS  (all roles)
-- =====================================================================
-- 2a. Platform users (school_id NULL)
INSERT INTO users (id, school_id, user_type, username, email, phone, password_hash, full_name, is_active, created_at, updated_at) VALUES
  (1, NULL, 'super_admin', 'pramod', 'pramod@edunexus.io', '9800000001', @pw, 'Pramod Rai',       1, NOW(), NOW()),
  (2, NULL, 'staff',       'support', 'support@edunexus.io','9800000002', @pw, 'Platform Support', 1, NOW(), NOW());

-- 2b. School admins (one per school, ids 11..18)
INSERT INTO users (id, school_id, user_type, username, email, phone, password_hash, full_name, is_active, created_at, updated_at) VALUES
  (11, 1, 'school_admin', 'anita',  'anita@sunrise.edu.np',    '9841011011', @pw, 'Anita Sharma',     1, NOW(), NOW()),
  (12, 2, 'school_admin', 'suman',  'suman@greenvalley.edu.np','9846012012', @pw, 'Suman Poudel',     1, NOW(), NOW()),
  (13, 3, 'school_admin', 'rita',   'rita@himalaya.edu.np',    '9851013013', @pw, 'Rita Joshi',       1, NOW(), NOW()),
  (14, 4, 'school_admin', 'kiran',  'kiran@everest.edu.np',    '9861014014', @pw, 'Kiran Bhattarai',  1, NOW(), NOW()),
  (15, 5, 'school_admin', 'bharat', 'bharat@riverdale.edu.np', '9857015015', @pw, 'Bharat KC',        1, NOW(), NOW()),
  (16, 6, 'school_admin', 'sabina', 'sabina@bluelotus.edu.np', '9842016016', @pw, 'Sabina Rai',       1, NOW(), NOW()),
  (17, 7, 'school_admin', 'prakash','prakash@nagarjun.edu.np', '9808017017', @pw, 'Prakash Thapa',    1, NOW(), NOW()),
  (18, 8, 'school_admin', 'deepak', 'deepak@shreedeep.edu.np', '9862018018', @pw, 'Deepak Shrestha',  1, NOW(), NOW());

-- 2c. Teachers for Sunrise (login accounts, ids 101..108)
INSERT INTO users (id, school_id, user_type, username, email, phone, password_hash, full_name, is_active, created_at, updated_at) VALUES
  (101, 1, 'teacher', 'rajesh.k',  'rajesh.k@sunrise.edu.np',  '9851031415', @pw, 'Rajesh Koirala',   1, NOW(), NOW()),
  (102, 1, 'teacher', 'sunita.g',  'sunita.g@sunrise.edu.np',  '9802092653', @pw, 'Sunita Gurung',    1, NOW(), NOW()),
  (103, 1, 'teacher', 'prakash.s', 'prakash.s@sunrise.edu.np', '9841058979', @pw, 'Prakash Shrestha', 1, NOW(), NOW()),
  (104, 1, 'teacher', 'kamala.t',  'kamala.t@sunrise.edu.np',  '9808032384', @pw, 'Kamala Tamang',    1, NOW(), NOW()),
  (105, 1, 'teacher', 'dinesh.m',  'dinesh.m@sunrise.edu.np',  '9865062643', @pw, 'Dinesh Maharjan',  1, NOW(), NOW()),
  (106, 1, 'teacher', 'bina.k',    'bina.k@sunrise.edu.np',    '9812038327', @pw, 'Bina Karki',       1, NOW(), NOW()),
  (107, 1, 'teacher', 'niraj.r',   'niraj.r@sunrise.edu.np',   '9843095028', @pw, 'Niraj Rana',       1, NOW(), NOW()),
  (108, 1, 'teacher', 'sarita.p',  'sarita.p@sunrise.edu.np',  '9809084197', @pw, 'Sarita Pandey',    1, NOW(), NOW());

-- 2d. Student login accounts for Sunrise (ids 201..212)
INSERT INTO users (id, school_id, user_type, username, email, phone, password_hash, full_name, is_active, created_at, updated_at) VALUES
  (201, 1, 'student', 'aarav.t',   'aarav.t@sunrise.edu.np',   '9841022334', @pw, 'Aarav Thapa',      1, NOW(), NOW()),
  (202, 1, 'student', 'sneha.s',   'sneha.s@sunrise.edu.np',   '9802011223', @pw, 'Sneha Shrestha',   1, NOW(), NOW()),
  (203, 1, 'student', 'bibek.g',   'bibek.g@sunrise.edu.np',   '9851133445', @pw, 'Bibek Gurung',     1, NOW(), NOW()),
  (204, 1, 'student', 'priya.k',   'priya.k@sunrise.edu.np',   '9808055667', @pw, 'Priya Karki',      1, NOW(), NOW()),
  (205, 1, 'student', 'rohan.m',   'rohan.m@sunrise.edu.np',   '9865077889', @pw, 'Rohan Maharjan',   1, NOW(), NOW()),
  (206, 1, 'student', 'anisha.r',  'anisha.r@sunrise.edu.np',  '9812099001', @pw, 'Anisha Rai',       1, NOW(), NOW()),
  (207, 1, 'student', 'kiran.t',   'kiran.t@sunrise.edu.np',   '9843012131', @pw, 'Kiran Tamang',     1, NOW(), NOW()),
  (208, 1, 'student', 'meera.a',   'meera.a@sunrise.edu.np',   '9809014151', @pw, 'Meera Adhikari',   1, NOW(), NOW()),
  (209, 1, 'student', 'sagar.b',   'sagar.b@sunrise.edu.np',   '9855016171', @pw, 'Sagar Basnet',     1, NOW(), NOW()),
  (210, 1, 'student', 'ritika.p',  'ritika.p@sunrise.edu.np',  '9801018191', @pw, 'Ritika Pandey',    0, NOW(), NOW()),
  (211, 1, 'student', 'nabin.l',   'nabin.l@sunrise.edu.np',   '9846020212', @pw, 'Nabin Lama',       1, NOW(), NOW()),
  (212, 1, 'student', 'ojaswi.b',  'ojaswi.b@sunrise.edu.np',  '9811022232', @pw, 'Ojaswi Bhattarai', 1, NOW(), NOW());

-- 2e. Parent login accounts for Sunrise (ids 301..306)
INSERT INTO users (id, school_id, user_type, username, email, phone, password_hash, full_name, is_active, created_at, updated_at) VALUES
  (301, 1, 'parent', 'bikash.t', 'bikash.thapa@gmail.com',   '9841022334', @pw, 'Bikash Thapa',     1, NOW(), NOW()),
  (302, 1, 'parent', 'ram.s',    'ram.shrestha@gmail.com',   '9802011223', @pw, 'Ram Shrestha',     1, NOW(), NOW()),
  (303, 1, 'parent', 'hari.g',   'hari.gurung@gmail.com',    '9851133445', @pw, 'Hari Gurung',      1, NOW(), NOW()),
  (304, 1, 'parent', 'suman.k',  'suman.karki@gmail.com',    '9808055667', @pw, 'Suman Karki',      1, NOW(), NOW()),
  (305, 1, 'parent', 'raju.m',   'raju.maharjan@gmail.com',  '9865077889', @pw, 'Raju Maharjan',    1, NOW(), NOW()),
  (306, 1, 'parent', 'deepak.r', 'deepak.rai@gmail.com',     '9812099001', @pw, 'Deepak Rai',       1, NOW(), NOW());

-- =====================================================================
-- 3. STAFF  (teacher employee records for Sunrise)
-- =====================================================================
INSERT INTO staff
  (school_id, user_id, employee_code, staff_type, first_name, last_name, gender,
   email, phone, specialization, designation, joining_date, status, created_at, updated_at)
VALUES
  (1,101,'EMP-014','teacher','Rajesh','Koirala','male',  'rajesh.k@sunrise.edu.np', '9851031415','Mathematics',      'Senior Teacher','2021-04-01','active',NOW(),NOW()),
  (1,102,'EMP-008','teacher','Sunita','Gurung', 'female','sunita.g@sunrise.edu.np', '9802092653','English',          'Teacher',       '2020-04-15','active',NOW(),NOW()),
  (1,103,'EMP-021','teacher','Prakash','Shrestha','male','prakash.s@sunrise.edu.np','9841058979','Science',          'Teacher',       '2022-05-01','active',NOW(),NOW()),
  (1,104,'EMP-011','teacher','Kamala','Tamang', 'female','kamala.t@sunrise.edu.np', '9808032384','Nepali',           'Teacher',       '2019-06-01','on_leave',NOW(),NOW()),
  (1,105,'EMP-030','teacher','Dinesh','Maharjan','male', 'dinesh.m@sunrise.edu.np', '9865062643','Social Studies',   'Teacher',       '2023-04-10','active',NOW(),NOW()),
  (1,106,'EMP-017','teacher','Bina','Karki',    'female','bina.k@sunrise.edu.np',   '9812038327','Computer Science', 'Teacher',       '2022-07-01','active',NOW(),NOW()),
  (1,107,'EMP-025','teacher','Niraj','Rana',    'male',  'niraj.r@sunrise.edu.np',  '9843095028','Health & PE',      'Teacher',       '2021-08-01','active',NOW(),NOW()),
  (1,108,'EMP-019','teacher','Sarita','Pandey', 'female','sarita.p@sunrise.edu.np', '9809084197','Optional Math',    'Teacher',       '2020-09-01','active',NOW(),NOW());

-- =====================================================================
-- 4. STUDENTS
-- =====================================================================
-- 4a. Named Sunrise students (ids 1..12) linked to their login accounts
INSERT INTO students
  (id, school_id, user_id, admission_no, roll_no, first_name, last_name, gender,
   current_address, admission_date, status, created_at, updated_at)
VALUES
  (1, 1,201,'ADM-2081-012','12','Aarav','Thapa','male',      'Baneshwor-10, Kathmandu','2024-04-10','active',   NOW(),NOW()),
  (2, 1,202,'ADM-2081-034','8', 'Sneha','Shrestha','female', 'Baluwatar-04, Kathmandu','2024-04-10','active',   NOW(),NOW()),
  (3, 1,203,'ADM-2081-055','21','Bibek','Gurung','male',     'Kalanki-14, Kathmandu',  '2024-04-10','active',   NOW(),NOW()),
  (4, 1,204,'ADM-2080-101','5', 'Priya','Karki','female',    'Patan-16, Lalitpur',     '2023-04-12','active',   NOW(),NOW()),
  (5, 1,205,'ADM-2080-118','17','Rohan','Maharjan','male',   'Kirtipur-05, Kathmandu', '2023-04-12','active',   NOW(),NOW()),
  (6, 1,206,'ADM-2079-201','3', 'Anisha','Rai','female',     'Bhaktapur-09',           '2022-04-15','active',   NOW(),NOW()),
  (7, 1,207,'ADM-2079-215','11','Kiran','Tamang','male',     'Boudha-06, Kathmandu',   '2022-04-15','active',   NOW(),NOW()),
  (8, 1,208,'ADM-2082-004','2', 'Meera','Adhikari','female', 'Thimi-07, Bhaktapur',    '2025-04-08','active',   NOW(),NOW()),
  (9, 1,209,'ADM-2082-019','15','Sagar','Basnet','male',     'Balaju-16, Kathmandu',   '2025-04-08','active',   NOW(),NOW()),
  (10,1,210,'ADM-2081-077','9', 'Ritika','Pandey','female',  'Chabahil-07, Kathmandu', '2024-04-10','inactive', NOW(),NOW()),
  (11,1,211,'ADM-2080-134','22','Nabin','Lama','male',       'Swayambhu-15, Kathmandu','2023-04-12','active',   NOW(),NOW()),
  (12,1,212,'ADM-2082-031','27','Ojaswi','Bhattarai','female','Maitidevi-33, Kathmandu','2025-04-08','active',  NOW(),NOW());

-- 4b. Bulk filler students so each school's student COUNT matches the UI
--     (front-end shows 1248/764/590/1032/310/275/488/356; Sunrise already has 12 named)
--     Portable numbers generator via digit cross-joins (works on MySQL 5.7 / 8.0 / MariaDB
--     — no recursive CTE, no cte_max_recursion_depth needed). Generates 1..9999.
INSERT INTO students
  (school_id, admission_no, first_name, last_name, gender, admission_date, status, created_at, updated_at)
SELECT t.school_id,
       CONCAT('F-', t.code, '-', LPAD(seq.n, 5, '0')),
       CONCAT('Student', seq.n),
       'Sample',
       IF(seq.n % 2 = 0, 'male', 'female'),
       '2015-05-15',
       'active',
       NOW(), NOW()
FROM (
  SELECT (d3.d * 1000 + d2.d * 100 + d1.d * 10 + d0.d) AS n
  FROM (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) d0
  CROSS JOIN (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) d1
  CROSS JOIN (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) d2
  CROSS JOIN (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) d3
) seq
JOIN (
  SELECT 1 AS school_id, 'SPS001' AS code, 1236 AS target UNION ALL
  SELECT 2, 'GVA002',  764 UNION ALL
  SELECT 3, 'HMS003',  590 UNION ALL
  SELECT 4, 'EIS004', 1032 UNION ALL
  SELECT 5, 'RWS005',  310 UNION ALL
  SELECT 6, 'BLA006',  275 UNION ALL
  SELECT 7, 'NHS007',  488 UNION ALL
  SELECT 8, 'SDS008',  356
) t ON seq.n BETWEEN 1 AND t.target;

-- =====================================================================
-- 5. GUARDIANS / PARENTS  (linked to the first 6 named Sunrise students)
-- =====================================================================
INSERT INTO guardians (id, school_id, user_id, first_name, last_name, relation, phone, occupation, created_at) VALUES
  (1,1,301,'Bikash','Thapa','father','9841022334','Businessman', NOW()),
  (2,1,302,'Ram','Shrestha','father','9802011223','Engineer',    NOW()),
  (3,1,303,'Hari','Gurung','father','9851133445','Teacher',      NOW()),
  (4,1,304,'Suman','Karki','father','9808055667','Doctor',       NOW()),
  (5,1,305,'Raju','Maharjan','father','9865077889','Farmer',     NOW()),
  (6,1,306,'Deepak','Rai','father','9812099001','Accountant',    NOW());

INSERT INTO student_guardians (student_id, guardian_id, is_primary) VALUES
  (1,1,1),(2,2,1),(3,3,1),(4,4,1),(5,5,1),(6,6,1);

-- =====================================================================
-- 6. SCHOOL SUBSCRIPTIONS  (plan ids resolved by slug: basic/standard/premium)
--    subscription ids 1..8 map to school ids 1..8
-- =====================================================================
INSERT INTO school_subscriptions
  (id, school_id, plan_id, billing_cycle, start_date, end_date, price, status, auto_renew, created_at, updated_at)
VALUES
  (1,1,(SELECT id FROM subscription_plans WHERE slug='premium'), 'yearly', '2026-04-01','2027-03-31',1990.00,'active',  1,NOW(),NOW()),
  (2,2,(SELECT id FROM subscription_plans WHERE slug='standard'),'monthly','2026-06-01','2026-06-30',  99.00,'active',  1,NOW(),NOW()),
  (3,3,(SELECT id FROM subscription_plans WHERE slug='standard'),'yearly', '2025-08-20','2026-08-19', 990.00,'active',  1,NOW(),NOW()),
  (4,4,(SELECT id FROM subscription_plans WHERE slug='premium'), 'yearly', '2026-01-10','2027-01-09',1990.00,'active',  1,NOW(),NOW()),
  (5,5,(SELECT id FROM subscription_plans WHERE slug='basic'),   'monthly','2026-06-18','2026-07-02',   0.00,'trial',   1,NOW(),NOW()),
  (6,6,(SELECT id FROM subscription_plans WHERE slug='basic'),   'monthly','2026-06-25','2026-07-09',   0.00,'trial',   1,NOW(),NOW()),
  (7,7,(SELECT id FROM subscription_plans WHERE slug='standard'),'monthly','2026-05-01','2026-05-31',  99.00,'past_due',1,NOW(),NOW()),
  (8,8,(SELECT id FROM subscription_plans WHERE slug='basic'),   'yearly', '2026-04-02','2027-04-01', 490.00,'active',  1,NOW(),NOW());

-- =====================================================================
-- 7. PLATFORM INVOICES  (SaaS billing to schools)
-- =====================================================================
INSERT INTO platform_invoices
  (id, school_id, subscription_id, invoice_no, amount, tax_amount, total_amount, due_date, status, issued_at, paid_at, reminded_at, created_at)
VALUES
  (1,1,1,'INV-2026-0142',1990.00,0,1990.00,'2026-04-15','paid',   '2026-04-01','2026-04-12',NULL,        '2026-04-01'),
  (2,2,2,'INV-2026-0158',  99.00,0,  99.00,'2026-06-10','paid',   '2026-06-01','2026-06-08',NULL,        '2026-06-01'),
  (3,4,4,'INV-2026-0161',1990.00,0,1990.00,'2026-01-24','paid',   '2026-01-10','2026-01-20',NULL,        '2026-01-10'),
  (4,7,7,'INV-2026-0169',  99.00,0,  99.00,'2026-05-10','overdue','2026-05-01',NULL,        '2026-06-30','2026-05-01'),
  (5,8,8,'INV-2026-0175', 490.00,0, 490.00,'2026-04-16','paid',   '2026-04-02','2026-04-14',NULL,        '2026-04-02'),
  (6,3,3,'INV-2026-0181', 990.00,0, 990.00,'2026-07-04','sent',   '2026-06-20',NULL,        NULL,        '2026-06-20'),
  (7,2,2,'INV-2026-0183',  99.00,0,  99.00,'2026-07-10','sent',   '2026-07-01',NULL,        NULL,        '2026-07-01');

-- =====================================================================
-- 8. PLATFORM PAYMENTS  (against the paid invoices)
-- =====================================================================
INSERT INTO platform_payments (invoice_id, school_id, amount, method, transaction_ref, status, paid_at, created_at) VALUES
  (1,1,1990.00,'stripe',       'TXN-STR-88121','success','2026-04-12',NOW()),
  (2,2,  99.00,'card',         'TXN-CRD-90012','success','2026-06-08',NOW()),
  (3,4,1990.00,'bank_transfer','TXN-BNK-77340','success','2026-01-20',NOW()),
  (5,8, 490.00,'esewa',        'TXN-ESW-55201','success','2026-04-14',NOW());

-- =====================================================================
-- 9. SUPPORT TICKETS  (raised by school admins, assigned to super admin)
-- =====================================================================
INSERT INTO support_tickets
  (id, school_id, raised_by, assigned_to, ticket_no, subject, description, priority, status, created_at, updated_at)
VALUES
  (1,2,12,1,'TKT-1042','Bulk student import failing on CSV upload',
     'Uploading our Grade 6 student list (412 rows) fails at row 38 with "Invalid date format".',
     'urgent','open','2026-07-02','2026-07-02'),
  (2,1,11,1,'TKT-1041','Need WhatsApp sender ID changed',
     'Please change our WhatsApp sender name from "SunriseEdu" to "Sunrise Public School".',
     'medium','in_progress','2026-07-01','2026-07-01'),
  (3,5,15,1,'TKT-1039','How to configure fee late fines?',
     'We want a flat Rs 100 fine after the 10th of each month. Where do we set this?',
     'low','waiting','2026-06-29','2026-06-29'),
  (4,3,13,1,'TKT-1036','Exam marksheet PDF shows wrong logo',
     'Marksheets generated this week still show our old logo though we updated it two weeks ago.',
     'high','open','2026-06-27','2026-06-27'),
  (5,4,14,1,'TKT-1031','Request: transport GPS integration',
     'Is live GPS tracking of buses on the roadmap? Parents keep asking.',
     'low','resolved','2026-06-20','2026-06-21'),
  (6,8,18,1,'TKT-1028','SMS credits not topping up',
     'We purchased 5,000 SMS credits yesterday but the balance still shows 120.',
     'high','resolved','2026-06-14','2026-06-14');

-- =====================================================================
-- 10. SUPPORT TICKET REPLIES  (comment threads; user 1 = super admin/platform)
-- =====================================================================
INSERT INTO support_ticket_replies (ticket_id, user_id, message, created_at) VALUES
  (1,12,'Uploading our Grade 6 list fails at row 38 with "Invalid date format". Worked last month.','2026-07-02 09:14:00'),
  (1, 1,'Thanks for reporting. Could you attach the CSV? Row 38 likely has a BS date instead of AD.','2026-07-02 11:40:00'),
  (1,12,'Attached. You are right — some dates are in BS format. The previous import accepted both.','2026-07-02 14:05:00'),

  (2,11,'Please change our WhatsApp sender name from "SunriseEdu" to "Sunrise Public School".','2026-07-01 10:22:00'),
  (2, 1,'Request submitted to the WhatsApp Business team. Usually takes 2-3 business days.','2026-07-01 15:30:00'),

  (3,15,'We want a flat Rs 100 fine after the 10th of each month. Where do we set this?','2026-06-29 12:00:00'),
  (3, 1,'Fee Management > Fee Structures > edit the fee type and set late fine amount and due day.','2026-06-29 16:45:00'),

  (4,13,'Marksheets generated this week still show our old logo though we updated it two weeks ago.','2026-06-27 08:50:00'),

  (5,14,'Is live GPS tracking of buses on the roadmap? Parents keep asking.','2026-06-20 13:12:00'),
  (5, 1,'It is on the roadmap for Q4 2026 (Premium). Added your school to the early-access list.','2026-06-21 09:05:00'),
  (5,14,'Great, thanks — closing this for now.','2026-06-21 10:00:00'),

  (6,18,'We purchased 5,000 SMS credits yesterday but the balance still shows 120.','2026-06-14 11:30:00'),
  (6, 1,'Gateway webhook was delayed. Credits applied manually — balance now shows 5,120. Apologies!','2026-06-14 14:55:00');

SET FOREIGN_KEY_CHECKS = 1;
SET SQL_SAFE_UPDATES = 1;   -- restore safe-update mode

-- =====================================================================
-- SUMMARY
-- =====================================================================
SELECT 'schools'      AS entity, COUNT(*) AS rows_inserted FROM schools
UNION ALL SELECT 'users (all roles)',     COUNT(*) FROM users
UNION ALL SELECT '  - super_admin',       COUNT(*) FROM users WHERE user_type='super_admin'
UNION ALL SELECT '  - school_admin',      COUNT(*) FROM users WHERE user_type='school_admin'
UNION ALL SELECT '  - teacher',           COUNT(*) FROM users WHERE user_type='teacher'
UNION ALL SELECT '  - student',           COUNT(*) FROM users WHERE user_type='student'
UNION ALL SELECT '  - parent',            COUNT(*) FROM users WHERE user_type='parent'
UNION ALL SELECT 'staff',                 COUNT(*) FROM staff
UNION ALL SELECT 'students (total)',      COUNT(*) FROM students
UNION ALL SELECT 'guardians',             COUNT(*) FROM guardians
UNION ALL SELECT 'school_subscriptions',  COUNT(*) FROM school_subscriptions
UNION ALL SELECT 'platform_invoices',     COUNT(*) FROM platform_invoices
UNION ALL SELECT 'platform_payments',     COUNT(*) FROM platform_payments
UNION ALL SELECT 'support_tickets',       COUNT(*) FROM support_tickets
UNION ALL SELECT 'support_ticket_replies',COUNT(*) FROM support_ticket_replies;
