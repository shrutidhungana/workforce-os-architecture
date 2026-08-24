# Feature-Role Matrix

**Governing rule:** UI visibility is not authorization. Server permissions remain authoritative. Every access decision below must be enforced server-side, never assumed from a hidden UI element.

**Roles (7):** Super Admin, Tenant Admin, HR, Team Lead, Finance Manager, Employee, Accountant

**Modules (13):** Tenant/Platform, Users/Roles/Permissions, Settings, Employees/Org, Projects/Tasks, Attendance, Leave, Finance, Documents, AI, Audit, Reports, Mobile App

**Access verbs:** View, Create, Edit, Delete, Approve, Configure, Export
Permission strings follow `module.verb` (e.g. `employee.create`, `leave.approve`, `report.export`, `audit.view`, `ai.view`).

Mobile is a **module** (a client surface), never a role — it is listed as its own row, not folded into another module or treated as an 8th role.

---

## 1. Role and Access

High-level access boundary for each role — before drilling into individual modules, this defines *how far* each role's access reaches.

| Role | Access boundary | Scope | One-line description |
|---|---|---|---|
| **Super Admin** | Platform-wide | Across all tenants | Operates the platform itself — tenant lifecycle and platform policy. No access to any tenant's business data. |
| **Tenant Admin** | Tenant-wide | Single tenant, full depth | The tenant's owner account — full CRUD/Configure across every module within their own tenant. |
| **HR** | Tenant-wide, domain-limited | Single tenant, workforce domain | Full authority over people/workforce modules (Employees, Attendance, Leave); limited elsewhere. |
| **Team Lead** | Team-scoped | Own team only | Operational authority restricted to their own team's projects, attendance, and leave approvals. |
| **Finance Manager** | Tenant-wide, finance domain | Single tenant, finance domain | Approve/Configure authority over Finance; read-only visibility into finance-relevant data in other modules. |
| **Employee** | Self-scoped | Own records only | Self-service only — own profile, own tasks, own attendance/leave, own payslip. |
| **Accountant** | Tenant-wide, finance execution | Single tenant, finance domain | Executes/records finance work (Create/Edit on transactions); does not approve or configure. |

---

## 2. Role and Permission

The concrete permission strings each role holds (`module.verb`). This is the layer that gets seeded into the RolePermission table and checked directly at the API boundary — everything else in this document is documentation *about* these strings.

### Super Admin
`tenant.view` · `tenant.create` · `tenant.delete` · `tenant.configure` · `user.configure` · `settings.configure` · `employee.view` · `ai.configure` · `audit.view` · `audit.export` · `report.view` · `report.export` · `mobile.view`

### Tenant Admin
`tenant.view` · `tenant.configure` · `user.view` · `user.create` · `user.edit` · `user.delete` · `settings.configure` · `employee.view` · `employee.create` · `employee.edit` · `employee.delete` · `project.view` · `attendance.view` · `attendance.configure` · `leave.view` · `leave.configure` · `finance.view` · `finance.configure` · `document.view` · `ai.configure` · `audit.view` · `audit.export` · `report.view` · `report.export` · `mobile.view`

### HR
`user.create` · `user.edit` (HR-role users) · `settings.configure` (HR/leave/attendance) · `employee.view` · `employee.create` · `employee.edit` · `employee.delete` · `project.view` · `attendance.view` · `attendance.configure` · `attendance.approve` · `attendance.export` · `leave.view` · `leave.configure` · `leave.approve` · `finance.view` (limited) · `document.view` (employee docs) · `ai.view` · `audit.view` (HR scope) · `report.view` · `report.export` (HR reports) · `mobile.view`

### Team Lead
`user.view` (team membership) · `settings.edit` (team/project) · `employee.view` (own team) · `project.view` · `project.create` · `project.edit` · `project.delete` (own team) · `attendance.view` · `attendance.approve` (team) · `leave.view` · `leave.approve` (team) · `finance.view` (budget, if allowed) · `document.view` (project docs) · `ai.view` · `audit.view` (team scope) · `report.view` · `report.export` (team reports) · `mobile.view`

