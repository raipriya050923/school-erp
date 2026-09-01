import 'models.dart';

/// All content in the app is hard-coded here — there is no network layer.
/// Swapping this file for a repository backed by an API is the only change
/// required to make the app live.
class SchoolData {
  const SchoolData._();

  static const String schoolName = 'Greenwood High School';
  static const String academicYear = '2025-2026';
  static const String todayLabel = 'Friday, Jan 17';
  static const String weekLabel = 'Week of Jan 13 - Jan 18, 2026';
  static const String currencySymbol = r'$';

  // ------------------------------------------------------------ the student

  static const Student student = Student(
    firstName: 'John',
    lastName: 'Smith',
    email: 'john.smith@school.edu',
    phone: '+1 (555) 123-4567',
    dateOfBirth: 'March 15, 2010',
    gender: 'Male',
    bloodGroup: 'O+',
    address: '123 Education Street, Academic City, CA 90210',
    nationality: 'American',
    studentId: 'STU-2025-0042',
    className: '10-A',
    section: 'A',
    rollNumber: '15',
    admissionDate: 'April 10, 2020',
    academicYear: '2025-2026',
    house: 'Blue House',
    classTeacher: 'Ms. Sarah Davis',
    guardians: <Guardian>[
      Guardian(
        relation: 'Father',
        name: 'Robert Smith',
        occupation: 'Software Engineer',
        phone: '+1 (555) 234-5678',
        email: 'robert.smith@email.com',
      ),
      Guardian(
        relation: 'Mother',
        name: 'Emily Smith',
        occupation: 'Doctor',
        phone: '+1 (555) 345-6789',
        email: 'emily.smith@email.com',
      ),
    ],
    achievements: <Achievement>[
      Achievement(
        title: 'Science Fair Winner',
        date: '2025',
        description: 'First place in Regional Science Fair',
      ),
      Achievement(
        title: 'Math Olympiad',
        date: '2024',
        description: 'Silver Medal in State Mathematics Olympiad',
      ),
      Achievement(
        title: 'Perfect Attendance',
        date: '2024',
        description: 'Awarded for 100% attendance in academic year',
      ),
    ],
  );

  // ---------------------------------------------------------- at-a-glance

  static const String overallAttendance = '92%';
  static const String overallGrade = 'A+';
  static const int classRank = 5;
  static const String averageScore = '87%';
  static const String averageScoreDelta = '+5% from last term';

  // -------------------------------------------------------------- timetable

  static const List<String> weekDays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const String shortBreak = '10:25 AM - 10:40 AM';
  static const String lunchBreak = '12:15 PM - 01:00 PM';

