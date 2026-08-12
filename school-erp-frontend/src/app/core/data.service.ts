import { Injectable } from '@angular/core';

/* =====================================================================
   DataService — in-memory dummy data for every portal.
   Replace with real HTTP calls when the backend API is ready.
   ===================================================================== */

export interface Plan {
  name: string;
  priceMonthly: number;
  priceYearly: number;
  maxStudents: number | null;   // null = unlimited
  trialDays: number;
  description: string;
  active: boolean;
}

export interface PlatformInvoice {
  no: string;
  school: string;
  amount: string;
  issued: string;
  due: string;
  status: string;
  reminded?: string;   // date last reminder email was sent
  paidAt?: string;
  method?: string;
  txnRef?: string;
}

export interface TicketComment {
  author: string;
  side: 'platform' | 'school';   // platform = super admin team, school = ticket creator
  message: string;
  at: string;                    // date-time
}

export interface Ticket {
  no: string;
  school: string;
  raisedBy: string;              // school-side user who created the ticket
  subject: string;
  priority: string;
  status: string;
  created: string;
  resolvedAt?: string;
  resolution?: string;
  comments: TicketComment[];
}

export interface School {
  code: string;
  name: string;
  city: string;
  plan: string;
  students: number;
  status: string;
  joined: string;
}

export interface Student {
  adm: string;
  name: string;
  cls: string;
  sec: string;
  roll: number;
  gender: string;
  guardian: string;
  phone: string;
  status: string;
  feeDue: number;
  admissionDate?: string;
  email?: string;
  address?: string;
  city?: string;
  state?: string;
  pincode?: string;
  dob?: string;
  bloodGroup?: string;
  previousSchool?: string;
}

export interface ExamPaper {
  date: string;
  subject: string;
  time: string;
  room: string;
  fullMarks: number;
}

export interface Exam {
  name: string;
  type: string;
  start: string;
  end: string;
  classes: string;
  status: string;
  schedule: ExamPaper[];
}

export interface FeeInvoice {
  no: string;
  student: string;
  cls: string;
  month: string;
  amount: number;
  paid: number;
  due: string;
  status: string;
  payments?: { date: string; amount: number; method: string; ref: string }[];
}

export interface ClassSection {
  name: string;
  students: number;
  teacher: string;
}

export interface SchoolClass {
  name: string;
  sections: ClassSection[];
}

export interface Teacher {
  code: string;
  name: string;
  subject: string;
  classes: string;
  phone: string;
  email: string;
  status: string;
  qualification?: string;
  joined?: string;
  address?: string;
  city?: string;
  state?: string;
  pincode?: string;
  dob?: string;
  gender?: string;
}

@Injectable({ providedIn: 'root' })
export class DataService {

  /* ---------------- SUPER ADMIN ---------------- */

  readonly platformStats = [
    { label: 'Total Schools', value: '24', sub: '+3 this quarter', trend: 'up' },
    { label: 'Active Subscriptions', value: '21', sub: '2 on trial', trend: '' },
    { label: 'Monthly Recurring Revenue', value: '$3,486', sub: '+8.2% vs last month', trend: 'up' },
    { label: 'Open Support Tickets', value: '4', sub: '1 urgent', trend: 'down' },
  ];

  readonly schools: School[] = [
    { code: 'SPS001', name: 'Sunrise Public School', city: 'Kathmandu', plan: 'Premium', students: 1248, status: 'Active', joined: '2024-03-12' },
    { code: 'GVA002', name: 'Green Valley Academy', city: 'Pokhara', plan: 'Standard', students: 764, status: 'Active', joined: '2024-06-01' },
    { code: 'HMS003', name: 'Himalaya Model School', city: 'Lalitpur', plan: 'Standard', students: 590, status: 'Active', joined: '2024-08-20' },
    { code: 'EIS004', name: 'Everest Int’l School', city: 'Bhaktapur', plan: 'Premium', students: 1032, status: 'Active', joined: '2024-11-05' },
    { code: 'RWS005', name: 'Riverdale World School', city: 'Butwal', plan: 'Basic', students: 310, status: 'Trial', joined: '2026-06-18' },
    { code: 'BLA006', name: 'Blue Lotus Academy', city: 'Biratnagar', plan: 'Basic', students: 275, status: 'Trial', joined: '2026-06-25' },
    { code: 'NHS007', name: 'Nagarjun Hill School', city: 'Kathmandu', plan: 'Standard', students: 488, status: 'Suspended', joined: '2025-01-15' },
    { code: 'SDS008', name: 'Shree Deep Sikshalaya', city: 'Dharan', plan: 'Basic', students: 356, status: 'Active', joined: '2025-04-02' },
  ];

  readonly plans: Plan[] = [
    { name: 'Basic', priceMonthly: 49, priceYearly: 490, maxStudents: 300, trialDays: 14, description: 'Core academics, attendance & exams', active: true },
    { name: 'Standard', priceMonthly: 99, priceYearly: 990, maxStudents: 1000, trialDays: 14, description: 'Basic + fees, library & communication', active: true },
    { name: 'Premium', priceMonthly: 199, priceYearly: 1990, maxStudents: null, trialDays: 14, description: 'All modules incl. transport, hostel & reports', active: true },
  ];