### Finance Manager
`user.create` · `user.edit` (finance-role users) · `settings.configure` (finance/payroll/expense) · `employee.view` (finance-relevant) · `project.view` (budget, if allowed) · `attendance.view` (payroll-relevant) · `leave.view` (payroll-relevant) · `finance.configure` · `finance.approve` · `finance.export` · `document.view` (finance docs) · `ai.view` · `audit.view` (finance scope) · `report.view` · `report.export` (finance reports) · `mobile.view`

### Employee
`user.view` (own access) · `settings.edit` (own preferences) · `employee.view` · `employee.edit` (own profile, safe fields) · `project.view` · `project.edit` (assigned tasks) · `attendance.view` · `attendance.create` (own) · `leave.view` · `leave.create` (own) · `finance.create` (submit expense, if enabled) · `finance.view` (own payslip, read-only) · `document.view` · `document.create` (own/allowed docs) · `ai.view` (allowed self-service) · `audit.view` (own activity) · `report.view` (own summaries) · `mobile.view` · `mobile.create` · `mobile.edit`

### Accountant
`user.create` · `user.edit` (finance-role users) · `settings.edit` (accounting preferences) · `employee.view` (finance-relevant) · `project.view` (if finance-related) · `attendance.view` (payroll-relevant) · `leave.view` (payroll-relevant) · `finance.create` · `finance.edit` (record/reconcile/report) · `finance.view` (payroll run status/history) · `document.view` (finance docs) · `ai.view` (finance extraction/search) · `audit.view` (finance scope) · `report.view` · `report.export` (accounting reports) · `mobile.view`

---

## 3. Role and Feature

What each role can actually do, module by module, in plain terms.

### Super Admin
- **Tenant/Platform** — create/suspend tenants, platform-wide audit
- **Users/Roles/Permissions** — sets platform-wide policy only
- **Settings** — platform defaults only
- **Employees/Org** — support/audit view only
- **AI** — platform-wide model/cost policy
- **Audit** — platform-wide audit log
- **Reports** — platform-wide reports
- **Mobile App** — support access only
- No access to: Projects/Tasks, Attendance, Leave, Finance, Documents

### Tenant Admin
- **Tenant/Platform** — manage own tenant
- **Users/Roles/Permissions** — invite users, assign roles, custom permissions
- **Settings** — General/Security/Notification/AI settings
- **Employees/Org** — full CRUD
- **Projects/Tasks** — full tenant visibility
- **Attendance / Leave** — full policy/admin
- **Finance** — full tenant admin (setup, not day-to-day processing)
- **Documents** — tenant-wide
- **AI** — enables features, sets caps
- **Audit / Reports** — tenant-wide
- **Mobile App** — admin summary, if allowed

### HR
- **Users/Roles/Permissions** — manages HR-role users
- **Settings** — owns HR/leave/attendance settings
- **Employees/Org** — full CRUD (departments, teams, employees)
- **Projects/Tasks** — optional read only
- **Attendance / Leave** — policies, reports, approvals
- **Finance** — limited (headcount cost context only)
- **Documents** — employee docs
- **AI** — HR/employee/team summaries
- **Audit / Reports** — HR scope
- **Mobile App** — HR summary, optional

### Team Lead
- **Users/Roles/Permissions** — team membership only
- **Settings** — team/project preferences
- **Employees/Org** — view own team only
- **Projects/Tasks** — create/manage team projects
- **Attendance / Leave** — team approvals
- **Finance** — limited (budget read if allowed)
- **Documents** — project docs
- **AI** — project summaries
- **Audit / Reports** — team scope
- **Mobile App** — team/task view

### Finance Manager
- **Users/Roles/Permissions** — manages finance-role users
- **Settings** — owns finance/payroll/expense settings
- **Employees/Org** — reads finance-relevant fields only (e.g. salary)
- **Projects/Tasks** — budget/read if allowed
- **Attendance / Leave** — reads payroll-relevant data
- **Finance** — configure settings, trigger payroll run, single sign-off approval, approve expenses, view reports
- **Documents** — finance docs
- **AI** — finance insight summaries (synthetic/demo data)
- **Audit / Reports** — finance scope
- **Mobile App** — finance summary, optional