  static const Map<String, List<ClassPeriod>> timetable =
      <String, List<ClassPeriod>>{
        'Monday': <ClassPeriod>[
          ClassPeriod(
            startTime: '08:00',
            endTime: '08:45',
            subject: 'Mathematics',
            teacher: 'Mr. Johnson',
            room: 'Room 101',
          ),
          ClassPeriod(
            startTime: '08:50',
            endTime: '09:35',
            subject: 'Physics',
            teacher: 'Mrs. Smith',
            room: 'Lab 2',
          ),
          ClassPeriod(
            startTime: '09:40',
            endTime: '10:25',
            subject: 'English',
            teacher: 'Ms. Davis',
            room: 'Room 103',
          ),
          ClassPeriod(
            startTime: '10:40',
            endTime: '11:25',
            subject: 'Chemistry',
            teacher: 'Mr. Wilson',
            room: 'Lab 1',
          ),
          ClassPeriod(
            startTime: '11:30',
            endTime: '12:15',
            subject: 'History',
            teacher: 'Mr. Brown',
            room: 'Room 105',
          ),
          ClassPeriod(
            startTime: '01:00',
            endTime: '01:45',
            subject: 'Computer Science',
            teacher: 'Ms. Taylor',
            room: 'Computer Lab',
          ),
          ClassPeriod(
            startTime: '01:50',
            endTime: '02:35',
            subject: 'Physical Education',
            teacher: 'Mr. Clark',
            room: 'Sports Ground',
          ),
        ],
        'Tuesday': <ClassPeriod>[
          ClassPeriod(
            startTime: '08:00',
            endTime: '08:45',
            subject: 'English',
            teacher: 'Ms. Davis',
            room: 'Room 103',
          ),
          ClassPeriod(
            startTime: '08:50',
            endTime: '09:35',
            subject: 'Mathematics',
            teacher: 'Mr. Johnson',
            room: 'Room 101',
          ),
          ClassPeriod(
            startTime: '09:40',
            endTime: '10:25',
            subject: 'Biology',
            teacher: 'Mrs. Anderson',
            room: 'Lab 3',
          ),
          ClassPeriod(
            startTime: '10:40',
            endTime: '11:25',
            subject: 'Physics',
            teacher: 'Mrs. Smith',
            room: 'Lab 2',
          ),
          ClassPeriod(
            startTime: '11:30',
            endTime: '12:15',
            subject: 'Geography',
            teacher: 'Mr. Martinez',
            room: 'Room 107',
          ),
          ClassPeriod(
            startTime: '01:00',
            endTime: '01:45',
            subject: 'Art',
            teacher: 'Ms. White',
            room: 'Art Room',
          ),
          ClassPeriod(
            startTime: '01:50',
            endTime: '02:35',
            subject: 'Music',
            teacher: 'Mr. Harris',
            room: 'Music Room',
          ),
        ],
        'Wednesday': <ClassPeriod>[
          ClassPeriod(
            startTime: '08:00',
            endTime: '08:45',
            subject: 'Chemistry',
            teacher: 'Mr. Wilson',
            room: 'Lab 1',
          ),
          ClassPeriod(
            startTime: '08:50',
            endTime: '09:35',
            subject: 'History',
            teacher: 'Mr. Brown',
            room: 'Room 105',
          ),
          ClassPeriod(
            startTime: '09:40',
            endTime: '10:25',
            subject: 'Mathematics',
            teacher: 'Mr. Johnson',
            room: 'Room 101',
          ),
          ClassPeriod(
            startTime: '10:40',
            endTime: '11:25',
            subject: 'English',
            teacher: 'Ms. Davis',
            room: 'Room 103',
          ),
          ClassPeriod(
            startTime: '11:30',
            endTime: '12:15',
            subject: 'Computer Science',
            teacher: 'Ms. Taylor',
            room: 'Computer Lab',
          ),
          ClassPeriod(
            startTime: '01:00',
            endTime: '01:45',
            subject: 'Physics',
            teacher: 'Mrs. Smith',
            room: 'Lab 2',
          ),
          ClassPeriod(
            startTime: '01:50',
            endTime: '02:35',
            subject: 'Library',
            teacher: 'Ms. Green',
            room: 'Library',
          ),
        ],
        'Thursday': <ClassPeriod>[
          ClassPeriod(
            startTime: '08:00',
            endTime: '08:45',
            subject: 'Biology',
            teacher: 'Mrs. Anderson',
            room: 'Lab 3',
          ),
          ClassPeriod(
            startTime: '08:50',
            endTime: '09:35',
            subject: 'English',
            teacher: 'Ms. Davis',
            room: 'Room 103',
          ),
          ClassPeriod(
            startTime: '09:40',
            endTime: '10:25',
            subject: 'Chemistry',
            teacher: 'Mr. Wilson',
            room: 'Lab 1',
          ),
          ClassPeriod(
            startTime: '10:40',
            endTime: '11:25',
            subject: 'Mathematics',
            teacher: 'Mr. Johnson',
            room: 'Room 101',
          ),
          ClassPeriod(
            startTime: '11:30',
            endTime: '12:15',
            subject: 'Geography',
            teacher: 'Mr. Martinez',
            room: 'Room 107',
          ),
          ClassPeriod(
            startTime: '01:00',
            endTime: '01:45',
            subject: 'History',
            teacher: 'Mr. Brown',
            room: 'Room 105',
          ),
          ClassPeriod(
            startTime: '01:50',
            endTime: '02:35',
            subject: 'Physical Education',
            teacher: 'Mr. Clark',
            room: 'Sports Ground',
          ),
        ],
        'Friday': <ClassPeriod>[
          ClassPeriod(
            startTime: '08:00',
            endTime: '08:45',
            subject: 'Physics',
            teacher: 'Mrs. Smith',
            room: 'Lab 2',
          ),
          ClassPeriod(
            startTime: '08:50',
            endTime: '09:35',
            subject: 'Computer Science',
            teacher: 'Ms. Taylor',
            room: 'Computer Lab',
          ),
          ClassPeriod(
            startTime: '09:40',
            endTime: '10:25',
            subject: 'English',
            teacher: 'Ms. Davis',
            room: 'Room 103',
          ),
          ClassPeriod(
            startTime: '10:40',
            endTime: '11:25',
            subject: 'Biology',
            teacher: 'Mrs. Anderson',
            room: 'Lab 3',
          ),
          ClassPeriod(
            startTime: '11:30',
            endTime: '12:15',
            subject: 'Mathematics',
            teacher: 'Mr. Johnson',
            room: 'Room 101',
          ),
          ClassPeriod(
            startTime: '01:00',
            endTime: '01:45',
            subject: 'Art',
            teacher: 'Ms. White',
            room: 'Art Room',
          ),
          ClassPeriod(
            startTime: '01:50',
            endTime: '02:35',
            subject: 'Club Activities',
            teacher: 'Various',
            room: 'Various',
          ),
        ],
        'Saturday': <ClassPeriod>[
          ClassPeriod(
            startTime: '08:00',
            endTime: '08:45',
            subject: 'Mathematics',
            teacher: 'Mr. Johnson',
            room: 'Room 101',
          ),
          ClassPeriod(
            startTime: '08:50',
            endTime: '09:35',
            subject: 'Science Quiz',
            teacher: 'Mrs. Smith',
            room: 'Hall',
          ),
          ClassPeriod(
            startTime: '09:40',
            endTime: '10:25',
            subject: 'English',
            teacher: 'Ms. Davis',
            room: 'Room 103',
          ),
          ClassPeriod(
            startTime: '10:40',
            endTime: '11:25',
            subject: 'Sports Practice',
            teacher: 'Mr. Clark',
            room: 'Sports Ground',
          ),
        ],
      };

