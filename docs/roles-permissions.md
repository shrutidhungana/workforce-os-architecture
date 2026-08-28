# Roles & Permissions

This document is the **system spec** for authorization: the naming convention, the full permission catalog (the seed list), and how permission checks get tested. [`feature-role-matrix.md`](./feature-role-matrix.md) is the *applied* result — the full per-role, per-module grid. This doc is what makes that grid seedable and testable rather than just prose.

**Governing rule (repeated from the matrix, because this doc should stand alone):** UI visibility is never authorization. Every permission check happens server-side, on every request, regardless of what the client sends or hides.

---

## 1. Role vs Permission

- A **permission** is the atomic, checkable unit: `employee.edit`, `leave.approve`. One string, one yes/no question, checked at the API boundary.
- A **role** is just a named bundle of permissions (`role_permission` join table). Roles don't have special-cased behavior in code — a Team Lead can approve leave because the `TeamLead` role happens to hold `leave.approve`, not because a service function checks `if (user.role === 'TeamLead')`.

Why this matters: when Accountant later also needs `document.view` on a new document type, that's a one-row seed change to `role_permission`, not a new `if` branch scattered across every service that touches documents.

## 2. Naming Convention

Every permission string is `module.verb`.

| Verb | Meaning |
|---|---|
| `view` | Read access to the module's data |
| `create` | Add a new record |
| `edit` | Modify an existing record |
| `delete` | Remove a record |
| `approve` | Move a record through an approval workflow (leave, expense) |
| `configure` | Change module-wide settings/policy, not a single record |
| `export` | Bulk data egress (CSV, report download) — kept distinct from `view` because export is a bigger data-leak risk and gets its own Audit event |

**Scope is not encoded in the permission string.** There is no `audit.read.finance` or `report.view.team` — a role either holds `audit.view` or it doesn't. *Which rows* it sees (own team, own tenant, finance-scoped records) is enforced by query-scoping in the repository/service layer using the caller's tenant/team/self context, not by minting a new permission string per scope.

**Trade-off:** this keeps the permission table small (roughly one string per module per verb, not one per scope combination) and keeps every scope rule in one place — the tenant-context/repository layer — instead of smeared across permission names. The cost is that "HR sees audit scoped to HR" is a code-level rule, not something visible by reading the seed table alone; it has to be documented (as it is in the matrix) and tested explicitly.

**When to revisit:** if a tenant ever needs *custom* scope rules (e.g. "this Team Lead can also see Team B"), row-level scoping stops being expressible as a fixed code rule and this naming convention would need to evolve toward a real policy engine (e.g. CASL/OPA) with per-tenant grants. Not needed at this project's scale — flagging it now so the limitation is a documented decision, not a surprise later.

## 3. Permission Catalog (Seed List)

The full set of permission strings seeded into the `permission` table, grouped by module:

| Module | Permissions |
|---|---|
| Tenant/Platform | `tenant.view` · `tenant.create` · `tenant.delete` · `tenant.configure` |
| Users/Roles | `user.view` · `user.create` · `user.edit` · `user.delete` · `user.configure` |
| Settings | `settings.view` · `settings.edit` · `settings.configure` (checked per-group: general/security/notifications/hr/finance/ai) |
| Employees/Org | `employee.view` · `employee.create` · `employee.edit` · `employee.delete` |
| Projects/Tasks | `project.view` · `project.create` · `project.edit` · `project.delete` |
| Attendance | `attendance.view` · `attendance.create` · `attendance.configure` · `attendance.approve` · `attendance.export` |
| Leave | `leave.view` · `leave.create` · `leave.configure` · `leave.approve` |
| Finance | `finance.view` · `finance.create` · `finance.edit` · `finance.configure` · `finance.approve` · `finance.export` |
| Documents | `document.view` · `document.create` |
| AI | `ai.view` · `ai.configure` |
| Audit | `audit.view` · `audit.export` |
| Reports | `report.view` · `report.export` |
| Mobile | `mobile.view` · `mobile.create` · `mobile.edit` |

This is the literal input to the identity-schema seed migration (`role`, `permission`, `role_permission` tables). Every permission a role holds in [`feature-role-matrix.md` §2](./feature-role-matrix.md#2-role-and-permission) must come from this list — the matrix and this catalog must never drift apart.

## 4. Role → Permission Bundles

The 7 roles (Super Admin, Tenant Admin, HR, Team Lead, Finance Manager, Employee, Accountant) each resolve to a fixed bundle of the permissions above. The exhaustive per-role list already lives in [`feature-role-matrix.md` §2](./feature-role-matrix.md#2-role-and-permission) — not repeated here to avoid the two documents disagreeing with each other over time.

## 5. Permission Check vs Ownership Check

Not every access rule is a permission lookup. Some are **ownership checks** — "is this your own record?" — which are a different, cheaper question than "does your role hold this permission?":

- Viewing/editing your own profile, own notifications, own sessions — ownership, not `employee.view`/`.edit` on someone else's row.
- A permission (`employee.edit`) can still gate *which fields* are editable even on an owned record (Employee can edit safe self-service fields on their own profile; changing `role` or `salary` requires the admin-scoped permission, even for your own record).

Both checks are server-side. Neither is ever satisfied by the client simply not rendering a field.

## 6. Tenant Defaults vs Per-User Preferences

Not covered here — permissions govern *whether* an action is allowed; the tenant-default-vs-per-user-preference question is a Settings-module data-modeling concern. See [`settings-design.md`](./settings-design.md).

## 7. How Permission Checks Will Be Tested

This is what turns the catalog above from documentation into a guarantee:

1. **Unit — permission resolution.** Given a `(user, tenant)` pair, the query that resolves the caller's effective permission set (`membership → role → role_permission`) returns exactly the seeded bundle for that role.
2. **Integration — allowed/denied per procedure.** Every protected tRPC procedure/REST route gets two tests minimum: one caller whose role holds the required permission (expect success), one whose role doesn't (expect 403).
3. **Matrix-driven regression.** Rather than hand-writing a 403 test per role per endpoint, generate the negative cases directly from this catalog: for every `(role, permission)` pair *not* in that role's seeded bundle, assert the corresponding endpoint returns 403 for that role. This makes the permission catalog itself the test fixture — adding a permission to the catalog without updating a role's bundle can't silently pass.
4. **Cross-tenant regression.** Same permission, same role, wrong tenant → denied. This is a distinct failure mode from a missing permission and needs its own test, not folded into #2.
5. **CI gate.** All of the above run on every PR. A PR that weakens or removes a permission check fails CI on the regression suite, not just on human review.

## 8. Deliberately Out of Scope for v1

- Custom per-tenant roles or a role/permission editor UI — the 7 roles and their bundles are fixed and seeded at deploy time, not tenant-configurable.
- Resource-level ACLs beyond the three scopes already in use (self / team / tenant).
- Temporary permission elevation or delegation.

**Revisit when:** a real requirement for tenant-defined roles or finer-grained scoping shows up — not preemptively.
