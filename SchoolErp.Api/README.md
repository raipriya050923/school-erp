# SchoolErp — Super Admin API (.NET 8, Clean Architecture, ADO.NET + MySQL)

A REST API backing the Super Admin panel of the School ERP. Built with **Clean
Architecture** and **raw ADO.NET** (MySqlConnector — no Entity Framework) against
**MySQL**.

## Architecture

```
src/
├── SchoolErp.Domain          → Entities only. No dependencies.
├── SchoolErp.Application      → DTOs, interfaces (I*Repository, I*Service),
│                                business-logic services. Depends on Domain.
├── SchoolErp.Infrastructure   → ADO.NET repositories, MySqlConnectionFactory,
│                                DbHelper, notification sender. Depends on Application.
└── SchoolErp.Api              → Controllers, middleware, Program.cs (composition root).
                                 Depends on Application + Infrastructure.
```

Dependency rule points inward: **Domain ← Application ← Infrastructure / Api**.
The Application layer knows nothing about MySQL — it depends only on the
`I*Repository` interfaces, which Infrastructure implements with ADO.NET.

## Data access (ADO.NET, no EF)

- `MySqlConnectionFactory` opens `MySqlConnection`s from the `MySql` connection string.
- `DbHelper` wraps `MySqlCommand` / `IDataReader` with small helpers; **every value is
  passed as a parameter** (`@name`) — no string concatenation of user input.
- Each repository maps `IDataRecord` rows to Domain entities by hand.

## Endpoints (base: `/api/super-admin`)

| Area | Method & route |
|------|----------------|
| Dashboard | `GET /dashboard/stats` |
| Schools | `GET /schools` · `GET /schools/{id}` · `POST /schools` · `PUT /schools/{id}` · `PATCH /schools/{id}/status` |
| Plans | `GET /plans` · `GET /plans/{id}` · `POST /plans` · `PUT /plans/{id}` · `PATCH /plans/{id}/active?value=` |
| Subscriptions | `GET /subscriptions?status=&planId=` |
| Billing | `GET /billing/invoices?status=` · `GET /billing/summary` · `POST /billing/invoices/{id}/payments` · `POST /billing/invoices/{id}/reminder` |
| Tickets | `GET /tickets?status=` · `GET /tickets/{id}` · `PATCH /tickets/{id}/status` · `POST /tickets/{id}/resolve` · `POST /tickets/{id}/comments` |

## Setup

1. **Database** — create the schema, then apply the API migration:
   ```bash
   mysql -u root -p < ../database/school_erp_schema.sql
   mysql -u root -p < db/migrations/001_superadmin_api_columns.sql
   ```
2. **Connection string** — edit `src/SchoolErp.Api/appsettings.json`
   (`ConnectionStrings:MySql`) to match your MySQL credentials.
3. **Run**:
   ```bash
   dotnet run --project src/SchoolErp.Api
   ```
   Swagger UI is served at `/swagger` in Development. CORS is pre-configured for the
   Angular client at `http://localhost:4200`.

## Notes

- Errors are normalised by `ExceptionHandlingMiddleware`: `ValidationException` → 400,
  `NotFoundException` → 404, everything else → 500, all as `{ error, message }` JSON.
- `INotificationSender` is stubbed by `LoggingNotificationSender` (logs the email);
  swap it for an SMTP/SendGrid implementation without touching the Application layer.
- The acting user id for ticket actions is hard-coded to `1` in the controller — wire
  it to the authenticated user once auth/JWT is added.