  /// The five periods surfaced on the dashboard as "today".
  static const List<ClassPeriod> todaySchedule = <ClassPeriod>[
    ClassPeriod(
      startTime: '08:00',
      endTime: '08:45',
      subject: 'Mathematics',
      teacher: 'Mr. Johnson',
      room: 'Room 101',
    ),
    ClassPeriod(
      startTime: '09:00',
      endTime: '09:45',
      subject: 'Physics',
      teacher: 'Mrs. Smith',
      room: 'Lab 2',
    ),
    ClassPeriod(
      startTime: '10:00',
      endTime: '10:45',
      subject: 'English',
      teacher: 'Ms. Davis',
      room: 'Room 103',
    ),
    ClassPeriod(
      startTime: '11:30',
      endTime: '12:15',
      subject: 'Computer Science',
      teacher: 'Mr. Wilson',
      room: 'Lab 1',
    ),
    ClassPeriod(
      startTime: '01:00',
      endTime: '01:45',
      subject: 'History',
      teacher: 'Mr. Brown',
      room: 'Room 105',
    ),
  ];

  // ------------------------------------------------------------- attendance

  static const List<String> months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const AttendanceMonth januaryAttendance = AttendanceMonth(
    name: 'January',
    year: 2026,
    firstWeekdayOffset: 3,
    totalDays: 24,
    present: 22,
    absent: 1,
    late: 1,
    holidays: 7,
    days: <AttendanceDay>[
      AttendanceDay(
        date: 1,
        status: DayStatus.holiday,
        note: "New Year's Day",
      ),
      AttendanceDay(date: 2, status: DayStatus.present),
      AttendanceDay(date: 3, status: DayStatus.present),
      AttendanceDay(date: 4, status: DayStatus.weekend),
      AttendanceDay(date: 5, status: DayStatus.weekend),
      AttendanceDay(date: 6, status: DayStatus.present),
      AttendanceDay(date: 7, status: DayStatus.present),
      AttendanceDay(date: 8, status: DayStatus.present),
      AttendanceDay(
        date: 9,
        status: DayStatus.late,
        note: 'Arrived 15 mins late',
      ),
      AttendanceDay(date: 10, status: DayStatus.present),
      AttendanceDay(date: 11, status: DayStatus.weekend),
      AttendanceDay(date: 12, status: DayStatus.weekend),
      AttendanceDay(date: 13, status: DayStatus.present),
      AttendanceDay(date: 14, status: DayStatus.present),
      AttendanceDay(date: 15, status: DayStatus.absent, note: 'Sick leave'),
      AttendanceDay(date: 16, status: DayStatus.present),
      AttendanceDay(date: 17, status: DayStatus.present),
      AttendanceDay(date: 18, status: DayStatus.weekend),
      AttendanceDay(date: 19, status: DayStatus.weekend),
      AttendanceDay(date: 20, status: DayStatus.present),
      AttendanceDay(date: 21, status: DayStatus.present),
      AttendanceDay(date: 22, status: DayStatus.present),
      AttendanceDay(date: 23, status: DayStatus.present),
      AttendanceDay(date: 24, status: DayStatus.present),
      AttendanceDay(date: 25, status: DayStatus.weekend),
      AttendanceDay(date: 26, status: DayStatus.holiday, note: 'Republic Day'),
      AttendanceDay(date: 27, status: DayStatus.present),
      AttendanceDay(date: 28, status: DayStatus.present),
      AttendanceDay(date: 29, status: DayStatus.present),
      AttendanceDay(date: 30, status: DayStatus.present),
      AttendanceDay(date: 31, status: DayStatus.present),
    ],
  );