  /** Create or replace a plan (in-memory demo). */
  addPlan(p: Plan): void {
    this.plans.push(p);
  }

  /** Number of schools currently on a plan. */
  planSubscribers(name: string): number {
    return this.subscriptions.filter(s => s.plan === name).length;
  }

  readonly subscriptions = [
    { school: 'Sunrise Public School', plan: 'Premium', cycle: 'Yearly', start: '2026-04-01', end: '2027-03-31', amount: '$1,990', status: 'Active' },
    { school: 'Everest Int’l School', plan: 'Premium', cycle: 'Yearly', start: '2026-01-10', end: '2027-01-09', amount: '$1,990', status: 'Active' },
    { school: 'Green Valley Academy', plan: 'Standard', cycle: 'Monthly', start: '2026-06-01', end: '2026-06-30', amount: '$99', status: 'Active' },
    { school: 'Himalaya Model School', plan: 'Standard', cycle: 'Yearly', start: '2025-08-20', end: '2026-08-19', amount: '$990', status: 'Active' },
    { school: 'Riverdale World School', plan: 'Basic', cycle: 'Monthly', start: '2026-06-18', end: '2026-07-02', amount: '$0', status: 'Trial' },
    { school: 'Blue Lotus Academy', plan: 'Basic', cycle: 'Monthly', start: '2026-06-25', end: '2026-07-09', amount: '$0', status: 'Trial' },
    { school: 'Nagarjun Hill School', plan: 'Standard', cycle: 'Monthly', start: '2026-05-01', end: '2026-05-31', amount: '$99', status: 'Past due' },
    { school: 'Shree Deep Sikshalaya', plan: 'Basic', cycle: 'Yearly', start: '2026-04-02', end: '2027-04-01', amount: '$490', status: 'Active' },
  ];

  readonly billingStats = [
    { label: 'Collected (FY 2026)', value: '$18,420', sub: 'across 21 schools', trend: '' },
    { label: 'Outstanding', value: '$1,287', sub: '3 invoices', trend: '' },
    { label: 'Overdue', value: '$99', sub: 'Nagarjun Hill School', trend: 'down' },
  ];

  readonly platformInvoices: PlatformInvoice[] = [
    { no: 'INV-2026-0142', school: 'Sunrise Public School', amount: '$1,990', issued: '2026-04-01', due: '2026-04-15', status: 'Paid' },
    { no: 'INV-2026-0158', school: 'Green Valley Academy', amount: '$99', issued: '2026-06-01', due: '2026-06-10', status: 'Paid' },
    { no: 'INV-2026-0161', school: 'Everest Int’l School', amount: '$1,990', issued: '2026-01-10', due: '2026-01-24', status: 'Paid' },
    { no: 'INV-2026-0169', school: 'Nagarjun Hill School', amount: '$99', issued: '2026-05-01', due: '2026-05-10', status: 'Overdue' },
    { no: 'INV-2026-0175', school: 'Shree Deep Sikshalaya', amount: '$490', issued: '2026-04-02', due: '2026-04-16', status: 'Paid' },
    { no: 'INV-2026-0181', school: 'Himalaya Model School', amount: '$990', issued: '2026-06-20', due: '2026-07-04', status: 'Sent' },
    { no: 'INV-2026-0183', school: 'Green Valley Academy', amount: '$99', issued: '2026-07-01', due: '2026-07-10', status: 'Sent' },
  ];

