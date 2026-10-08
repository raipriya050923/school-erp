# पाठशाला — Login Accounts

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

> Each portal is scoped to the signed-in user's own tenant. Login issues a JWT holding
> `school_id` (plus `staff_id` / `student_id` for the teacher and student portals), and the
> API resolves every query from those claims — so `anita` sees Sunrise, `suman` sees Green
> Valley, and a brand-new school's admin sees an empty school. The old
> `School:CurrentSchoolId` / `Teacher:CurrentStaffId` / `Student:CurrentStudentId` settings
> are gone; deleting them from `appsettings.json` changes nothing.
>
> Sunrise Public School (`anita`, `rajesh.k`, `aarav.t`) is still the only tenant with a full
> set of seeded data.

## Newly onboarded schools

Super Admin → **School Management → + Onboard School** now provisions the school's first
`school_admin` login automatically. On success a dialog shows the generated **username** and
**temporary password** — copy them there and then, because only the bcrypt hash is stored and
the plaintext is never retrievable afterwards. (Sending it by email is not wired up yet; if the
credentials are lost, use *Forgot password* on the login page.)

- Username is derived from the school name, e.g. "Sunrise Public School" → `sunrise.admin`
  (a counter is appended if that name is taken — logins resolve across all tenants).
- The admin's email is the school's contact email, so onboarding is rejected if that address
  already belongs to another account.
- Password is 12 characters from a CSPRNG, with look-alike characters (`0/O`, `1/l/I`) excluded.

The new admin sees only their own school's data — tenant scope comes from their token (below).

## Newly registered teachers and students

Admin → **Teachers → + Add Teacher** and **Students → + New Admission** now provision a portal
login automatically, and show the generated **username** and **temporary password** in a dialog.
Copy them there and then — only the bcrypt hash is stored, so the plaintext is gone once you
close it. (Emailing them is not wired up yet; if they are lost, use *Forgot password* — or, when
the account has no email, an admin has to reset it.)

- Username is `first.last` lowercased, e.g. Manisha Regmi → `manisha.regmi`. A counter is
  appended when that is taken (`sujan.thapa2`), since logins resolve across all tenants.
- The account is linked back to the person via `staff.user_id` / `students.user_id`, which is
  what lets the token carry `staff_id` / `student_id` and scope the portal to them.
- The email is stored **only if it is free across all schools**. Password reset resolves users by
  email globally, so a duplicate would leave one account unrecoverable; rather than block the
  admission (siblings share a parent's address), the clash just drops the email and the person
  signs in by username. The dialog says so when that happens.

> Set `Accounts:FixedPassword` in `appsettings.json` to give every provisioned login the same
> password instead of a random one — handy for demos. Leave it empty anywhere real.

## Auth features

- **Login** — `POST /api/auth/login` (username or email + password, bcrypt-verified).
  Returns `token` (a JWT, valid 8 hours by default) alongside the user. Every other API call
  must send it as `Authorization: Bearer <token>`; the Angular app does this automatically via
  `authInterceptor`, and a 401 clears the session and bounces to `/login?expired=1`.
  Configure signing under `Jwt:*` in `appsettings.json` — **replace `Jwt:Key` outside dev.**
- **Roles** — controllers are gated by `[Authorize(Roles = …)]`: `api/super-admin/*` needs
  `super_admin`, `api/admin/*` needs `school_admin`, `api/teacher/*` and `api/student/*` need
  their own roles. A token from the wrong role gets 403, not another tenant's data.
- **Change password** — top-right user menu → *Change Password* (`POST /api/auth/change-password`)
- **Forgot password** — `/forgot-password` → generates a reset token (`POST /api/auth/forgot-password`);
  the demo returns the token on screen since there's no real inbox
- **Reset password** — `/reset-password?token=…` (`POST /api/auth/reset-password`)