  static const List<SubjectAttendance> subjectAttendance = <SubjectAttendance>[
    SubjectAttendance(subject: 'Mathematics', total: 45, attended: 43),
    SubjectAttendance(subject: 'Physics', total: 40, attended: 38),
    SubjectAttendance(subject: 'Chemistry', total: 38, attended: 36),
    SubjectAttendance(subject: 'English', total: 42, attended: 40),
    SubjectAttendance(subject: 'Biology', total: 35, attended: 33),
    SubjectAttendance(subject: 'History', total: 30, attended: 29),
    SubjectAttendance(subject: 'Computer Science', total: 28, attended: 27),
  ];

  static const List<AttendanceRecord> recentAttendance = <AttendanceRecord>[
    AttendanceRecord(
      date: 'Jan 17, 2026',
      day: 'Friday',
      status: DayStatus.present,
      checkIn: '07:55 AM',
      checkOut: '02:40 PM',
    ),
    AttendanceRecord(
      date: 'Jan 16, 2026',
      day: 'Thursday',
      status: DayStatus.present,
      checkIn: '07:50 AM',
      checkOut: '02:35 PM',
    ),
    AttendanceRecord(
      date: 'Jan 15, 2026',
      day: 'Wednesday',
      status: DayStatus.absent,
      note: 'Sick leave',
    ),
    AttendanceRecord(
      date: 'Jan 14, 2026',
      day: 'Tuesday',
      status: DayStatus.present,
      checkIn: '07:52 AM',
      checkOut: '02:38 PM',
    ),
    AttendanceRecord(
      date: 'Jan 13, 2026',
      day: 'Monday',
      status: DayStatus.present,
      checkIn: '07:48 AM',
      checkOut: '02:42 PM',
    ),
  ];

  // ---------------------------------------------------------------- results