### Employee
- **Users/Roles/Permissions** — views own access only
- **Settings** — own preferences
- **Employees/Org** — own profile only (safe fields)
- **Projects/Tasks** — assigned tasks only
- **Attendance / Leave** — check-in/out, request leave (own)
- **Finance** — submit expense if enabled; read-only own payslip (no editing, no processing)
- **Documents** — own/allowed docs
- **AI** — allowed self-service AI
- **Audit / Reports** — own activity only
- **Mobile App** — primary self-service (full mobile feature set)

### Accountant
- **Users/Roles/Permissions** — manages finance-role users (shared with Finance Manager)
- **Settings** — accounting preferences
- **Employees/Org** — reads finance-relevant fields only
- **Projects/Tasks** — read if finance-related
- **Attendance / Leave** — reads payroll-relevant data
- **Finance** — records/reconciles/reports; views payroll run status/history (does not trigger or approve)
- **Documents** — finance docs
- **AI** — finance extraction/search
- **Audit / Reports** — finance scope
- **Mobile App** — finance summary, optional

---

## 4. Module and Features

Each module's concrete feature set and its per-role verb access (View / Create / Edit / Delete / Approve / Configure / Export).

### 4.1 Tenant/Platform
*Create/suspend tenants, own-tenant management, platform defaults*

| Role | Access |
|---|---|
| Super Admin | Create, Delete (suspend), Configure — platform-wide |
| Tenant Admin | View, Configure — own tenant only |
| HR / Team Lead / Finance Manager / Employee / Accountant | — |

### 4.2 Users/Roles/Permissions
*Invite users, assign roles, custom permissions*

| Role | Access |
|---|---|
| Super Admin | Configure — platform policy only |
| Tenant Admin | View, Create, Edit, Delete — full, own tenant |
| HR | Create, Edit — HR-role users only |
| Team Lead | View — team membership only |
| Finance Manager | Create, Edit — finance-role users |
| Employee | View — own access only |
| Accountant | Create, Edit — finance-role users |

### 4.3 Settings
*General, Security, Notification, HR, Finance, AI settings*

| Role | Access |
|---|---|
| Super Admin | Configure — platform defaults |
| Tenant Admin | Configure — General/Security/Notification/AI |
| HR | Configure — HR/leave/attendance |
| Team Lead | Edit — team/project preferences |
| Finance Manager | Configure — finance settings |
| Employee | Edit — own preferences |
| Accountant | Edit — accounting preferences |

### 4.4 Employees/Org
*Departments, teams, managers, employee CRUD/profile*

| Role | Access |
|---|---|
| Super Admin | View — support/audit only |
| Tenant Admin | View, Create, Edit, Delete — full CRUD |
| HR | View, Create, Edit, Delete — full CRUD |
| Team Lead | View — own team only |
| Finance Manager | View — finance-relevant fields only |
| Employee | View, Edit — own profile, safe fields only |
| Accountant | View — finance-relevant fields only |

### 4.5 Projects/Tasks
*Project/task CRUD, Kanban, comments/activity, realtime*

| Role | Access |
|---|---|
| Super Admin | — |
| Tenant Admin | View — full tenant visibility |
| HR | View — optional read |
| Team Lead | View, Create, Edit, Delete — manage team projects |
| Finance Manager | View — budget/read, if allowed |
| Employee | View, Edit — assigned tasks, status update only |
| Accountant | View — if finance-related |

### 4.6 Attendance
*Check-in/out, history, rules/policy, approvals, reports*

| Role | Access |
|---|---|
| Super Admin | — |
| Tenant Admin | View, Configure — full policy/admin |
| HR | View, Configure, Approve, Export — policy, reports, approvals |
| Team Lead | View, Approve — team approvals |
| Finance Manager | View — payroll-relevant read only |
| Employee | View, Create — own check-in/out |
| Accountant | View — payroll-relevant read only |

### 4.7 Leave
*Leave types, balances, request, approval, history*

| Role | Access |
|---|---|
| Super Admin | — |
| Tenant Admin | View, Configure — full policy/admin |
| HR | View, Configure, Approve — policy, approvals |
| Team Lead | View, Approve — team approvals |
| Finance Manager | View — payroll-relevant read only |
| Employee | View, Create — request/history, own |
| Accountant | View — payroll-relevant read only |

