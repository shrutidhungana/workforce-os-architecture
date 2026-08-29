# Mobile Architecture

## 1. What This Document Covers

How the React Native / Expo mobile app fits into the existing system: what it talks to, what it never talks to, what code it shares with the web app, how it stores a session securely, and how push notifications reach it. Diagrams live in [`diagrams/mobile-architecture.md`](../diagrams/mobile-architecture.md).

## 2. Core Rule: Mobile Is a Client, Not a Backend

Mobile is not a backend module. It is a client of the same public API the web app uses — same modular monolith, same auth, same RBAC, same domain services. There is no mobile-specific backend, no mobile-only database, and no direct database access from the app.

Concretely: `Mobile App → Public API → Auth/RBAC → Shared Domain Services → PostgreSQL`. The full request path, including where push notifications branch off, is diagrammed in [`diagrams/mobile-architecture.md`](../diagrams/mobile-architecture.md).

Why this matters: building a second backend (or a mobile-specific API layer) would mean duplicating auth, RBAC, and every domain rule in two places — and the two copies drifting apart over time is a near-certainty, not a risk. Reusing the same API means a permission fix, a validation rule, or a new field only has to be written once.

## 3. Mobile Scope (Self-Service) vs. Web Scope (Admin/Management)

Mobile deliberately covers a subset of what the web app covers — self-service and day-to-day actions, not administration:

| Mobile | Web-only |
|---|---|
| Login | Tenant/organization management |
| Dashboard | Department/team management |
| Attendance (check-in/check-out) | Role and permission assignment |
| Leave (request, view balance/status) | Approving other people's leave (Team Lead/HR) |
| Assigned tasks (view, update status) | Kanban board management, task creation/assignment |
| Notifications | Payroll runs, financial reports |
| Selected AI features (e.g. summaries) | Full AI/RAG document workflows |

This split isn't a technical limitation — the same API endpoints exist either way. It's a product decision: approval workflows, org configuration, and financial operations are dense, multi-step, and better suited to a larger screen. Nothing here prevents extending mobile scope later; it only requires building the missing screens against APIs that already exist.

## 4. Shared Types vs. Platform-Specific Code

Because mobile and web hit the same API, they share the same domain contract:

**Shared (should not be duplicated per platform):**
- Domain/API types — `User`, `Employee`, `LeaveRequest`, `Task`, `Notification`, etc., and their request/response shapes
- Validation schemas for anything submitted to the API (e.g. a leave request form's shape)
- API client logic — auth header handling, base request wrapper, error shape

**Platform-specific (intentionally not shared):**
- UI components and screens — React (web) vs. React Native (mobile) render trees are fundamentally different
- Navigation — routed URLs (web) vs. a native navigator/stack (mobile)
- Local storage mechanism — browser storage vs. Expo's secure storage APIs (see §5)
- Platform capabilities — camera/photo upload, push notification registration, biometric unlock

Practically, this means the types and validation schemas generated from or shared with the backend belong in a package both clients import, while every screen and navigation stack is written twice, once per platform, on purpose.

## 5. Secure Mobile Session Storage

A mobile session needs the same properties a web session needs — the token must not be readable by other apps on the device, and it must not silently outlive its intended lifetime — but the mechanism differs because there's no `HttpOnly` cookie on a native app.

Concept:
- The access/refresh token pair is written to the device's secure storage (iOS Keychain / Android Keystore, via Expo's `SecureStore` or equivalent), never to plain `AsyncStorage` or another unencrypted key-value store.
- The refresh-token rotation and reuse-detection rules already defined for web sessions apply unchanged — mobile is just another session, not a different session model.
- Logout and "revoke all sessions" both need to reach mobile sessions too, since a session row in the backend doesn't care which client created it.
- App backgrounding/foregrounding needs a defined behavior (e.g. re-validate or silently refresh on foreground) so a stale token doesn't surface as a confusing failed request deep in the app.

**Open question, not yet resolved:** exact re-authentication behavior after a long background period (silent refresh vs. forced re-login) — deferred until session/token architecture is implemented end-to-end.

## 6. Offline and Retry Behavior

Mobile networks are unreliable in a way browser sessions usually aren't, so the app needs an explicit stance on:
- **Read data while offline** — showing last-known cached data (e.g. last-loaded dashboard/task list) rather than a blank error screen.
- **Writes made while offline** — either blocked with a clear "you're offline" state, or queued and retried on reconnect. Blocking is the simpler starting point; queuing is a later enhancement once the retry/idempotency patterns from the notification work are established.
- **Reconnection** — a network-state listener that triggers a refetch of visible screens, rather than leaving stale data on screen indefinitely.

This is deliberately left as application-level behavior rather than a new architectural component — it doesn't change what the backend looks like, only how the client behaves around the same API.

## 7. Push Notifications

Push is one more delivery channel off the existing Notification Service, not a separate system. The same domain event that would produce an in-app or email notification (a leave approval, a task assignment) also triggers a push send when the recipient has a registered device token. The full path is diagrammed in [`diagrams/mobile-architecture.md`](../diagrams/mobile-architecture.md) §3.

Device token registration itself is a small, mobile-specific step: on login (or first grant of notification permission), the app registers its push token against the current user, and the Notification Service looks up that token when it has something to deliver.

## 8. What I Should Be Able to Explain From This

- Why mobile calls the same API instead of getting its own backend, and what duplicating auth/RBAC into a second backend would cost.
- Why the mobile/web scope split is a product decision, not a technical constraint.
- What's shared (types, validation, API client) vs. platform-specific (UI, navigation, storage), and why.
- Why session tokens go into secure device storage rather than plain key-value storage, and why refresh-token rotation applies to mobile the same way it applies to web.
- Why push notifications are modeled as a channel off one Notification Service rather than a separate mobile-only notification system.

## 9. Still Open

- Exact re-authentication behavior after extended app backgrounding (§5).
- Whether offline writes are blocked or queued, and if queued, how idempotency is guaranteed on retry (§6).
- Which AI features actually ship on mobile first, once AI/RAG work is further along.