  static const List<ExamResult> results = <ExamResult>[
    ExamResult(
      exam: 'Mid-Term',
      examDate: 'October 2025',
      totalMarks: 500,
      obtained: 437,
      grade: 'A',
      rank: 5,
      totalStudents: 45,
      subjects: <SubjectResult>[
        SubjectResult(
          name: 'Mathematics',
          maxMarks: 100,
          obtained: 92,
          grade: 'A+',
        ),
        SubjectResult(
          name: 'Physics',
          maxMarks: 100,
          obtained: 88,
          grade: 'A',
        ),
        SubjectResult(
          name: 'Chemistry',
          maxMarks: 100,
          obtained: 85,
          grade: 'A',
        ),
        SubjectResult(
          name: 'English',
          maxMarks: 100,
          obtained: 90,
          grade: 'A+',
        ),
        SubjectResult(
          name: 'Biology',
          maxMarks: 100,
          obtained: 82,
          grade: 'A',
        ),
      ],
    ),
    ExamResult(
      exam: 'Final',
      examDate: 'March 2025',
      totalMarks: 500,
      obtained: 445,
      grade: 'A+',
      rank: 3,
      totalStudents: 45,
      subjects: <SubjectResult>[
        SubjectResult(
          name: 'Mathematics',
          maxMarks: 100,
          obtained: 95,
          grade: 'A+',
        ),
        SubjectResult(
          name: 'Physics',
          maxMarks: 100,
          obtained: 90,
          grade: 'A+',
        ),
        SubjectResult(
          name: 'Chemistry',
          maxMarks: 100,
          obtained: 87,
          grade: 'A',
        ),
        SubjectResult(
          name: 'English',
          maxMarks: 100,
          obtained: 88,
          grade: 'A',
        ),
        SubjectResult(
          name: 'Biology',
          maxMarks: 100,
          obtained: 85,
          grade: 'A',
        ),
      ],
    ),
    ExamResult(
      exam: 'Unit Test 1',
      examDate: 'August 2025',
      totalMarks: 250,
      obtained: 215,
      grade: 'A',
      rank: 7,
      totalStudents: 45,
      subjects: <SubjectResult>[
        SubjectResult(
          name: 'Mathematics',
          maxMarks: 50,
          obtained: 45,
          grade: 'A+',
        ),
        SubjectResult(name: 'Physics', maxMarks: 50, obtained: 42, grade: 'A'),
        SubjectResult(
          name: 'Chemistry',
          maxMarks: 50,
          obtained: 40,
          grade: 'A',
        ),
        SubjectResult(
          name: 'English',
          maxMarks: 50,
          obtained: 44,
          grade: 'A+',
        ),
        SubjectResult(
          name: 'Biology',
          maxMarks: 50,
          obtained: 44,
          grade: 'A+',
        ),
      ],
    ),
    ExamResult(
      exam: 'Unit Test 2',
      examDate: 'December 2025',
      totalMarks: 250,
      obtained: 220,
      grade: 'A',
      rank: 4,
      totalStudents: 45,
      subjects: <SubjectResult>[
        SubjectResult(
          name: 'Mathematics',
          maxMarks: 50,
          obtained: 47,
          grade: 'A+',
        ),
        SubjectResult(name: 'Physics', maxMarks: 50, obtained: 44, grade: 'A+'),
        SubjectResult(
          name: 'Chemistry',
          maxMarks: 50,
          obtained: 42,
          grade: 'A',
        ),
        SubjectResult(
          name: 'English',
          maxMarks: 50,
          obtained: 45,
          grade: 'A+',
        ),
        SubjectResult(
          name: 'Biology',
          maxMarks: 50,
          obtained: 42,
          grade: 'A',
        ),
      ],
    ),
  ];

  /// Chronological performance used by the trend chart.
  static const List<({String exam, double percentage})> performanceTrend =
      <({String exam, double percentage})>[
        (exam: 'Unit 1', percentage: 86),
        (exam: 'Mid-Term', percentage: 87.4),
        (exam: 'Unit 2', percentage: 88),
        (exam: 'Final', percentage: 89),
      ];

  static const List<({String grade, String range})> gradingScale =
      <({String grade, String range})>[
        (grade: 'A+', range: '90% & above'),
        (grade: 'A', range: '80% - 89%'),
        (grade: 'B+', range: '70% - 79%'),
        (grade: 'B', range: '60% - 69%'),
        (grade: 'C', range: 'Below 60%'),
      ];

  // ------------------------------------------------------------ assignments

