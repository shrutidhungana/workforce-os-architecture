# Module-Feature Map

This document defines the implementation scope of each module before any code exists: what it's for, what screens it needs, what API surface it exposes, what data it owns, who's allowed to touch it, and what it depends on.

**Format per module:** Purpose · Screens · API operations · Main entities · Permissions · Dependencies · Audit/Reports relationship.

This is being built one module at a time. Started with **Authentication**, since every other module depends on it to know who is calling.

---

## Authentication

### Purpose

Establishes who the caller is. Owns credential verification, session lifecycle, refresh-token rotation, and second-factor (MFA) verification. Every other module trusts the identity this module produces — it does not itself decide *what* that identity is allowed to do (that's Authorization, a separate cross-cutting concern layered on top).

### Screens

| Screen | Purpose |
|---|---|
| Login | Email + password entry; surfaces login errors without leaking account existence |
| MFA Challenge | Shown after a correct password when MFA is enabled — accepts a 6-digit TOTP code, with a "use email code instead" fallback path |
| Register | New user + tenant membership creation (self-serve signup or invited-user acceptance) |
| Forgot Password | Request a password reset email |
| Reset Password | Set a new password from a valid reset token |
| MFA Setup | Lives in Settings → Security. Displays a QR code to scan into an authenticator app, a manual entry secret, and one-time backup recovery codes |
| Session / Security (partial) | List active sessions and revoke individual or all sessions — also in Settings → Security |

Logout and "current user" are actions/state, not standalone screens.

### API Operations

| Operation | Notes |
|---|---|
| `POST /auth/register` | Creates user + tenant membership transactionally; returns safe response only (no password/hash) |
| `POST /auth/login` | Verifies credentials. If MFA is enabled, returns a short-lived `mfa_challenge_id` instead of a session; otherwise creates the session directly |
| `POST /auth/mfa/verify` | Consumes `mfa_challenge_id` + TOTP code (or email OTP code), creates the session on success |
| `POST /auth/mfa/email-otp` | Requests a one-time email code as a fallback when the authenticator device is unavailable, tied to the same `mfa_challenge_id` |
| `POST /auth/mfa/enable` | Generates a TOTP secret + QR payload; MFA is not active until the user confirms one valid code |
| `POST /auth/mfa/confirm` | Verifies the first TOTP code and activates MFA; issues backup recovery codes |
| `POST /auth/mfa/disable` | Requires current password re-entry; deactivates MFA and invalidates unused backup codes |
| `POST /auth/mfa/backup-codes/regenerate` | Invalidates old backup codes and issues a fresh set |
| `POST /auth/logout` | Revokes the current session only |
| `POST /auth/logout-all` | Revokes all sessions for the user (security action) |
| `GET /auth/me` | Returns current user context from an active session |
| `POST /auth/refresh` | Rotates session/refresh identifier; detects refresh-token reuse |
| `POST /auth/forgot-password` | Issues a time-limited reset token, delivered via Notifications |
| `POST /auth/reset-password` | Consumes reset token, sets new password, invalidates existing sessions (MFA enrollment is untouched) |
| `GET /auth/sessions` | Lists active sessions for the current user |
| `DELETE /auth/sessions/:id` | Revokes a specific session |

tRPC is used for all of the above — this is first-party, internal application traffic, not an external integration surface (per the tRPC vs. REST split in this repo's architecture strategy).

### Main Entities

| Entity | Owns |
|---|---|
| `user` | Email, password hash, account status |
| `session` | Session identifier, user reference, expiry, device/context metadata |
| `refresh_token` | Rotation chain, reuse-detection state, linked session |
| `password_reset_token` | Token hash, expiry, single-use flag |
| `mfa_credential` | TOTP secret (encrypted at rest), enabled flag, enrollment timestamp |
| `mfa_backup_code` | Hashed one-time recovery codes, used/unused flag |
| `mfa_email_otp` | Short-lived numeric code hash, expiry, attempt count, linked `mfa_challenge_id` |

`membership` (user ↔ tenant ↔ role) is created during registration but is owned by the **Users/Tenant** module, not Authentication — Authentication only needs to know a membership exists to issue a session, not to manage it.

### Permissions

Authentication is intentionally the one module with **no `auth.*` permission strings** — login, register, and logout are entry points available to anyone with valid credentials or a valid invite, not gated by role. MFA setup, challenge, and session management are all scoped to "own account only" for every role — that's an ownership check (is this your account?), not a role-permission check.

Super Admin and Tenant Admin additionally get `user.configure` / `user.create` / `user.edit` / `user.delete` (see the Users module), which covers force-revoking *another* user's sessions or requiring MFA tenant-wide via a Security setting — those are Users/Settings-module permissions, not Authentication ones. Authentication only enforces MFA once a `mfa_credential` exists for the account; whether MFA is *mandatory* for a role is a policy decision that belongs to Settings → Security (tenant-level), not to this module.

### Dependencies

| Depends on | For |
|---|---|
| **Users/Tenant module** | Membership creation on register; role/permission lookup returned in `/auth/me` and `/auth/login` |
| **Notifications module** | Delivering the password-reset email and the MFA email-OTP fallback code |
| **Redis** | Session store; rate limiting on login attempts, MFA challenge attempts, and email-OTP requests (all three need independent limits — MFA/OTP brute-force is a distinct risk from password brute-force) |

Nothing depends on Authentication for data — everything depends on it for *identity*.

### AI Capability

None. Authentication sits outside the AI tool registry entirely — no AI capability reads or writes credentials, sessions, MFA state, or tokens. The tool candidates named elsewhere in this document (`getMyLeaveBalance`, `getAssignedTasks`, `getEmployeeSummary`, `createLeaveRequest`) are all business-data operations — identity and session management stay a pure application concern the model can never touch, directly or through a tool.

### Audit / Reports Relationship

- **Generates Audit events:** yes. Login, logout, failed login, password reset requested/completed, session revoked, refresh-token reuse detected, MFA enabled/disabled, MFA challenge failed, and backup-code used are all written to the append-only Audit log (`audit_event`) — these are exactly the security-sensitive actions Audit exists to capture, per the Platform module description in [`system-architecture.md`](./system-architecture.md). MFA events in particular matter for Audit: a disabled-MFA event on an account right before suspicious activity is a classic incident-response signal.
- **Feeds Reports:** no. Authentication has no reporting surface of its own (no "login report" screen in v1) — Audit is the correct place to review this history, not Reports. This is the same Audit-vs-Reports distinction called out for other modules: Audit is security/compliance traceability, Reports is business-facing aggregation.

---

## Employees / Org

### Purpose

Owns the organization's people structure — departments, teams, manager hierarchy, and employee profiles. This is the HR-facing identity layered on top of the account Authentication creates; a `user` can exist without an `employee` record (e.g. a Super Admin has no HR profile), per [`system-architecture.md`](./system-architecture.md#platform).

### Screens

| Screen | Purpose |
|---|---|
| Employee List | Paginated, searchable, filterable (department/status) — HR/Tenant Admin view |
| Employee Detail / Edit | Full profile CRUD, including manager/department/team assignment |
| My Profile | Employee self-service — same underlying entity, restricted to safe fields only |
| Departments | Create/edit department structure |
| Teams | Create/edit teams, assign a Team Lead |

### API Operations

| Operation | Notes |
|---|---|
| `GET /employees` | Paginated list with search + department/status filters |
| `GET /employees/:id` | Single employee detail |
| `POST /employees` | Create — HR/Tenant Admin only |
| `PATCH /employees/:id` | Update — full field set for HR/Tenant Admin |
| `PATCH /employees/me` | Self-service update — server enforces a distinct, smaller field allow-list (e.g. never `salary`, `role`, `department` from this endpoint, regardless of what the client sends) |
| `DELETE /employees/:id` | Soft delete / offboard |
| `GET/POST/PATCH /departments` | Department CRUD |
| `GET/POST/PATCH /teams` | Team CRUD, including Team Lead assignment |

### Main Entities

| Entity | Owns |
|---|---|
| `employee` | Profile fields, manager reference, department/team reference, employment status |
| `department` | Name, hierarchy |
| `team` | Name, department reference, assigned Team Lead |

### Permissions

Permission strings: `employee.view` / `employee.create` / `employee.edit` / `employee.delete`.

- **Tenant Admin, HR** — full CRUD, tenant-wide
- **Team Lead** — `employee.view`, own team only
- **Employee** — `employee.view` + `employee.edit`, own profile, safe fields only (self-service update and admin update are different permission checks, not just different UI forms — the server must reject a self-service call that includes an admin-only field even if the client sends it)
- **Finance Manager, Accountant** — `employee.view`, finance-relevant fields only (e.g. salary, for payroll context)
- **Super Admin** — `employee.view`, support/audit only

### Dependencies

| Depends on | For |
|---|---|
| **Authentication** | A `user` must exist before an `employee` profile can be linked to one |
| **Documents module** | Employee document attachments (contracts, ID, etc.) |

Attendance, Leave, Projects, and Finance all read employee/team data from here rather than duplicating it — this module is a dependency *of* those, not the other way around.

### AI Capability

Read-only employee/team summaries, generated on demand — not stored, not auto-refreshed. Scope narrows by role: HR gets full-team summaries, Team Lead gets a summary scoped to their own team only, and Employee gets a summary of their own profile only, and only if self-service AI is enabled in tenant AI settings. This maps to a `getEmployeeSummary`-style read tool — it cannot edit a record; any actual profile change still goes through the normal `PATCH` endpoints above, with their own permission checks.

### Audit / Reports Relationship

- **Generates Audit events:** yes — employee create/edit/delete, and especially manager/department/team reassignment and employment-status changes, are exactly the kind of business-sensitive writes Audit exists to capture.
- **Feeds Reports:** yes — "employee count by department/status" is one of the baseline Reports summaries.

---

## Attendance

### Purpose

Owns check-in/check-out records and the state machine that prevents invalid transitions (no double check-in, no checkout without a check-in). Reads employee/team data from the Employees module rather than duplicating it, per [`system-architecture.md`](./system-architecture.md#workforce).

### Screens

| Screen | Purpose |
|---|---|
| Check In / Check Out | Employee self-service — a single action button, state-aware (shows Check In or Check Out, never both) |
| My Attendance History | Employee's own record, read-only |
| Team Attendance (HR/Team Lead) | Team- or tenant-wide view, filterable by date/employee |

### API Operations

| Operation | Notes |
|---|---|
| `POST /attendance/check-in` | Rejected server-side if an open check-in already exists for that employee/day |
| `POST /attendance/check-out` | Rejected server-side if there is no open check-in to close |
| `GET /attendance/me` | Own history |
| `GET /attendance` | HR/Team Lead — filtered by team/date/employee |

### Main Entities

| Entity | Owns |
|---|---|
| `attendance_record` | Employee reference, check-in/check-out timestamps, state |

The invalid-state prevention (no double check-in) is enforced with a DB constraint/transaction, not just UI button-disabling — the spec is explicit that this rule must hold even if two requests race.

### Permissions

Permission strings: `attendance.view` / `attendance.create` / `attendance.configure` / `attendance.approve` / `attendance.export`.

- **Employee** — `attendance.create` + `attendance.view`, own record only
- **Team Lead** — `attendance.view` + `attendance.approve`, team scope
- **HR** — `attendance.view` + `attendance.configure` + `attendance.approve` + `attendance.export`, tenant-wide
- **Tenant Admin** — `attendance.view` + `attendance.configure`, full policy/admin
- **Finance Manager, Accountant** — `attendance.view`, payroll-relevant read-only
- **Super Admin** — no access (this is tenant business data, out of platform scope)

### Dependencies

| Depends on | For |
|---|---|
| **Employees module** | Which employee/team a record belongs to |
| **Authentication** | Identity of who is checking in |

### AI Capability

None planned for v1 — no AI capability is currently assigned to Attendance for any role. If this changes later (e.g. an anomaly-detection summary over attendance patterns), it should follow the same shape as every other AI capability here: a read-only tool, gated by the `attendance.view` permission the role already holds — never a new authorization path of its own.

### Audit / Reports Relationship

- **Generates Audit events:** partially — routine check-in/check-out is high-volume and not itself an audit-worthy security event, but HR *corrections* to an attendance record (editing a past check-in/out time) should be audited, since that's a manual override of the state machine.
- **Feeds Reports:** yes — attendance summary is one of the baseline Reports.

---

## Projects / Tasks

### Purpose

Owns projects, tasks, the Kanban board, task assignment, comments, activity history, and realtime updates. Tasks and projects are kept in one module rather than split apart, since a task has no meaning without a parent project, per [`system-architecture.md`](./system-architecture.md#project-management).

### Screens

| Screen | Purpose |
|---|---|
| Project List | Tenant/team-scoped list of projects |
| Kanban Board | Drag-and-drop task board, grouped by status, with optimistic updates |
| Task Detail | Task fields, assignee, comments, activity timeline |
| Create/Edit Project | Team Lead-only project setup |

### API Operations

| Operation | Notes |
|---|---|
| `GET/POST/PATCH/DELETE /projects` | Team Lead manages own team's projects; others read-only per scope |
| `GET/POST/PATCH/DELETE /tasks` | Task CRUD, including status/assignee updates |
| `PATCH /tasks/:id/status` | Drives Kanban drag/drop — optimistic on the client, rolled back on server rejection |
| `POST /tasks/:id/comments` | Add a comment |
| `GET /tasks/:id/activity` | Domain activity timeline (status changes, reassignment, comments) |
| WebSocket channel | Authenticated, tenant/project-scoped — pushes task status/comment events to open boards |

### Main Entities

| Entity | Owns |
|---|---|
| `project` | Name, team reference, status |
| `task` | Project reference, assignee, status, priority, label |
| `comment` | Task reference, author, body |
| `activity_log` | Task reference, actor, action, timestamp — **user-facing** context, distinct from the security-focused Audit log |

### Permissions

Permission strings: `project.view` / `project.create` / `project.edit` / `project.delete`.

- **Team Lead** — full CRUD, own team's projects only
- **Employee** — `project.view` + `project.edit`, assigned tasks only (status update, not reassignment or deletion)
- **Tenant Admin** — `project.view`, full tenant visibility (oversight, not day-to-day management)
- **HR** — `project.view`, optional read
- **Finance Manager, Accountant** — `project.view`, budget/finance-relevant only, if enabled
- **Super Admin** — no access

### Dependencies

| Depends on | For |
|---|---|
| **Employees module** | Valid assignees, team scoping |
| **Authentication** | Identity for comments/activity actor |
| **Documents module** | Project-attached files |
| **Notifications module** | Task-assigned / comment-mention notifications |

### AI Capability

Project summaries, available to Team Lead only, scoped to their own team's projects — no other role has an AI capability listed for this module. This corresponds to a `getProjectSummary`-style read tool and, separately, the `getAssignedTasks` read tool named in the Oct 21 safe-tool-calling plan (an Employee-facing capability, listing a user's own assigned tasks, gated by the same `project.view` scope as the manual UI). Neither tool can move a task or change its status — Kanban drag/drop and reassignment stay manual actions unless a future, explicitly confirmed write tool is added for them.

### Audit / Reports Relationship

- **Generates Audit events:** yes, for business-significant changes — project create/delete, task reassignment across teams. Routine status drag/drop and comments write to the **domain `activity_log`** instead, which is the user-facing "what happened on this task" story — not the security/compliance Audit trail. This is a deliberate split, not an oversight: Audit answers "who did what for compliance," activity answers "what happened on this task for the team."
- **Feeds Reports:** yes — project/task status summary is a baseline Reports view.

---

## Leave

### Purpose

Owns leave types, balances, requests, and the approval workflow, keeping status and balance changes transactionally consistent (a leave request cannot move to "approved" without the corresponding balance deduction happening in the same transaction).

### Screens

| Screen | Purpose |
|---|---|
| My Leave | Employee's own request form + history + status |
| Approval Queue | Team Lead / HR — pending requests awaiting their decision |

### API Operations

| Operation | Notes |
|---|---|
| `GET /leave/types` | Tenant-configured leave types |
| `GET /leave/balance` | Own current balance, by type |
| `POST /leave/requests` | Submit a request — validated against remaining balance |
| `GET /leave/requests/me` | Own request history |
| `GET /leave/requests` | Team Lead/HR — pending/all requests in scope |
| `POST /leave/requests/:id/approve` | Updates status + deducts balance transactionally |
| `POST /leave/requests/:id/reject` | Updates status, no balance change |

### Main Entities

| Entity | Owns |
|---|---|
| `leave_type` | Name, accrual rule, tenant reference |
| `leave_balance` | Employee reference, leave type, remaining amount |
| `leave_request` | Employee reference, dates, type, status |
| `approval_history` | Request reference, actor, decision, timestamp |

### Permissions

Permission strings: `leave.view` / `leave.create` / `leave.configure` / `leave.approve`.

- **Employee** — `leave.create` + `leave.view`, own requests/history only
- **Team Lead** — `leave.view` + `leave.approve`, team scope
- **HR** — `leave.view` + `leave.configure` + `leave.approve`, tenant-wide policy and approvals
- **Tenant Admin** — `leave.view` + `leave.configure`, full policy/admin
- **Finance Manager, Accountant** — `leave.view`, payroll-relevant read-only
- **Super Admin** — no access

### Dependencies

| Depends on | For |
|---|---|
| **Employees module** | Who's requesting, team scoping for approvals |
| **Notifications module** | Request-submitted / approved / rejected notifications |

### AI Capability

Leave balance is surfaced inline in the approval flow (HR, Team Lead) and on the Employee's own leave screen — a `getMyLeaveBalance`-style read tool, named explicitly in the Oct 21 safe-tool-calling plan. That same plan names `createLeaveRequest` as the one AI **write** tool for this module: the model can propose a leave request, but the server re-validates the current user/tenant/permission and requires explicit user confirmation before the mutation runs — same authorization path as a manually submitted request, plus one extra confirmation step, and the same Audit write either way.

### Audit / Reports Relationship

- **Generates Audit events:** yes — request submitted, approved, rejected, and any manual balance adjustment are all audit-worthy (approval authority and balance correctness are exactly the kind of thing Audit needs to make reviewable).
- **Feeds Reports:** yes — leave summary (by type/team/status) is a baseline Reports view.

### Open Question (carried over from `system-architecture.md`)

The approval chain is not yet finalized — **single-step** (Team Lead *or* HR approves) vs. **sequential** (Team Lead approves, then HR) is still undecided. This affects the `leave_request` status enum and the `approval_history` shape, so it should be settled before the Sep 26 implementation day (Leave balances and approval workflow) rather than mid-build.

---

## Finance

### Purpose

Owns finance settings and a deliberately small expense/invoice submit-record-approve workflow, plus bounded payroll: a fixed salary field per employee, a manually triggered monthly payroll run that snapshots salary into payslip records, and a single Finance Manager sign-off. This module stays a record-keeping/reporting feature, not an accounting system.

**Explicitly out of scope** (the Lightweight Payroll Scope this project committed to) — worth restating here so the boundary doesn't drift mid-build:
- Tax/deduction calculation engines
- Multi-currency or multi-country compliance rules
- Bank/payment gateway integration or actual money movement
- Benefits, bonuses, reimbursement workflows
- Payroll approval chains beyond a single Finance Manager sign-off

### Screens

| Screen | Purpose |
|---|---|
| Finance Settings | Finance Manager — expense categories, payroll cadence, sign-off rule |
| Submit Expense/Invoice | Employee submits their own; Accountant records on behalf of the business |
| Approval Queue | Finance Manager — approve/reject submitted expenses/invoices |
| Trigger Payroll Run | Finance Manager — manual trigger, single confirmation step, no multi-stage chain |
| Payroll Run History/Status | Finance Manager (full), Accountant (view-only) |
| My Payslips | Employee — read-only, one record per completed payroll run |

### API Operations

| Operation | Notes |
|---|---|
| `GET/PATCH /finance/settings` | Finance Manager only |
| `POST /finance/expenses` | Employee (own), Accountant (on behalf of the business) — a single `expense` entity with a `type` field covers both expense and invoice, kept intentionally small rather than two parallel schemas |
| `GET /finance/expenses` | Own (Employee) or full approval-scope (Finance Manager, Accountant) |
| `POST /finance/expenses/:id/approve` / `/reject` | Finance Manager only |
| `POST /finance/payroll-runs` | Finance Manager — triggers the run, requires explicit sign-off confirmation in the same request |
| `GET /finance/payroll-runs` / `/:id` | Finance Manager (full), Accountant (status/history, read-only) |
| `GET /finance/payslips/me` | Employee — own payslips only, never editable once generated |

### Main Entities

| Entity | Owns |
|---|---|
| `finance_settings` | Tenant-scoped config: categories, payroll cadence |
| `expense` | Type (expense/invoice), amount, submitter, status |
| `payroll_run` | Triggered-by, run date, status, sign-off timestamp |
| `payslip` | Employee reference, payroll-run reference, salary snapshot, generated-at — immutable once created |

`salary` itself is **not** owned here — it lives on the `employee` entity (Employees/Org module); Finance only reads it at payroll-run time to snapshot into a payslip. This keeps salary-as-a-field and payroll-as-a-process as two separate concerns with two separate permission checks.

### Permissions

Permission strings: `finance.view` / `finance.create` / `finance.edit` / `finance.configure` / `finance.approve` / `finance.export`.

- **Finance Manager** — `finance.configure` + `finance.approve` + `finance.export`: settings, payroll trigger + sign-off, expense/invoice approvals, reports
- **Accountant** — `finance.create` + `finance.edit`: record/reconcile/report; `finance.view`: payroll run status/history — cannot trigger or approve
- **Employee** — `finance.create`: submit expense, if enabled; `finance.view`: own payslip, read-only only
- **Tenant Admin** — `finance.view` + `finance.configure`: full tenant setup/admin, not day-to-day processing
- **HR, Team Lead** — `finance.view`, limited (headcount cost / budget context only)
- **Super Admin** — no access

### Dependencies

| Depends on | For |
|---|---|
| **Employees/Org module** | Reads the `salary` field it owns, for payroll snapshotting |
| **Notifications module** | Payroll-run-completed, expense approved/rejected notifications |

### AI Capability

Finance Manager gets finance insight summaries, explicitly bounded to synthetic/demo data — no live financial-analysis engine, matching this project's cost and scope guardrails. Accountant gets finance extraction/search — pulling structured fields out of invoice/receipt documents, via the Documents module's AI extraction pipeline rather than a Finance-owned model. Neither capability can trigger a payroll run or approve a transaction — AI in Finance is read/summarize only, following the same "AI never grants more access than the role already has" rule as every other module.

### Audit / Reports Relationship

- **Generates Audit events:** yes. Payroll-run triggered/signed-off, and expense/invoice approved/rejected, are among the highest-stakes writes in the whole system — a payroll run produces real payslip records, so it should never be a silent write.
- **Feeds Reports:** yes — a finance/cost summary is a baseline Reports view. Payroll run history itself stays a Finance-module screen, not duplicated into Reports.

---

## Users / Roles / Permissions

### Purpose

Owns user accounts, tenant membership, and role/permission assignment — kept separate from HR/Employee data (a `user` can exist without an `employee` record; a Super Admin has none). This module owns the tables (`role`, `permission`, `role_permission`, `membership`) that the Authorization layer reads from on every request. Authorization itself is **not** a module with its own screens — it's a cross-cutting guard enforced inside every other module, per [`system-architecture.md`](./system-architecture.md#platform).

### Screens

| Screen | Purpose |
|---|---|
| Members List | Tenant Admin (all members); HR/Finance Manager/Accountant scoped to the users they're allowed to create/edit |
| Invite User | Email + role assignment; creates a pending membership |
| Edit User Role | Reassign a member's role |
| My Access | Employee — read-only view of their own role and permission set |

### API Operations

| Operation | Notes |
|---|---|
| `GET /users` | Tenant-scoped; HR/Finance Manager/Accountant see only the role-scoped subset they can manage |
| `POST /users/invite` | Creates a pending `membership`; delivery via Notifications |
| `PATCH /users/:id/role` | Reassign role — the seven roles are fixed and seeded, not tenant-creatable in v1 |
| `DELETE /users/:id` | Revokes the membership/access; does not delete an underlying `employee` record if one exists — offboarding an employee and revoking system access are related but distinct actions |
| `GET /users/me/permissions` | Resolves the current user's permission set — this is what `/auth/me` (Authentication module) consumes to build the login response |

### Main Entities

| Entity | Owns |
|---|---|
| `membership` | User × tenant × role join |
| `role` | The 7 fixed roles |
| `permission` | Seeded granular permission strings (`employee.create`, `leave.approve`, etc.) |
| `role_permission` | Join table — the seed data that makes roles "bundles of permissions" rather than hardcoded checks |

### Permissions

Permission strings: `user.view` / `user.create` / `user.edit` / `user.delete` / `user.configure`.

- **Super Admin** — `user.configure`, platform policy only (does not manage individual tenant members)
- **Tenant Admin** — `user.view` + `user.create` + `user.edit` + `user.delete`, full, own tenant
- **HR** — `user.create` + `user.edit`, HR-role users only
- **Team Lead** — `user.view`, team membership only
- **Finance Manager, Accountant** — `user.create` + `user.edit`, finance-role users only
- **Employee** — `user.view`, own access only

### Dependencies

| Depends on | For |
|---|---|
| **Authentication** | Every session issued depends on a `membership` this module owns already existing |
| **Notifications module** | Invite emails |

Authentication *consumes* what this module produces (membership → session); it does not own membership itself.

### AI Capability

None. Role and permission management is deliberately kept outside the AI tool registry — it doesn't appear among the tool candidates named elsewhere in this document (`getProjectSummary`, `getEmployeeSummary`, `searchDocuments`, `getLeaveBalance`), and shouldn't be added without a strong reason. Letting AI *read* who-has-what-role is low-risk; letting AI *change* a role is a fundamentally different class of risk than summarizing a project, since it's a direct authorization-path change — that stays a manual, permissioned action only.

### Audit / Reports Relationship

- **Generates Audit events:** yes — this is the first example given in [`system-architecture.md`](./system-architecture.md#platform)'s own description of the Audit module ("role changes" is named explicitly). User invited, role changed, and access revoked all write to Audit.
- **Feeds Reports:** no dedicated Reports view in v1 — Audit is the correct place to review this history today. A "seats used" report could be added later without changing this module's ownership.

---

## AI

### Purpose

Owns the AI provider adapter (interface-first, so the vendor — Gemini today — can be swapped without touching business logic), the tenant AI settings gate, the usage/cost ledger, the RAG pipeline, and the tool-calling registry. It holds none of the other modules' core data itself — it only reaches other modules through registered tools, so the model can never see or touch more than a tool explicitly exposes, per [`system-architecture.md`](./system-architecture.md#ai). AI is deliberately not "just a chatbot" here — every capability above is scoped, structured, and attached to an existing module rather than living in a standalone AI screen.

### Screens

| Screen | Purpose |
|---|---|
| AI Settings | Tenant Admin — enable/disable features per capability, request caps, document-AI and tool-action toggles |
| AI Usage / Cost Ledger | Tenant Admin (tenant-scoped), Super Admin (platform-scoped) — tenant/user/feature/model/cost breakdown |
| Inline AI surfaces | Embedded inside other modules' own screens — the summary panel on Employee/Project pages, the RAG ask-a-question box (Documents), the tool-call confirmation dialog — not a standalone chat screen |

### API Operations

| Operation | Notes |
|---|---|
| `AIProvider.generate` / `.embed` | Internal only — never exposed directly to the client; every client-facing call goes through a feature-specific endpoint below |
| `POST /ai/summary/:module/:id` | Structured summary; output validated with Zod before it's returned |
| `POST /ai/documents/extract` | Structured extraction from an uploaded document |
| `POST /ai/rag/ask` | Embeds the question, retrieves tenant-scoped top-k chunks, generates a sourced answer |
| `POST /ai/tools/propose` | Model selects a tool + args from the registry — nothing executes yet |
| `POST /ai/tools/confirm` | Required before any write tool executes; server **re-checks** user/tenant/permission at this step, not just at propose time |
| `GET /ai/usage` | Tenant's own usage ledger |

### Main Entities

| Entity | Owns |
|---|---|
| `ai_settings` | Tenant-scoped feature toggles, request cap |
| `ai_usage_ledger` | Tenant, user, feature, model, token/cost metadata — per request |
| `document_chunk` | Tenant/document reference, chunk text, embedding vector, content hash — lives in PostgreSQL + pgvector (no separate paid vector database) |
| `tool_invocation` | Which tool, args, confirmed-by, result — mirrored into Audit rather than kept as a separate silo |

### Permissions

Permission strings: `ai.view` / `ai.configure`.

- **Super Admin** — `ai.configure`, platform-wide model/cost policy
- **Tenant Admin** — `ai.configure`, enable features, caps, provider settings
- **HR** — `ai.view`, HR summaries/search
- **Team Lead** — `ai.view`, project summaries
- **Finance Manager** — `ai.view`, finance analysis, if enabled
- **Accountant** — `ai.view`, finance extraction/search
- **Employee** — `ai.view`, allowed self-service AI only

The permission check happens **twice** for anything AI touches: once to gate the AI feature itself (`ai.view` / `ai.configure`), and again inside the tool against the *underlying module's* permission (e.g. an employee-summary tool still enforces `employee.view` scope). `ai.view` alone is never sufficient to read data a role couldn't already see manually — this is the same rule stated in every module's AI Capability section above, just centralized here.

### Dependencies

| Depends on | For |
|---|---|
| **Every module with a registered read tool** (Employees, Projects, Leave, Documents) | AI is a consumer of their service layer, same as any other caller — never a special-cased direct-DB path |
| **Documents module** | Source content for RAG and extraction |
| **Audit** | Every tool proposal, confirmation, and execution is recorded here |
| **External Gemini provider** | Behind the `AIProvider` interface — swappable |
| **PostgreSQL + pgvector** | Vector storage — no separate paid vector database |

### Audit / Reports Relationship

- **Generates Audit events:** yes, exhaustively — every tool proposal, confirmation, and execution (read or write) is logged. This is the mechanism that makes "AI never has unrestricted database access" verifiable after the fact, rather than just asserted in a doc.
- **Feeds Reports:** no — the usage/cost ledger is this module's own operational view, closer to a billing/ops screen than a Reports-module business KPI. It is not duplicated into the Reports module.

---

## Tenant

### Purpose

Owns the tenant/organization entity itself — the top-level record every other module's data is scoped by via `tenant_id`, which is the foundation of the multi-tenant isolation model. Covers tenant lifecycle: creation, activation, suspension. This is deliberately distinct from the **Settings** module below: Tenant owns *what the organization is* (its identity and lifecycle state); Settings owns *how it's configured to behave*.

### Screens

| Screen | Purpose |
|---|---|
| Platform Tenants | Super Admin — list every tenant on the platform, activate/suspend |
| Create Tenant | Super Admin — manual onboarding path |
| Organization Profile | Tenant Admin — own tenant's name/slug; activation/suspension status shown read-only, not editable here |

### API Operations

| Operation | Notes |
|---|---|
| `GET /tenants` | Super Admin, platform-wide |
| `POST /tenants` | Super Admin — manual tenant creation |
| `PATCH /tenants/:id/activate` / `/suspend` | Super Admin only — never delegated to Tenant Admin |
| `GET /tenants/me` | Tenant Admin — own tenant record |
| `PATCH /tenants/me` | Tenant Admin — name/slug only |

### Main Entities

| Entity | Owns |
|---|---|
| `tenant` | Name, slug, status (active/suspended), created-at |

### Permissions

Permission strings: `tenant.view` / `tenant.create` / `tenant.delete` / `tenant.configure`.

- **Super Admin** — `tenant.create` + `tenant.delete` (suspend) + `tenant.configure`, platform-wide
- **Tenant Admin** — `tenant.view` + `tenant.configure`, own tenant only
- **HR, Team Lead, Finance Manager, Employee, Accountant** — no access

### Dependencies

Every tenant-owned entity across every other module carries this module's `tenant_id` — that makes Tenant the one implicit dependency of literally everything else in the system, not just the modules listed elsewhere as explicit dependencies. It's called out once here rather than repeated in every module's Dependencies table above, to avoid restating the same row thirteen times.

### AI Capability

None. No AI capability is assigned to this module for any role. Tenant lifecycle actions (create, suspend) are exactly the kind of irreversible, platform-wide action that should never be reachable via a tool — confirmed or not.

### Audit / Reports Relationship

- **Generates Audit events:** yes, top priority — tenant activation/suspension is the first example named in the Audit module's own description elsewhere in this repo's architecture notes.
- **Feeds Reports:** platform-wide reporting for Super Admin exists as a concept but its exact content isn't specified yet — worth resolving before the Reports module is built out, since "platform reports" today is a placeholder more than a defined screen.

### Open Question

Does self-serve signup exist — a new registrant creating a brand-new tenant and becoming its first Tenant Admin — or is every tenant created only by Super Admin / invite-only? Authentication's registration flow ("create user + membership transactionally") doesn't currently specify which. This determines whether `POST /tenants` needs a public, unauthenticated path reachable from the Register screen, or stays a Super-Admin-only internal action. Worth settling before Authentication's registration flow is implemented, since it changes what that endpoint needs to do.

---

## Settings

### Purpose

Owns the six typed, per-tenant configuration groups — General, Security, Notifications, HR, Finance, AI — each independently permissioned, plus per-user preferences layered on top of tenant defaults. Distinct from the **Tenant** module above: Settings owns *how* a tenant is configured to behave, not the tenant record itself.

### Screens

| Screen | Purpose |
|---|---|
| Settings | Tabbed by group (General/Security/Notifications/HR/Finance/AI) — each tab visible only to roles permitted to configure it |
| My Preferences | Self-service, per-user overrides (e.g. notification channel opt-in, timezone) — distinct from tenant-wide defaults |

### API Operations

| Operation | Notes |
|---|---|
| `GET/PATCH /settings/:group` | `group` is one of `general \| security \| notifications \| hr \| finance \| ai`; permission checked per group, not just per module |
| `GET/PATCH /settings/me` | Per-user preference overrides |

### Main Entities

| Entity | Owns |
|---|---|
| `settings` | Tenant-scoped, one row per group, Zod-validated against a typed schema per group |
| `user_preference` | Per-user overrides, where a setting has a personal layer on top of the tenant default |

### Permissions

Permission strings: `settings.view` / `settings.edit` / `settings.configure`, scoped per group.

- **Super Admin** — `settings.configure`, platform defaults only
- **Tenant Admin** — `settings.configure`, General/Security/Notification/AI
- **HR** — `settings.configure`, HR/leave/attendance
- **Finance Manager** — `settings.configure`, finance/payroll/expense
- **Team Lead** — `settings.edit`, team/project preferences
- **Accountant** — `settings.edit`, accounting preferences
- **Employee** — `settings.edit`, own preferences only

The Finance settings group is a good example of the module split in practice: the Finance module's own "Finance Settings" screen documented above **is** this module's `finance` group, surfaced inside Finance's UI for a better workflow — the underlying data, validation, and per-group permission model still live here in Settings, not duplicated into Finance.

### Dependencies

| Depends on | For |
|---|---|
| **Tenant module** | Every settings row is scoped by `tenant_id` |

Every module that gates its own behavior on a setting (Finance reads the `finance` group, AI reads the `ai` group, Notifications reads the `notifications` group) depends *on* Settings — Settings does not depend on them.

### AI Capability

None directly. The AI module's own settings tab is Tenant Admin *configuring* AI, not AI acting on Settings. Worth stating explicitly: AI is never permitted to change a tenant's settings on its own initiative. The "propose, then confirm" write-tool pattern used elsewhere doesn't even apply here — settings changes simply aren't in the tool registry at all.

### Audit / Reports Relationship

- **Generates Audit events:** yes — every settings change, per group, is audit-worthy. Security and Finance groups matter most here, since a misconfiguration in either is a real security/compliance risk, not just a cosmetic preference change.
- **Feeds Reports:** no. Settings represent current-state configuration, not something aggregated or trended over time in v1.

---

## Documents

### Purpose

Owns file uploads, document metadata, and secure tenant-scoped access. Binary content lives in S3 (or a local/dev equivalent) behind a storage adapter interface; only metadata lives in the database. Also the substrate that other modules' document attachments live on top of (employee docs, project docs, finance docs) and the source content the AI module's RAG/extraction pipeline reads.

### Screens

| Screen | Purpose |
|---|---|
| Upload | Contextual — embedded wherever a document attaches (Employee profile, Project, Finance), not a standalone "Documents" app |
| Document List | Scoped by owning entity — employee docs under Employees, project docs under Projects, finance docs under Finance |
| Document Detail / Preview | View metadata, download (authorized only) |

### API Operations

| Operation | Notes |
|---|---|
| `POST /documents` | Upload — validates size/type server-side, stores metadata + binary via the storage adapter |
| `GET /documents/:id` | Download — authorized only; cross-tenant/cross-owner access is denied, not just hidden |
| `GET /documents?ownerType=&ownerId=` | List scoped to an owning entity (an employee, a project, a finance record) |
| `DELETE /documents/:id` | Owner or admin-scope only |

### Main Entities

| Entity | Owns |
|---|---|
| `document` | Tenant reference, owner type/id (employee/project/finance), uploader, file metadata (name/size/mime), storage key |

### Permissions

- **Tenant Admin** — View, tenant-wide
- **HR** — View, employee docs
- **Team Lead** — View, project docs
- **Finance Manager, Accountant** — View, finance docs
- **Employee** — View + Create, own/allowed docs only
- **Super Admin** — no access

A document's visibility is always inherited from its **owning entity's** permission, not a separate Documents-specific rule — if a role can't view a given employee's profile, it can't view that employee's documents either, regardless of any Documents-level grant.

### Dependencies

| Depends on | For |
|---|---|
| **Storage adapter (S3 / local-dev)** | Binary file storage — business code depends on the interface, not the S3 SDK directly, so the backing store can be swapped without touching this module's logic |
| **Employees / Projects / Finance modules** | The owning entity a document is attached to — Documents doesn't own the business context, only the file + metadata |

### AI Capability

Documents itself has no independent AI capability — it's the *source*, not the actor. Every other module's document-related AI capability (HR's employee-doc search, Team Lead's project-doc search, Finance/Accountant's finance-doc search and extraction, Employee's self-service search) reads through Documents' storage and metadata, scoped by whatever permission that role already holds on the *owning* entity — a role can never search documents attached to something it couldn't otherwise view.

### Audit / Reports Relationship

- **Generates Audit events:** yes — upload, download, and delete are all audit-worthy, especially a denied cross-tenant/cross-owner access attempt.
- **Feeds Reports:** no dedicated Reports view currently — document count or storage usage isn't in the baseline Reports scope, though it could be added later without changing this module's ownership.

---

## Notifications

### Purpose

Sends and stores in-app, email, and push notifications triggered by other modules — leave approved, task assigned, payroll run completed, password reset, MFA email-OTP, user invited. This is the first module planned for extraction into its own service, because delivery is asynchronous, safely retryable, and can fail without breaking the request that triggered it.

### Screens

| Screen | Purpose |
|---|---|
| Notification Center | In-app bell/list, every role — own notifications only |

Per-channel opt-in preferences (email vs. push vs. in-app) live in the **Settings** module's `notifications` group, not here — same split pattern as Tenant/Settings and Finance/Settings: Notifications owns *delivery*, Settings owns the *preference* that controls it.

### API Operations

| Operation | Notes |
|---|---|
| `GET /notifications/me` | Own notification list |
| `PATCH /notifications/:id/read` | Mark read |
| `enqueueNotification(job)` | Internal only — called from other modules' services, never a public HTTP endpoint. This is the boundary that keeps a slow/failing notification from blocking the request that triggered it |

### Main Entities

| Entity | Owns |
|---|---|
| `notification` | Tenant, recipient, type, payload, read status, created-at |
| `notification_job` | Queue job wrapper — delivery status, retry count, provider used |

### Permissions

Every role can view/manage only their own notifications — this is an ownership check (is this addressed to me?), not a role-permission check, the same pattern as Authentication's session management.

### Dependencies

| Depends on | For |
|---|---|
| **Every module that triggers a notification** (Authentication, Leave, Finance, Projects, Users/Roles/Permissions) | Notifications is a downstream consumer of their events, called via enqueue rather than a direct write |
| **Redis / job queue** | Async delivery, retry/backoff |
| **Email provider, Push provider** (external) | Actual delivery |

### AI Capability

None. Notification content is templated from the triggering event, not generated or summarized by AI — worth stating explicitly since it's an easy thing to assume incorrectly.

### Audit / Reports Relationship

- **Generates Audit events:** no, deliberately — this is the first module in this document where the answer is no on both counts, and it's worth explaining why: the *action that triggered* the notification (a leave approved, a payroll run completed) is what gets audited, by the module that owns that action. Notifications is a delivery mechanism, not a business action in itself; a delivery failure after max retries is an operational/observability concern (structured logs, alerting), not a security Audit event.
- **Feeds Reports:** no, for the same reason.

---

## Audit

### Purpose

Maintains the append-only log of sensitive actions across every other module — role changes, payroll runs, tenant activation, login/MFA events, leave approvals, document access, and every AI tool invocation. Written to exclusively through a single `AuditService.record()` call from other modules' services; it exposes no update or delete path anywhere in its API surface, by design.

### Screens

| Screen | Purpose |
|---|---|
| Audit Log | Role-scoped list — Super Admin sees platform-wide, Tenant Admin sees tenant-wide, HR/Team Lead/Finance Manager/Accountant see their own domain, Employee sees only their own activity |
| Event Detail | Single `audit_event` drill-down |

Filters: actor, action, entity, date range.

### API Operations

| Operation | Notes |
|---|---|
| `GET /audit/events` | Filtered, paginated; scope enforced server-side per role, not client-side filtering of a full result set |
| `GET /audit/events/:id` | Single event detail |
| `GET /audit/events/export` | CSV export, `audit.export` only |
| `AuditService.record(event)` | Internal only — the sole write path; not reachable as a public endpoint from any client |

### Main Entities

| Entity | Owns |
|---|---|
| `audit_event` | Tenant, actor, action, entity type/id, request/correlation ID, metadata, timestamp — append-only; there is no update or delete column or endpoint at all |

### Permissions

- **Super Admin** — View + Export, platform-wide
- **Tenant Admin** — View + Export, tenant-wide
- **HR, Team Lead, Finance Manager, Accountant** — View, domain-scoped (HR sees HR-relevant events, Finance Manager sees finance-relevant events, etc.)
- **Employee** — View, own activity only

### Dependencies

Every other module writes into Audit through `AuditService` — Audit depends on nothing from other modules' data models, it only receives calls. This makes Audit a **sink**: everything points into it; it points out to nothing but its own storage.

### AI Capability

Read-side only, and indirect: every other module's AI Capability section in this document already states that AI tool invocations get logged here — Audit is where that claim is *verified*, not where AI does anything. No AI capability currently reads or summarizes Audit data itself (an "audit anomaly summary" is a plausible future capability, flagged here as a candidate rather than assumed into scope).

### Audit / Reports Relationship

- **Generates Audit events:** not in the recursive sense — Audit doesn't audit its own writes. Whether *viewing/exporting* audit data should itself produce a meta-audit-event is an open design question, not yet decided.
- **Feeds Reports:** no. Audit and Reports are deliberately separate: Audit is compliance traceability, Reports is business aggregation. Reports never reads from `audit_event` directly.

---

## Reports

### Purpose

Owns role-scoped, **deterministic** (not AI-generated) read models across employee/attendance/leave/project/finance data — dashboards, filters, CSV export, cached aggregates. Explicitly distinct from both Audit (security/compliance trail) and AI-generated summaries (interpretive, not deterministic aggregation) — a Reports number should always be independently reproducible from the underlying tables.

### Screens

| Screen | Purpose |
|---|---|
| Reports Dashboard | Role-scoped cards/tables: employee count by department/status, attendance summary, leave summary, project/task status summary, finance summary |
| Report Detail / Filter | Date range, team, status filters — sharable via URL |

### API Operations

| Operation | Notes |
|---|---|
| `GET /reports/:type` | `type` is one of `employee \| attendance \| leave \| project \| finance`; role-scoped |
| `GET /reports/:type/export` | CSV, requires `report.export` |

### Main Entities

Reports doesn't own tables of its own in the usual sense — it's a read layer over other modules' data (`employee`, `attendance_record`, `leave_request`, `task`, `expense`, etc.), plus one cached aggregate entry per expensive query (Redis, TTL-bound, invalidated on the relevant underlying write).

### Permissions

- **Super Admin** — View + Export, platform-wide
- **Tenant Admin** — View + Export, tenant-wide
- **HR, Team Lead, Finance Manager, Accountant** — View + Export, domain-scoped
- **Employee** — View, own summaries only — no export

### Dependencies

| Depends on | For |
|---|---|
| **Every module documented above with "Feeds Reports: yes"** (Employees/Org, Attendance, Projects/Tasks, Leave, Finance) | Reports reads from each through its service layer — the same module-boundary rule as everywhere else in this monolith, never a raw cross-module table query |
| **Redis** | The one cached expensive aggregate |

### AI Capability

None directly — Reports is explicitly the deterministic counterpart to AI's generated summaries. A future "AI insight layered on top of a report" capability would live in the AI module reading Reports' output, not inside Reports itself — keeping the deterministic/generative line intact rather than blurring it.

### Audit / Reports Relationship

- **Generates Audit events:** only for `report.export` — a CSV export is a data-egress action worth logging, the same way Audit's own export is. Routine report *viewing* is not logged, to avoid drowning Audit in high-volume read noise.
- **Feeds Reports:** N/A — this is the Reports module itself.

---

## Mobile App

### Purpose

Not a backend module with its own tables — a React Native/Expo client consuming the same APIs as web, with no separate backend or business database. Covers login, dashboard, attendance, leave, assigned tasks, notifications, and a bounded subset of AI features. Every backend module documented above already governs mobile's actual data and permission behavior; this entry documents mobile as a **client surface**, not a new authorization domain.

### Screens

| Screen | Purpose |
|---|---|
| Login | Same Authentication flow as web, including MFA challenge |
| Dashboard | Today's attendance state, leave summary, assigned task count |
| Check In / Check Out | Same Attendance module underneath |
| My Leave | Request + history — no HR/Team Lead approval UI on mobile in v1 |
| Assigned Tasks | List + detail + status update — no mobile Kanban |
| Notifications | Push + in-app list |

### API Operations

None of its own — mobile calls the exact same endpoints already documented under Authentication, Attendance, Leave, Projects/Tasks, and Notifications above. The one mobile-specific addition:

| Operation | Notes |
|---|---|
| `POST /notifications/push-tokens` | Register a device push token (owned by the Notifications module) |

### Main Entities

None owned by Mobile itself — only the device push token (owned by Notifications) and whatever is cached locally for offline read convenience, which is never synced back or treated as authoritative.

### Permissions

Whatever the authenticated user's role already grants server-side — mobile enforces nothing the backend doesn't already enforce. Hiding an approval screen on mobile is a UX scoping choice, not a security boundary. Employee gets primary self-service (View/Create/Edit); every other role gets an optional, view-only summary, if enabled at all.

### Dependencies

| Depends on | For |
|---|---|
| **Authentication, Attendance, Leave, Projects/Tasks, Notifications** | Every endpoint mobile actually calls — mobile has no dependency of its own that the backend doesn't already have |

### AI Capability

None initially. Employee is the intended candidate for a future mobile AI entry point (self-service summary/search), but it isn't built in v1. When added, it should follow the same read-only, permission-gated shape every AI capability in this document already follows.

### Audit / Reports Relationship

Not a separate category for Mobile — a mobile action is audited/reported through whichever backend module's endpoint it actually called (a mobile check-in is an **Attendance**-module audit event, not a distinct "mobile audit event"). Worth stating explicitly so Mobile is never mistaken for a parallel audit or reporting surface.

---

*All 15 modules from the module-feature-map spec are now documented: Authentication, Employees/Org, Attendance, Projects/Tasks, Leave, Finance, Users/Roles/Permissions, AI, Tenant, Settings, Documents, Notifications, Audit, Reports, Mobile App.*