  readonly tickets: Ticket[] = [
    {
      no: 'TKT-1042', school: 'Green Valley Academy', raisedBy: 'Suman Poudel (Admin)', subject: 'Bulk student import failing on CSV upload', priority: 'Urgent', status: 'Open', created: '2026-07-02',
      comments: [
        { author: 'Suman Poudel', side: 'school', message: 'Uploading our Grade 6 student list (412 rows) fails at row 38 with "Invalid date format". The same file worked last month.', at: '2026-07-02 09:14' },
        { author: 'Pramod Rai', side: 'platform', message: 'Thanks for reporting. Could you attach the CSV so we can reproduce? Row 38 likely has a BS date instead of AD.', at: '2026-07-02 11:40' },
        { author: 'Suman Poudel', side: 'school', message: 'Attached. You are right — some dates are in BS format. But the previous import accepted both.', at: '2026-07-02 14:05' },
      ],
    },
    {
      no: 'TKT-1041', school: 'Sunrise Public School', raisedBy: 'Anita Sharma (Admin)', subject: 'Need WhatsApp sender ID changed', priority: 'Medium', status: 'In progress', created: '2026-07-01',
      comments: [
        { author: 'Anita Sharma', side: 'school', message: 'Please change our WhatsApp sender name from "SunriseEdu" to "Sunrise Public School".', at: '2026-07-01 10:22' },
        { author: 'Pramod Rai', side: 'platform', message: 'Request submitted to the WhatsApp Business team. Usually takes 2–3 business days.', at: '2026-07-01 15:30' },
      ],
    },
    {
      no: 'TKT-1039', school: 'Riverdale World School', raisedBy: 'Bharat KC (Accountant)', subject: 'How to configure fee late fines?', priority: 'Low', status: 'Waiting', created: '2026-06-29',
      comments: [
        { author: 'Bharat KC', side: 'school', message: 'We want a flat Rs 100 fine after the 10th of each month. Where do we set this?', at: '2026-06-29 12:00' },
        { author: 'Pramod Rai', side: 'platform', message: 'Fee Management → Fee Structures → edit the fee type and set "Late fine amount" and "Due day". Let me know if you need a walkthrough call.', at: '2026-06-29 16:45' },
      ],
    },
    {
      no: 'TKT-1036', school: 'Himalaya Model School', raisedBy: 'Rita Joshi (Admin)', subject: 'Exam marksheet PDF shows wrong logo', priority: 'High', status: 'Open', created: '2026-06-27',
      comments: [
        { author: 'Rita Joshi', side: 'school', message: 'Marksheets generated this week still show our old logo, though we updated it in School Profile two weeks ago.', at: '2026-06-27 08:50' },
      ],
    },
    {
      no: 'TKT-1031', school: 'Everest Int’l School', raisedBy: 'Kiran Bhattarai (Admin)', subject: 'Request: transport GPS integration', priority: 'Low', status: 'Resolved', created: '2026-06-20',
      comments: [
        { author: 'Kiran Bhattarai', side: 'school', message: 'Is live GPS tracking of buses on the roadmap? Parents keep asking.', at: '2026-06-20 13:12' },
        { author: 'Pramod Rai', side: 'platform', message: 'It is on the roadmap for Q4 2026 as part of the Premium plan. Added your school to the early-access list.', at: '2026-06-21 09:05' },
        { author: 'Kiran Bhattarai', side: 'school', message: 'Great, thanks — closing this for now.', at: '2026-06-21 10:00' },
      ],
    },
    {
      no: 'TKT-1028', school: 'Shree Deep Sikshalaya', raisedBy: 'Deepak Shrestha (Admin)', subject: 'SMS credits not topping up', priority: 'High', status: 'Resolved', created: '2026-06-14',
      comments: [
        { author: 'Deepak Shrestha', side: 'school', message: 'We purchased 5,000 SMS credits yesterday but the balance still shows 120.', at: '2026-06-14 11:30' },
        { author: 'Pramod Rai', side: 'platform', message: 'Payment webhook from the gateway was delayed. Credits applied manually — balance now shows 5,120. Apologies!', at: '2026-06-14 14:55' },
      ],
    },
  ];

  /* ---------------- SCHOOL ADMIN ---------------- */

  readonly adminStats = [
    { label: 'Students', value: '1,248', sub: '+38 admissions this year', trend: 'up' },
    { label: 'Teachers', value: '52', sub: '4 on leave today', trend: '' },
    { label: 'Attendance Today', value: '93.4%', sub: '1,166 of 1,248 present', trend: 'up' },
    { label: 'Fees Due (July)', value: 'Rs 4.2L', sub: '212 unpaid invoices', trend: 'down' },
  ];

  readonly classes: SchoolClass[] = [
    { name: 'Grade 6', sections: [{ name: 'A', students: 42, teacher: 'S. Gurung' }, { name: 'B', students: 40, teacher: 'M. Adhikari' }] },
    { name: 'Grade 7', sections: [{ name: 'A', students: 44, teacher: 'P. Shrestha' }, { name: 'B', students: 41, teacher: 'K. Tamang' }] },
    { name: 'Grade 8', sections: [{ name: 'A', students: 38, teacher: 'R. Koirala' }, { name: 'B', students: 37, teacher: 'D. Maharjan' }] },
    { name: 'Grade 9', sections: [{ name: 'A', students: 36, teacher: 'B. Karki' }, { name: 'B', students: 35, teacher: 'N. Rana' }] },
    { name: 'Grade 10', sections: [{ name: 'A', students: 34, teacher: 'S. Pandey' }, { name: 'B', students: 33, teacher: 'A. Basnet' }] },
  ];

  /** Add a new class, optionally with an initial section (in-memory demo). */
  addClass(name: string, section?: { name: string; teacher: string }): void {
    const sections = section ? [{ name: section.name, students: 0, teacher: section.teacher || 'Unassigned' }] : [];
    this.classes.push({ name, sections });
  }

  /** Add a section to an existing class. */
  addSection(className: string, section: { name: string; teacher: string }): void {
    const cls = this.classes.find(c => c.name === className);
    if (cls) cls.sections.push({ name: section.name, students: 0, teacher: section.teacher || 'Unassigned' });
  }

  /** Remove a section from a class. */
  removeSection(cls: SchoolClass, section: ClassSection): void {
    cls.sections = cls.sections.filter(s => s !== section);
  }

  /** Remove an entire class. */
  removeClass(cls: SchoolClass): void {
    const i = this.classes.indexOf(cls);
    if (i > -1) this.classes.splice(i, 1);
  }