  static const List<Assignment> assignments = <Assignment>[
    Assignment(
      id: 1,
      title: 'Quadratic Equations Problem Set',
      subject: 'Mathematics',
      teacher: 'Mr. Johnson',
      assignedDate: 'Jan 10, 2026',
      dueDate: 'Jan 20, 2026',
      status: AssignmentStatus.pending,
      description:
          'Solve problems 1-20 from Chapter 5. Show all working steps.',
      attachments: <String>['Chapter5_Problems.pdf'],
      maxMarks: 50,
    ),
    Assignment(
      id: 2,
      title: "Newton's Laws Lab Report",
      subject: 'Physics',
      teacher: 'Mrs. Smith',
      assignedDate: 'Jan 8, 2026',
      dueDate: 'Jan 18, 2026',
      status: AssignmentStatus.submitted,
      submittedDate: 'Jan 16, 2026',
      description:
          "Write a detailed lab report on the experiment conducted on Newton's Laws of Motion.",
      attachments: <String>['Lab_Report_Template.docx'],
      maxMarks: 30,
    ),
    Assignment(
      id: 3,
      title: 'Essay: Climate Change Impact',
      subject: 'English',
      teacher: 'Ms. Davis',
      assignedDate: 'Jan 5, 2026',
      dueDate: 'Jan 15, 2026',
      status: AssignmentStatus.graded,
      submittedDate: 'Jan 14, 2026',
      description:
          'Write a 1000-word essay on the impact of climate change on biodiversity.',
      attachments: <String>['Essay_Guidelines.pdf'],
      maxMarks: 40,
      obtainedMarks: 36,
      feedback:
          'Excellent analysis and well-structured arguments. Good use of references.',
    ),
    Assignment(
      id: 4,
      title: 'Organic Chemistry Worksheet',
      subject: 'Chemistry',
      teacher: 'Mr. Wilson',
      assignedDate: 'Jan 12, 2026',
      dueDate: 'Jan 22, 2026',
      status: AssignmentStatus.pending,
      description:
          'Complete the worksheet on organic compounds and their reactions.',
      attachments: <String>['Organic_Chemistry_Worksheet.pdf'],
      maxMarks: 25,
    ),
    Assignment(
      id: 5,
      title: 'Cell Biology Diagram',
      subject: 'Biology',
      teacher: 'Mrs. Anderson',
      assignedDate: 'Jan 3, 2026',
      dueDate: 'Jan 13, 2026',
      status: AssignmentStatus.graded,
      submittedDate: 'Jan 12, 2026',
      description: 'Draw and label the structure of animal and plant cells.',
      maxMarks: 20,
      obtainedMarks: 18,
      feedback: 'Very neat diagrams with accurate labeling.',
    ),
    Assignment(
      id: 6,
      title: 'World War II Timeline',
      subject: 'History',
      teacher: 'Mr. Brown',
      assignedDate: 'Jan 1, 2026',
      dueDate: 'Jan 11, 2026',
      status: AssignmentStatus.overdue,
      description:
          'Create a detailed timeline of major events during World War II (1939-1945).',
      attachments: <String>['Timeline_Template.docx'],
      maxMarks: 30,
    ),
  ];

  // ------------------------------------------------------------------- fees

  static const List<FeeComponent> feeStructure = <FeeComponent>[
    FeeComponent(name: 'Tuition Fee', amount: 5000, frequency: 'Quarterly'),
    FeeComponent(name: 'Lab Fee', amount: 500, frequency: 'Quarterly'),
    FeeComponent(name: 'Library Fee', amount: 200, frequency: 'Quarterly'),
    FeeComponent(name: 'Sports Fee', amount: 300, frequency: 'Quarterly'),
    FeeComponent(
      name: 'Computer Lab Fee',
      amount: 400,
      frequency: 'Quarterly',
    ),
    FeeComponent(name: 'Activity Fee', amount: 250, frequency: 'Quarterly'),
  ];

  static const List<PaymentRecord> paymentHistory = <PaymentRecord>[
    PaymentRecord(
      id: 'TXN001',
      date: 'Oct 15, 2025',
      description: 'Q3 2025 - Tuition & Fees',
      amount: 6650,
      receiptNo: 'RCP-2025-0345',
      paymentMethod: 'Online Payment',
    ),
    PaymentRecord(
      id: 'TXN002',
      date: 'Jul 10, 2025',
      description: 'Q2 2025 - Tuition & Fees',
      amount: 6650,
      receiptNo: 'RCP-2025-0234',
      paymentMethod: 'Bank Transfer',
    ),
    PaymentRecord(
      id: 'TXN003',
      date: 'Apr 05, 2025',
      description: 'Q1 2025 - Tuition & Fees',
      amount: 6650,
      receiptNo: 'RCP-2025-0123',
      paymentMethod: 'Online Payment',
    ),
    PaymentRecord(
      id: 'TXN004',
      date: 'Jan 08, 2025',
      description: 'Annual Registration Fee',
      amount: 2000,
      receiptNo: 'RCP-2025-0012',
      paymentMethod: 'Cash',
    ),
  ];

