# EduNexus — Login Accounts

All seeded users share the same demo password:

> **Password:** `Password@123`

Log in at the app's `/login` page with the **username** (or the email) and the password above.
Passwords are stored as **bcrypt** hashes in the `users` table (migration `006_auth_passwords.sql`);
the plaintext is only listed here for demo/testing convenience.

---

## Platform (Super Admin)

| Role | Username | Email | Password |
|------|----------|-------|----------|
| Super Admin | `pramod` | pramod@edunexus.io | `Password@123` |
| Platform Support | `support` | support@edunexus.io | `Password@123` |

## School Admins (one per school)

| School | Username | Email | Password |
|--------|----------|-------|----------|
| Sunrise Public School | `anita` | anita@sunrise.edu.np | `Password@123` |
| Green Valley Academy | `suman` | suman@greenvalley.edu.np | `Password@123` |
| Himalaya Model School | `rita` | rita@himalaya.edu.np | `Password@123` |
| Everest Int'l School | `kiran` | kiran@everest.edu.np | `Password@123` |
| Riverdale World School | `bharat` | bharat@riverdale.edu.np | `Password@123` |
| Blue Lotus Academy | `sabina` | sabina@bluelotus.edu.np | `Password@123` |
| Nagarjun Hill School | `prakash` | prakash@nagarjun.edu.np | `Password@123` |
| Shree Deep Sikshalaya | `deepak` | deepak@shreedeep.edu.np | `Password@123` |

## Teachers (Sunrise Public School)

| Name | Username | Email | Password |
|------|----------|-------|----------|
| Rajesh Koirala (Maths) | `rajesh.k` | rajesh.k@sunrise.edu.np | `Password@123` |
| Sunita Gurung (English) | `sunita.g` | sunita.g@sunrise.edu.np | `Password@123` |
| Prakash Shrestha (Science) | `prakash.s` | prakash.s@sunrise.edu.np | `Password@123` |
| Kamala Tamang (Nepali) | `kamala.t` | kamala.t@sunrise.edu.np | `Password@123` |
| Dinesh Maharjan (Social) | `dinesh.m` | dinesh.m@sunrise.edu.np | `Password@123` |
| Bina Karki (Computer) | `bina.k` | bina.k@sunrise.edu.np | `Password@123` |
| Niraj Rana (Health & PE) | `niraj.r` | niraj.r@sunrise.edu.np | `Password@123` |
| Sarita Pandey (Opt. Maths) | `sarita.p` | sarita.p@sunrise.edu.np | `Password@123` |

## Students (Sunrise Public School)

| Name | Username | Email | Password |
|------|----------|-------|----------|
| Aarav Thapa (G8-A) | `aarav.t` | aarav.t@sunrise.edu.np | `Password@123` |
| Sneha Shrestha (G8-A) | `sneha.s` | sneha.s@sunrise.edu.np | `Password@123` |
| Bibek Gurung (G8-A) | `bibek.g` | bibek.g@sunrise.edu.np | `Password@123` |
| Priya Karki (G9-B) | `priya.k` | priya.k@sunrise.edu.np | `Password@123` |
| Rohan Maharjan (G9-A) | `rohan.m` | rohan.m@sunrise.edu.np | `Password@123` |
| Anisha Rai (G10-A) | `anisha.r` | anisha.r@sunrise.edu.np | `Password@123` |
| Kiran Tamang (G10-B) | `kiran.t` | kiran.t@sunrise.edu.np | `Password@123` |
| Meera Adhikari (G6-A) | `meera.a` | meera.a@sunrise.edu.np | `Password@123` |
| Sagar Basnet (G6-B) | `sagar.b` | sagar.b@sunrise.edu.np | `Password@123` |
| Ritika Pandey (G7-A, inactive) | `ritika.p` | ritika.p@sunrise.edu.np | `Password@123` |
| Nabin Lama (G9-B) | `nabin.l` | nabin.l@sunrise.edu.np | `Password@123` |
| Ojaswi Bhattarai (G6-A) | `ojaswi.b` | ojaswi.b@sunrise.edu.np | `Password@123` |

## Parents (Sunrise Public School)

| Name | Username | Email | Password |
|------|----------|-------|----------|
| Bikash Thapa | `bikash.t` | bikash.thapa@gmail.com | `Password@123` |
| Ram Shrestha | `ram.s` | ram.shrestha@gmail.com | `Password@123` |
| Hari Gurung | `hari.g` | hari.gurung@gmail.com | `Password@123` |
| Suman Karki | `suman.k` | suman.karki@gmail.com | `Password@123` |
| Raju Maharjan | `raju.m` | raju.maharjan@gmail.com | `Password@123` |
| Deepak Rai | `deepak.r` | deepak.rai@gmail.com | `Password@123` |

---

## Which portal each role lands on

| Role (`user_type`) | Portal after login |
|--------------------|--------------------|
| `super_admin` | `/super-admin` |
| `school_admin` | `/admin` |
| `teacher` | `/teacher` |
| `student` | `/student` |

> The four "active" portals are wired to a specific tenant/user via config
> (`School:CurrentSchoolId`, `Teacher:CurrentStaffId`, `Student:CurrentStudentId`).
> For the demo, the data-serving portals are scoped to **Sunrise Public School** —
> so sign in as `anita` (admin), `rajesh.k` (teacher), or `aarav.t` (student) to see
> the live data that matches those config values.

## Auth features

- **Login** — `POST /api/auth/login` (username or email + password, bcrypt-verified)
- **Change password** — top-right user menu → *Change Password* (`POST /api/auth/change-password`)
- **Forgot password** — `/forgot-password` → generates a reset token (`POST /api/auth/forgot-password`);
  the demo returns the token on screen since there's no real inbox
- **Reset password** — `/reset-password?token=…` (`POST /api/auth/reset-password`)