  readonly students: Student[] = [
    { adm: 'ADM-2081-012', name: 'Aarav Thapa', cls: 'Grade 8', sec: 'A', roll: 12, gender: 'M', guardian: 'Bikash Thapa', phone: '98410-22334', status: 'Active', feeDue: 12500 },
    { adm: 'ADM-2081-034', name: 'Sneha Shrestha', cls: 'Grade 8', sec: 'A', roll: 8, gender: 'F', guardian: 'Ram Shrestha', phone: '98020-11223', status: 'Active', feeDue: 0 },
    { adm: 'ADM-2081-055', name: 'Bibek Gurung', cls: 'Grade 8', sec: 'A', roll: 21, gender: 'M', guardian: 'Hari Gurung', phone: '98511-33445', status: 'Active', feeDue: 6250 },
    { adm: 'ADM-2080-101', name: 'Priya Karki', cls: 'Grade 9', sec: 'B', roll: 5, gender: 'F', guardian: 'Suman Karki', phone: '98080-55667', status: 'Active', feeDue: 0 },
    { adm: 'ADM-2080-118', name: 'Rohan Maharjan', cls: 'Grade 9', sec: 'A', roll: 17, gender: 'M', guardian: 'Raju Maharjan', phone: '98650-77889', status: 'Active', feeDue: 18750 },
    { adm: 'ADM-2079-201', name: 'Anisha Rai', cls: 'Grade 10', sec: 'A', roll: 3, gender: 'F', guardian: 'Deepak Rai', phone: '98120-99001', status: 'Active', feeDue: 0 },
    { adm: 'ADM-2079-215', name: 'Kiran Tamang', cls: 'Grade 10', sec: 'B', roll: 11, gender: 'M', guardian: 'Lakpa Tamang', phone: '98430-12131', status: 'Active', feeDue: 12500 },
    { adm: 'ADM-2082-004', name: 'Meera Adhikari', cls: 'Grade 6', sec: 'A', roll: 2, gender: 'F', guardian: 'Gopal Adhikari', phone: '98090-14151', status: 'Active', feeDue: 0 },
    { adm: 'ADM-2082-019', name: 'Sagar Basnet', cls: 'Grade 6', sec: 'B', roll: 15, gender: 'M', guardian: 'Krishna Basnet', phone: '98550-16171', status: 'Active', feeDue: 6250 },
    { adm: 'ADM-2081-077', name: 'Ritika Pandey', cls: 'Grade 7', sec: 'A', roll: 9, gender: 'F', guardian: 'Mohan Pandey', phone: '98010-18191', status: 'Inactive', feeDue: 0 },
    { adm: 'ADM-2080-134', name: 'Nabin Lama', cls: 'Grade 9', sec: 'B', roll: 22, gender: 'M', guardian: 'Pasang Lama', phone: '98460-20212', status: 'Active', feeDue: 0 },
    { adm: 'ADM-2082-031', name: 'Ojaswi Bhattarai', cls: 'Grade 6', sec: 'A', roll: 27, gender: 'F', guardian: 'Naresh Bhattarai', phone: '98110-22232', status: 'Active', feeDue: 12500 },
  ];

  /** Register a new admission (in-memory demo). Returns the generated admission no. */
  addStudent(input: Omit<Student, 'adm' | 'status' | 'feeDue'>): string {
    const adm = `ADM-2083-${String(this.students.length + 1).padStart(3, '0')}`;
    this.students.unshift({ ...input, adm, status: 'Active', feeDue: 0 });
    return adm;
  }

  /** Add a new teacher (in-memory demo). Returns the generated employee code. */
  addTeacher(input: Omit<Teacher, 'code' | 'status'>): string {
    const code = `EMP-${String(this.teachers.length + 31).padStart(3, '0')}`;
    this.teachers.unshift({ ...input, code, status: 'Active' });
    return code;
  }

  readonly teachers: Teacher[] = [
    { code: 'EMP-014', name: 'Rajesh Koirala', subject: 'Mathematics', classes: 'G8, G9, G10', phone: '98510-31415', email: 'rajesh.k@sunrise.edu.np', status: 'Active' },
    { code: 'EMP-008', name: 'Sunita Gurung', subject: 'English', classes: 'G6, G7', phone: '98020-92653', email: 'sunita.g@sunrise.edu.np', status: 'Active' },
    { code: 'EMP-021', name: 'Prakash Shrestha', subject: 'Science', classes: 'G7, G8', phone: '98410-58979', email: 'prakash.s@sunrise.edu.np', status: 'Active' },
    { code: 'EMP-011', name: 'Kamala Tamang', subject: 'Nepali', classes: 'G6, G7, G8', phone: '98080-32384', email: 'kamala.t@sunrise.edu.np', status: 'On leave' },
    { code: 'EMP-030', name: 'Dinesh Maharjan', subject: 'Social Studies', classes: 'G8, G9', phone: '98650-62643', email: 'dinesh.m@sunrise.edu.np', status: 'Active' },
    { code: 'EMP-017', name: 'Bina Karki', subject: 'Computer Science', classes: 'G9, G10', phone: '98120-38327', email: 'bina.k@sunrise.edu.np', status: 'Active' },
    { code: 'EMP-025', name: 'Niraj Rana', subject: 'Health & PE', classes: 'G6–G10', phone: '98430-95028', email: 'niraj.r@sunrise.edu.np', status: 'Active' },
    { code: 'EMP-019', name: 'Sarita Pandey', subject: 'Optional Math', classes: 'G9, G10', phone: '98090-84197', email: 'sarita.p@sunrise.edu.np', status: 'Active' },
  ];