### 4.8 Finance
*Settings, expense/invoice mini-flow, approvals, bounded payroll (fixed salary field, manual payroll run trigger, payslip snapshot, single sign-off — no tax engine, multi-currency, or approval chain)*

| Role | Access |
|---|---|
| Super Admin | — |
| Tenant Admin | View, Configure — full tenant admin |
| HR | View — limited |
| Team Lead | View — limited |
| Finance Manager | Configure, Approve, Export — settings, payroll trigger + sign-off, approvals, reports |
| Employee | Create — submit expense if enabled; View — own payslip, read-only |
| Accountant | Create, Edit — record/reconcile/report; View — payroll run status/history |

### 4.9 Documents
*Upload, metadata, ownership, secure access*

| Role | Access |
|---|---|
| Super Admin | — |
| Tenant Admin | View — tenant-wide |
| HR | View — employee docs |
| Team Lead | View — project docs |
| Finance Manager | View — finance docs |
| Employee | View, Create — own/allowed docs |
| Accountant | View — finance docs |

### 4.10 AI
*Summary, extraction, embeddings, RAG, tool calls, cost controls*

| Role | Access |
|---|---|
| Super Admin | Configure — platform model/cost policy |
| Tenant Admin | Configure — enable features, caps, AI settings |
| HR | View — HR summaries/search |
| Team Lead | View — project summaries |
| Finance Manager | View — finance analysis, if enabled |
| Employee | View — allowed self-service AI |
| Accountant | View — finance extraction/search |

### 4.11 Audit
*Append-only audit trail — business/security/AI actions*

| Role | Access |
|---|---|
| Super Admin | View, Export — platform audit |
| Tenant Admin | View, Export — tenant audit |
| HR | View — HR scope |
| Team Lead | View — team scope |
| Finance Manager | View — finance scope |
| Employee | View — own activity only |
| Accountant | View — finance scope |

### 4.12 Reports
*Role-scoped KPI queries, filters, CSV export, cached aggregates — deterministic, not AI-generated*

| Role | Access |
|---|---|
| Super Admin | View, Export — platform reports |
| Tenant Admin | View, Export — tenant reports |
| HR | View, Export — HR reports |
| Team Lead | View, Export — team reports |
| Finance Manager | View, Export — finance reports |
| Employee | View — own summaries only |
| Accountant | View, Export — accounting reports |

### 4.13 Mobile App
*Login/session, dashboard, attendance, leave, tasks, push — same API, no separate business database*

| Role | Access |
|---|---|
| Super Admin | View — support only |
| Tenant Admin | View — admin summary, if allowed |
| HR | View — HR summary, optional |
| Team Lead | View — team/task view |
| Finance Manager | View — finance summary, optional |
| Employee | View, Create, Edit — primary self-service |
| Accountant | View — finance summary, optional |

---

## 5. Role, Module, Feature and AI

Full per-role profile: every module the role touches, the feature/verb access, and the AI capability attached (if any). AI never grants more access than the role already has in that module — it is a new interface onto existing data, not a new authorization path. Read-only AI capabilities may execute automatically once the underlying module permission is satisfied; any AI capability that writes data always requires explicit user confirmation plus a server-side permission recheck.

### Super Admin

| Module | Feature access | AI capability |
|---|---|---|
| Tenant/Platform | Create, Delete, Configure (platform-wide) | Sets platform-wide AI model/cost policy (governance only) |
| Users/Roles/Permissions | Configure (platform policy) | — |
| Settings | Configure (platform defaults) | — |
| Employees/Org | View (support/audit) | — |
| Audit | View, Export (platform) | Sees audit entries for every AI action, platform-wide |
| Reports | View, Export (platform) | — |
| Mobile App | View (support only) | — |

### Tenant Admin

| Module | Feature access | AI capability |
|---|---|---|
| Tenant/Platform | View, Configure (own tenant) | — |
| Users/Roles/Permissions | Full CRUD | — |
| Settings | Configure (General/Security/Notification/AI) | Owns the AI settings tab: enable/disable features, request cap, document-AI toggle, tool-action toggle |
| Employees/Org | Full CRUD | — |
| Projects/Tasks | View (tenant-wide) | — |
| Attendance / Leave | View, Configure (full policy) | — |
| Finance | View, Configure (full admin) | — |
| Documents | View (tenant-wide) | — |
| AI | Configure (enable features, caps) | Configures the AI provider/tool registry for the tenant |
| Audit / Reports | View, Export (tenant-wide) | Sees audit entries for every AI action, tenant-wide |
| Mobile App | View (admin summary, if allowed) | — |

