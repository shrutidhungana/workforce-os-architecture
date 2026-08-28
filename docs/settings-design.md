# Settings Design

[`module-feature-map.md`](./module-feature-map.md#settings) documents Settings using the same generic per-module template as every other module (Purpose/Screens/API/Entities/Permissions). This document is the deep-dive that template doesn't have room for: what's actually inside each of the six groups, who can configure what, and how tenant-wide defaults relate to per-user overrides.

---

## 1. Two Layers: Tenant Defaults vs Per-User Preferences

- **Tenant defaults** — one row per `(tenant_id, group)` in the `settings` table. Every field in a group is Zod-validated against that group's schema. This is tenant-wide policy, set by whichever role owns that group.
- **Per-user preferences** — rows in `user_preference`. Only the fields a group's schema explicitly marks as "personal" get a per-user override; most groups have none at all.
- **Resolution order:** read the tenant default for the group, then apply the user's override only for fields flagged personal. A field with no personal layer always resolves to the tenant default, for every user, with no exception.

This is a deliberately small model — two layers, not a hierarchy of department/team/user overrides — because nothing in this product's scope needs a middle tier yet (see §6).

## 2. The Six Groups

### General
- **Fields:** tenant display name, default timezone, default locale, date/currency display format.
- **Configured by:** Tenant Admin (`settings.configure`, `general`).
- **Personal override:** timezone, locale — a user can view the app in their own timezone without changing the tenant default everyone else sees.

### Security
- **Fields:** session/refresh-token expiry policy, whether MFA is required tenant-wide, password policy.
- **Configured by:** Tenant Admin (`settings.configure`, `security`).
- **Personal override:** none. Security policy is never a per-user choice — an individual can't opt out of a tenant-wide MFA requirement.

### Notifications
- **Fields:** which channels (in-app/email/push) are enabled per event type at the tenant level, default digest frequency.
- **Configured by:** Tenant Admin (`settings.configure`, `notifications`).
- **Personal override:** yes — a user can opt out of a channel the tenant has enabled (e.g. mute email, keep in-app), and set quiet hours. A user cannot turn *on* a channel the tenant has disabled tenant-wide.

### HR
- **Fields:** leave types and policies, attendance rules (grace period, standard work hours), org-level defaults.
- **Configured by:** HR (`settings.configure`, `hr`).
- **Personal override:** none — these are workforce policy, not individual preference.

### Finance
- **Fields:** expense/invoice approval threshold, payroll run day, currency, single-sign-off requirement toggle.
- **Configured by:** Finance Manager (`settings.configure`, `finance`).
- **Personal override:** none.
- This group is also surfaced inside the Finance module's own "Finance Settings" screen for workflow convenience — same underlying data and permission check, just a friendlier entry point. The Finance module does not own a second copy of this data.

### AI
- **Fields:** per-feature toggles (structured summaries, RAG, document extraction, tool calling), tenant request cap, whether tool-calling writes require confirmation (this is a floor, not something a tenant can disable below the platform-enforced minimum).
- **Configured by:** Tenant Admin (`settings.configure`, `ai`).
- **Personal override:** none — AI is governed at the tenant level, deliberately, because the request cap exists for cost control and a per-user override would defeat that.

## 3. Role Ownership Summary

| Group | Configure | Edit (personal only) |
|---|---|---|
| General | Tenant Admin | — |
| Security | Tenant Admin | — |
| Notifications | Tenant Admin | Everyone (own channel/quiet-hours prefs) |
| HR | HR | — |
| Finance | Finance Manager | — |
| AI | Tenant Admin | — |

Team Lead, Employee, and Accountant hold `settings.edit` scoped to their own preferences only (timezone/locale under General, channel opt-outs under Notifications) — never `settings.configure` on any tenant-wide group.

## 4. Validation & Enforcement

- Each group has its own Zod schema in `packages/validators` — a PATCH to `finance` is validated against the Finance schema, not a generic "settings" shape.
- `GET/PATCH /settings/:group` checks the permission **for that specific group**, not a blanket "has some settings permission" check. A Finance Manager's `settings.configure` grant is scoped to `finance` — the server rejects a `PATCH /settings/security` from that same caller even though both are nominally "settings.configure".
- `GET/PATCH /settings/me` is an ownership check (own preferences), separate from the group-scoped permission checks above — see [`roles-permissions.md` §5](./roles-permissions.md#5-permission-check-vs-ownership-check).

## 5. Audit

Every settings change — tenant default or personal preference — produces an Audit event. Security and Finance changes are the highest-sensitivity case here (a misconfigured session-expiry or approval-threshold is a real risk, not a cosmetic change), so the Audit UI's filtering treats them as a category worth surfacing distinctly rather than burying them in general activity.

## 6. Deliberately Out of Scope for v1

- A department- or team-level settings tier between tenant and user — only two layers exist.
- Settings versioning/rollback UI beyond what Audit already captures as a change history.
- Tenant-configurable Security fields that are actually platform/ops concerns (CORS allow-list, infra-level rate limits) — those live in deployment config, not the `settings` table, because a tenant should never be able to weaken a platform-enforced boundary.

**Revisit when:** a real customer need for team-level configuration appears — not preemptively.