  readonly feeStats = [
    { label: 'Collected (July)', value: 'Rs 18.6L', sub: '78% of billed', trend: 'up' },
    { label: 'Outstanding', value: 'Rs 4.2L', sub: '212 invoices', trend: '' },
    { label: 'Overdue > 30 days', value: 'Rs 1.1L', sub: '54 invoices', trend: 'down' },
  ];

  readonly feeInvoices: FeeInvoice[] = [
    { no: 'FI-26-0871', student: 'Aarav Thapa', cls: 'Grade 8-A', month: 'July 2026', amount: 12500, paid: 0, due: '2026-07-10', status: 'Unpaid' },
    { no: 'FI-26-0842', student: 'Sneha Shrestha', cls: 'Grade 8-A', month: 'July 2026', amount: 12500, paid: 12500, due: '2026-07-10', status: 'Paid' },
    { no: 'FI-26-0853', student: 'Bibek Gurung', cls: 'Grade 8-A', month: 'July 2026', amount: 12500, paid: 6250, due: '2026-07-10', status: 'Partial' },
    { no: 'FI-26-0790', student: 'Rohan Maharjan', cls: 'Grade 9-A', month: 'June 2026', amount: 12500, paid: 0, due: '2026-06-10', status: 'Overdue' },
    { no: 'FI-26-0866', student: 'Priya Karki', cls: 'Grade 9-B', month: 'July 2026', amount: 13500, paid: 13500, due: '2026-07-10', status: 'Paid' },
    { no: 'FI-26-0878', student: 'Kiran Tamang', cls: 'Grade 10-B', month: 'July 2026', amount: 14500, paid: 0, due: '2026-07-10', status: 'Unpaid' },
    { no: 'FI-26-0881', student: 'Anisha Rai', cls: 'Grade 10-A', month: 'July 2026', amount: 14500, paid: 14500, due: '2026-07-10', status: 'Paid' },
    { no: 'FI-26-0885', student: 'Sagar Basnet', cls: 'Grade 6-B', month: 'July 2026', amount: 10500, paid: 4250, due: '2026-07-10', status: 'Partial' },
  ];

  readonly exams: Exam[] = [
    {
      name: 'First Terminal Examination 2083', type: 'Term', start: '2026-08-17', end: '2026-08-26', classes: 'G6–G10', status: 'Scheduled',
      schedule: [
        { date: '2026-08-17', subject: 'English', time: '08:00 – 10:00', room: 'Hall A', fullMarks: 100 },
        { date: '2026-08-18', subject: 'Mathematics', time: '08:00 – 10:00', room: 'Hall A', fullMarks: 100 },
        { date: '2026-08-20', subject: 'Science', time: '08:00 – 10:00', room: 'Hall B', fullMarks: 100 },
        { date: '2026-08-21', subject: 'Nepali', time: '08:00 – 10:00', room: 'Hall A', fullMarks: 100 },
        { date: '2026-08-24', subject: 'Social Studies', time: '08:00 – 10:00', room: 'Hall B', fullMarks: 100 },
        { date: '2026-08-26', subject: 'Computer Science', time: '08:00 – 09:30', room: 'Lab 1', fullMarks: 75 },
      ],
    },
    { name: 'Unit Test — July', type: 'Unit Test', start: '2026-07-14', end: '2026-07-16', classes: 'G6–G10', status: 'Scheduled', schedule: [] },
    { name: 'Quarterly Assessment 2083', type: 'Quarterly', start: '2026-06-08', end: '2026-06-15', classes: 'G6–G10', status: 'Result published', schedule: [] },
    { name: 'Annual Examination 2082', type: 'Final', start: '2026-03-10', end: '2026-03-21', classes: 'G6–G10', status: 'Completed', schedule: [] },
  ];

  /** Create a new exam (in-memory demo). Returns the created exam. */
  addExam(input: { name: string; type: string; start: string; end: string; classes: string }): Exam {
    const exam: Exam = { ...input, status: 'Scheduled', schedule: [] };
    this.exams.unshift(exam);
    return exam;
  }

  /** Add a subject paper to an exam's schedule. */
  addExamPaper(exam: Exam, paper: ExamPaper): void {
    exam.schedule.push(paper);
    exam.schedule.sort((a, b) => a.date.localeCompare(b.date));
  }

  removeExamPaper(exam: Exam, paper: ExamPaper): void {
    exam.schedule = exam.schedule.filter(p => p !== paper);
  }