  static const List<PendingPayment> pendingPayments = <PendingPayment>[
    PendingPayment(
      id: 'PEN001',
      description: 'Q4 2025 - Tuition & Fees',
      amount: 6650,
      dueDate: 'Jan 31, 2026',
      status: PendingStatus.dueSoon,
    ),
    PendingPayment(
      id: 'PEN002',
      description: 'Annual Sports Day Fee',
      amount: 500,
      dueDate: 'Feb 05, 2026',
      status: PendingStatus.upcoming,
    ),
  ];

  static const String feeNote =
      'Fees are payable at the beginning of each quarter. '
      'Late payment may attract a fine of \$50 per week.';

  // ---------------------------------------------------------- notifications

  static List<AppNotification> notifications() => <AppNotification>[
    AppNotification(
      id: 1,
      title: 'Assignment Due Tomorrow',
      message:
          'Your Mathematics assignment "Quadratic Equations Problem Set" is due tomorrow. Make sure to submit it on time.',
      type: NotificationType.assignment,
      date: 'Jan 17, 2026',
      time: '09:00 AM',
      priority: NotificationPriority.high,
    ),
    AppNotification(
      id: 2,
      title: 'Mid-Term Exam Schedule Released',
      message:
          'The mid-term examination schedule for February 2026 has been released. Please check the examination section for details.',
      type: NotificationType.exam,
      date: 'Jan 16, 2026',
      time: '02:30 PM',
      priority: NotificationPriority.medium,
    ),
    AppNotification(
      id: 3,
      title: 'Fee Payment Reminder',
      message:
          'Your quarterly fee payment of \$6,650 is due on January 31, 2026. Please make the payment to avoid late fees.',
      type: NotificationType.fee,
      date: 'Jan 15, 2026',
      time: '10:00 AM',
      priority: NotificationPriority.high,
      read: true,
    ),
    AppNotification(
      id: 4,
      title: 'Parent-Teacher Meeting',
      message:
          'A parent-teacher meeting is scheduled for January 25, 2026, at 10:00 AM. Your parents are requested to attend.',
      type: NotificationType.event,
      date: 'Jan 14, 2026',
      time: '11:30 AM',
      priority: NotificationPriority.medium,
      read: true,
    ),
    AppNotification(
      id: 5,
      title: 'Result Published',
      message:
          'Your Unit Test 2 results have been published. You scored 88% and secured 4th rank in class. Congratulations!',
      type: NotificationType.result,
      date: 'Jan 12, 2026',
      time: '04:00 PM',
      priority: NotificationPriority.low,
      read: true,
    ),
    AppNotification(
      id: 6,
      title: 'Library Book Return',
      message:
          'Please return the library book "Advanced Physics" by January 20, 2026, to avoid penalty charges.',
      type: NotificationType.general,
      date: 'Jan 10, 2026',
      time: '09:15 AM',
      priority: NotificationPriority.low,
      read: true,
    ),
    AppNotification(
      id: 7,
      title: 'Annual Sports Day Registration',
      message:
          'Registration for Annual Sports Day is now open. Last date to register is January 28, 2026.',
      type: NotificationType.event,
      date: 'Jan 8, 2026',
      time: '03:00 PM',
      priority: NotificationPriority.medium,
      read: true,
    ),
    AppNotification(
      id: 8,
      title: 'Holiday Notice',
      message:
          'School will remain closed on January 26, 2026, on account of Republic Day.',
      type: NotificationType.general,
      date: 'Jan 5, 2026',
      time: '10:00 AM',
      priority: NotificationPriority.low,
      read: true,
    ),
  ];
}