### HR

| Module | Feature access | AI capability |
|---|---|---|
| Users/Roles/Permissions | Create, Edit (HR-role users) | — |
| Settings | Configure (HR/leave/attendance) | — |
| Employees/Org | Full CRUD | Employee/team summaries (full team) |
| Projects/Tasks | View (optional) | — |
| Attendance | View, Configure, Approve, Export | — |
| Leave | View, Configure, Approve | Leave balance visible in approval flow |
| Finance | View (limited) | — |
| Documents | View (employee docs) | Semantic search over employee docs, scoped to HR's document permission |
| Audit / Reports | View (HR scope) / View, Export (HR reports) | Sees audit entries for AI actions within HR scope |
| Mobile App | View (HR summary, optional) | — |

### Team Lead

| Module | Feature access | AI capability |
|---|---|---|
| Users/Roles/Permissions | View (team membership) | — |
| Settings | Edit (team/project preferences) | — |
| Employees/Org | View (own team) | Employee summary scoped to own team only |
| Projects/Tasks | Full CRUD (own team's projects) | Project summaries |
| Attendance / Leave | View, Approve (team approvals) | Leave balance shown in approval flow |
| Finance | View (budget, if allowed) | — |
| Documents | View (project docs) | Search over project docs, scoped to Team Lead's permission |
| Audit / Reports | View (team scope) / View, Export (team reports) | Sees audit entries for AI actions within team scope |
| Mobile App | View (team/task view) | — |

### Finance Manager

| Module | Feature access | AI capability |
|---|---|---|
| Users/Roles/Permissions | Create, Edit (finance-role users) | — |
| Settings | Configure (finance/payroll/expense) | — |
| Employees/Org | View (finance-relevant fields) | — |
| Projects/Tasks | View (budget, if allowed) | — |
| Attendance / Leave | View (payroll-relevant) | — |
| Finance | Configure, Approve, Export (settings, payroll trigger + sign-off, approvals, reports) | Finance insight summaries, bounded to synthetic/demo data — no live financial analysis engine |
| Documents | View (finance docs) | Search/extraction over finance docs, scoped to finance permission |
| Audit / Reports | View (finance scope) / View, Export (finance reports) | Sees audit entries for AI actions within finance scope |
| Mobile App | View (finance summary, optional) | — |

### Employee

| Module | Feature access | AI capability |
|---|---|---|
| Users/Roles/Permissions | View (own access) | — |
| Settings | Edit (own preferences) | — |
| Employees/Org | View, Edit (own profile, safe fields) | Employee summary restricted to own profile, only if self-service AI is enabled |
| Projects/Tasks | View, Edit (assigned tasks) | — |
| Attendance | View, Create (own check-in/out) | — |
| Leave | View, Create (own request/history) | Own leave balance |
| Finance | Create (submit expense, if enabled); View (own payslip, read-only) | — |
| Documents | View, Create (own/allowed docs) | Allowed self-service AI over own/allowed docs |
| Audit / Reports | View (own activity) / View (own summaries) | — |
| Mobile App | View, Create, Edit (primary self-service) | None initially — Employee is the intended candidate for a future mobile AI entry point |

### Accountant

| Module | Feature access | AI capability |
|---|---|---|
| Users/Roles/Permissions | Create, Edit (finance-role users) | — |
| Settings | Edit (accounting preferences) | — |
| Employees/Org | View (finance-relevant fields) | — |
| Projects/Tasks | View (if finance-related) | — |
| Attendance / Leave | View (payroll-relevant) | — |
| Finance | Create, Edit (record/reconcile/report); View (payroll run status/history) | Finance extraction/search — pulling structured data out of invoices/receipts |
| Documents | View (finance docs) | Document extraction/search over finance docs |
| Audit / Reports | View (finance scope) / View, Export (accounting reports) | Sees audit entries for AI actions within finance scope |
| Mobile App | View (finance summary, optional) | — |