  readonly notices = [
    { title: 'First Terminal Exam Routine Published', audience: 'All', date: '2026-07-02', body: 'The routine for the First Terminal Examination has been published. Students can view the schedule in the exam section. Admit cards will be distributed from Shrawan 25.' },
    { title: 'Parent–Teacher Meeting', audience: 'Parents', date: '2026-06-28', body: 'A parent–teacher meeting is scheduled for Saturday, July 12 from 10 AM. Attendance of at least one guardian is mandatory.' },
    { title: 'School Bus Route 4 — Temporary Change', audience: 'Students', date: '2026-06-25', body: 'Due to road maintenance in Baneshwor, Route 4 will divert via Shantinagar until further notice. Pickup times shift by 10 minutes.' },
    { title: 'Inter-house Football Tournament', audience: 'Students', date: '2026-06-20', body: 'The annual inter-house football tournament begins July 18. Interested students should register with the sports department by July 10.' },
  ];

  readonly recentAdmissions = [
    { name: 'Ojaswi Bhattarai', cls: 'Grade 6-A', date: '2026-06-30' },
    { name: 'Sagar Basnet', cls: 'Grade 6-B', date: '2026-06-27' },
    { name: 'Meera Adhikari', cls: 'Grade 6-A', date: '2026-06-24' },
    { name: 'Aayush Nepal', cls: 'Grade 7-B', date: '2026-06-21' },
  ];

  readonly upcomingEvents = [
    { title: 'Unit Test — July', date: '2026-07-14', type: 'Exam' },
    { title: 'Parent–Teacher Meeting', date: '2026-07-12', type: 'Meeting' },
    { title: 'Inter-house Football Kickoff', date: '2026-07-18', type: 'Event' },
    { title: 'Janai Purnima (Holiday)', date: '2026-08-08', type: 'Holiday' },
  ];

  /* ---------------- TEACHER ---------------- */

  readonly teacherStats = [
    { label: 'My Classes', value: '4', sub: 'G8-A, G8-B, G9-A, G10-A', trend: '' },
    { label: 'Students Taught', value: '142', sub: 'across 4 sections', trend: '' },
    { label: 'Submissions To Grade', value: '8', sub: 'Algebra worksheet', trend: 'down' },
    { label: 'Periods Today', value: '5', sub: 'next: G9-A at 11:15', trend: '' },
  ];

  readonly myClasses = [
    { cls: 'Grade 8', sec: 'A', subject: 'Mathematics', students: 38, room: 'R-204', isClassTeacher: true },
    { cls: 'Grade 8', sec: 'B', subject: 'Mathematics', students: 37, room: 'R-205', isClassTeacher: false },
    { cls: 'Grade 9', sec: 'A', subject: 'Mathematics', students: 36, room: 'R-301', isClassTeacher: false },
    { cls: 'Grade 10', sec: 'A', subject: 'Optional Mathematics', students: 34, room: 'R-401', isClassTeacher: false },
  ];

  readonly classStudents = [
    { roll: 2, name: 'Sneha Shrestha' },
    { roll: 5, name: 'Bipin Nepali' },
    { roll: 8, name: 'Kritika Osti' },
    { roll: 12, name: 'Aarav Thapa' },
    { roll: 14, name: 'Sarina Dhakal' },
    { roll: 17, name: 'Sujal KC' },
    { roll: 21, name: 'Bibek Gurung' },
    { roll: 23, name: 'Aastha Poudel' },
    { roll: 27, name: 'Nischal Bista' },
    { roll: 31, name: 'Prerana Silwal' },
  ];

  readonly teacherHomework = [
    { title: 'Algebra Worksheet — Linear Equations', cls: 'Grade 8-A', subject: 'Mathematics', assigned: '2026-06-30', due: '2026-07-05', submitted: 30, total: 38, status: 'Open' },
    { title: 'Geometry: Triangle Congruence Proofs', cls: 'Grade 9-A', subject: 'Mathematics', assigned: '2026-06-28', due: '2026-07-03', submitted: 36, total: 36, status: 'Grading' },
    { title: 'Trigonometry Practice Set 4', cls: 'Grade 10-A', subject: 'Opt. Mathematics', assigned: '2026-06-25', due: '2026-07-01', submitted: 31, total: 34, status: 'Graded' },
    { title: 'Fractions & Decimals Revision', cls: 'Grade 8-B', subject: 'Mathematics', assigned: '2026-06-22', due: '2026-06-27', submitted: 37, total: 37, status: 'Graded' },
  ];

  readonly teacherTimetable: Record<string, { period: string; time: string; cls: string; room: string }[]> = {
    Sunday:    [{ period: 'P1', time: '09:00', cls: 'G8-A · Math', room: 'R-204' }, { period: 'P3', time: '11:15', cls: 'G9-A · Math', room: 'R-301' }, { period: 'P5', time: '13:30', cls: 'G8-B · Math', room: 'R-205' }],
    Monday:    [{ period: 'P2', time: '10:00', cls: 'G10-A · Opt Math', room: 'R-401' }, { period: 'P4', time: '12:15', cls: 'G8-A · Math', room: 'R-204' }],
    Tuesday:   [{ period: 'P1', time: '09:00', cls: 'G9-A · Math', room: 'R-301' }, { period: 'P2', time: '10:00', cls: 'G8-B · Math', room: 'R-205' }, { period: 'P6', time: '14:30', cls: 'G10-A · Opt Math', room: 'R-401' }],
    Wednesday: [{ period: 'P3', time: '11:15', cls: 'G8-A · Math', room: 'R-204' }, { period: 'P5', time: '13:30', cls: 'G9-A · Math', room: 'R-301' }],
    Thursday:  [{ period: 'P1', time: '09:00', cls: 'G8-B · Math', room: 'R-205' }, { period: 'P2', time: '10:00', cls: 'G8-A · Math', room: 'R-204' }, { period: 'P4', time: '12:15', cls: 'G10-A · Opt Math', room: 'R-401' }],
    Friday:    [{ period: 'P2', time: '10:00', cls: 'G9-A · Math', room: 'R-301' }, { period: 'P3', time: '11:15', cls: 'G8-A · Math', room: 'R-204' }],
  };

  /* ---------------- STUDENT (Aarav Thapa, Grade 8-A) ---------------- */

  readonly studentStats = [
    { label: 'Attendance (This Year)', value: '94.2%', sub: '113 of 120 days present', trend: 'up' },
    { label: 'Pending Homework', value: '2', sub: '1 due tomorrow', trend: '' },
    { label: 'Next Exam', value: 'Jul 14', sub: 'Unit Test — July', trend: '' },
    { label: 'Fee Due', value: 'Rs 12,500', sub: 'due by Jul 10', trend: 'down' },
  ];

  readonly studentAttendanceSummary = [
    { month: 'Baishakh (Apr–May)', present: 24, absent: 1, late: 0, pct: 96 },
    { month: 'Jestha (May–Jun)', present: 25, absent: 2, late: 1, pct: 89 },
    { month: 'Ashadh (Jun–Jul)', present: 23, absent: 0, late: 1, pct: 96 },
  ];

  readonly studentAttendanceRecent = [
    { date: '2026-07-03', day: 'Friday', status: 'Present' },
    { date: '2026-07-02', day: 'Thursday', status: 'Present' },
    { date: '2026-07-01', day: 'Wednesday', status: 'Late' },
    { date: '2026-06-30', day: 'Tuesday', status: 'Present' },
    { date: '2026-06-29', day: 'Monday', status: 'Present' },
    { date: '2026-06-28', day: 'Sunday', status: 'Present' },
  ];

  readonly studentHomework = [
    { title: 'Algebra Worksheet — Linear Equations', subject: 'Mathematics', teacher: 'R. Koirala', due: '2026-07-05', status: 'Pending' },
    { title: 'Essay: A Festival I Enjoy', subject: 'English', teacher: 'S. Gurung', due: '2026-07-04', status: 'Pending' },
    { title: 'Lab Report: Acid–Base Reactions', subject: 'Science', teacher: 'P. Shrestha', due: '2026-07-01', status: 'Submitted' },
    { title: 'निबन्ध: मेरो गाउँ', subject: 'Nepali', teacher: 'K. Tamang', due: '2026-06-28', status: 'Graded · 18/20' },
    { title: 'Map Work: Provinces of Nepal', subject: 'Social Studies', teacher: 'D. Maharjan', due: '2026-06-26', status: 'Graded · 15/20' },
  ];

  readonly studentTimetable: Record<string, string[]> = {
    //           P1          P2         P3          P4          P5         P6
    Sunday:    ['Math', 'English', 'Science', 'Nepali', 'Social', 'Computer'],
    Monday:    ['English', 'Math', 'Nepali', 'Science', 'Health/PE', 'Social'],
    Tuesday:   ['Science', 'Nepali', 'Math', 'English', 'Computer', 'Social'],
    Wednesday: ['Nepali', 'Science', 'Math', 'Social', 'English', 'Health/PE'],
    Thursday:  ['Social', 'Math', 'English', 'Computer', 'Science', 'Nepali'],
    Friday:    ['Math', 'Social', 'English', 'Science', 'Club', 'Club'],
  };

  readonly periodTimes = ['09:00', '10:00', '11:15', '12:15', '13:30', '14:30'];

  readonly studentResults = [
    { subject: 'English', fullMarks: 100, marks: 78, grade: 'B+' },
    { subject: 'Mathematics', fullMarks: 100, marks: 91, grade: 'A+' },
    { subject: 'Science', fullMarks: 100, marks: 84, grade: 'A' },
    { subject: 'Nepali', fullMarks: 100, marks: 72, grade: 'B+' },
    { subject: 'Social Studies', fullMarks: 100, marks: 80, grade: 'A' },
    { subject: 'Computer Science', fullMarks: 75, marks: 66, grade: 'A+' },
  ];

  readonly studentFees = [
    { no: 'FI-26-0871', month: 'July 2026', items: 'Tuition + Transport', amount: 12500, paid: 0, due: '2026-07-10', status: 'Unpaid' },
    { no: 'FI-26-0712', month: 'June 2026', items: 'Tuition + Transport', amount: 12500, paid: 12500, due: '2026-06-10', status: 'Paid' },
    { no: 'FI-26-0568', month: 'May 2026', items: 'Tuition + Transport + Exam', amount: 14000, paid: 14000, due: '2026-05-10', status: 'Paid' },
    { no: 'FI-26-0417', month: 'April 2026', items: 'Tuition + Transport + Annual charge', amount: 21500, paid: 21500, due: '2026-04-10', status: 'Paid' },
  ];

  /** Onboard a new school (in-memory demo — replace with a POST to the API later). */
  addSchool(input: { name: string; city: string; plan: string; status: string }): void {
    const initials = input.name
      .split(/\s+/)
      .map(w => w.charAt(0).toUpperCase())
      .join('')
      .replace(/[^A-Z]/g, '')
      .slice(0, 3)
      .padEnd(3, 'X');
    const seq = String(this.schools.length + 1).padStart(3, '0');
    this.schools.unshift({
      code: `${initials}${seq}`,
      name: input.name,
      city: input.city,
      plan: input.plan,
      students: 0,
      status: input.status,
      joined: new Date().toISOString().slice(0, 10),
    });
  }

  /**
   * Generate a student's daily attendance between two dates (in-memory demo).
   * Deterministic per student + date so results are stable across reloads.
   * Weekends (Saturday) are treated as holidays and skipped.
   */
  studentAttendanceBetween(adm: string, from: string, to: string):
      { date: string; day: string; status: 'Present' | 'Absent' | 'Late' | 'Holiday' }[] {
    const out: { date: string; day: string; status: 'Present' | 'Absent' | 'Late' | 'Holiday' }[] = [];
    const start = new Date(from);
    const end = new Date(to);
    if (isNaN(start.getTime()) || isNaN(end.getTime()) || start > end) return out;
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    // simple hash of admission number for per-student variation
    let seed = 0;
    for (const ch of adm) seed += ch.charCodeAt(0);

    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const dow = d.getDay();                 // 0 = Sun ... 6 = Sat
      const iso = d.toISOString().slice(0, 10);
      if (dow === 6) {                        // Saturday holiday in Nepal
        out.push({ date: iso, day: days[dow], status: 'Holiday' });
        continue;
      }
      // pseudo-random but deterministic
      const n = (seed + d.getDate() * 7 + d.getMonth() * 31) % 100;
      let status: 'Present' | 'Absent' | 'Late';
      if (n < 86) status = 'Present';
      else if (n < 94) status = 'Late';
      else status = 'Absent';
      out.push({ date: iso, day: days[dow], status });
    }
    return out;
  }

  /** Monthly tuition rate per class (in-memory demo — mirrors fee_structures). */
  readonly feeRates: Record<string, number> = {
    'Grade 6': 10500, 'Grade 7': 11500, 'Grade 8': 12500, 'Grade 9': 13500, 'Grade 10': 14500,
  };

  private feeSeq = 900;

  /**
   * Generate monthly invoices for all active students of a class (or all classes)
   * that don't already have an invoice for the given month. Returns count created.
   */
  generateInvoices(month: string, dueDate: string, className: string): number {
    const targets = this.students.filter(s =>
      s.status === 'Active' && (className === 'All' || s.cls === className),
    );
    let created = 0;
    for (const s of targets) {
      const already = this.feeInvoices.some(i => i.student === s.name && i.month === month);
      if (already) continue;
      const amount = this.feeRates[s.cls] ?? 12000;
      this.feeInvoices.unshift({
        no: `FI-26-${String(++this.feeSeq).padStart(4, '0')}`,
        student: s.name,
        cls: `${s.cls}-${s.sec}`,
        month,
        amount,
        paid: 0,
        due: dueDate,
        status: 'Unpaid',
        payments: [],
      });
      created++;
    }
    return created;
  }

  /** Record a (possibly partial) payment against an invoice. */
  recordFeePayment(inv: FeeInvoice, amount: number, method: string, ref: string, date: string): void {
    inv.paid = Math.min(inv.amount, inv.paid + amount);
    (inv.payments ??= []).push({ date, amount, method, ref });
    inv.status = inv.paid >= inv.amount ? 'Paid' : inv.paid > 0 ? 'Partial' : 'Unpaid';
  }

  /* ---------------- shared helpers ---------------- */

  /** Map a status string to a badge class used across all tables. */
  badgeClass(status: string): string {
    const s = status.toLowerCase();
    if (['active', 'paid', 'present', 'resolved', 'completed'].includes(s) || s.startsWith('graded')) return 'success';
    if (['trial', 'partial', 'late', 'waiting', 'grading', 'sent', 'in progress', 'submitted', 'scheduled', 'on leave'].includes(s)) return 'warning';
    if (['overdue', 'suspended', 'past due', 'absent', 'urgent', 'unpaid', 'inactive'].includes(s)) return 'danger';
    if (['open', 'result published', 'pending', 'high'].includes(s)) return 'info';
    return 'neutral';
  }

  grade(pct: number): string {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C+';
    if (pct >= 40) return 'C';
    return 'NG';
  }
}
