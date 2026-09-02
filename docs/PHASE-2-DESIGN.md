# Phase 2 — Authentication & Access Control: Design for Review

Depends on Phase 1. Replaces the fake auth behind `AuthRepository` with the real backend.

## 1. Backend contract (verified)

Base `/api/v1/auth`:

| Method | Path | Body | Returns |
|---|---|---|---|
| POST | `/login` | `{username, password}` | `AuthResponse` |
| POST | `/refresh` | `{refreshToken}` | `AuthResponse` |
| POST | `/logout` | `{refreshToken}` | `Void` |
| POST | `/logout-all` | – | `Void` |
| POST | `/change-password` | `ChangePasswordRequest` | `Void` |
| GET | `/me` | – | `UserResponse` |

```text
AuthResponse   = accessToken, refreshToken, tokenType,
                 accessTokenExpiresAt (Instant), mustChangePassword, user
UserResponse   = id, username, fullName, email, phone, employeeCode, status,
                 primaryBranchId, branchIds[], roles[], permissions[], lastLoginAt
```

Supporting: `GET /api/v1/branches`, `GET /api/v1/branches/{id}`,
`GET /api/v1/branches/{branchId}/locations`, `GET /api/v1/companies`.

`BranchResponse = id, companyId, code, name, headOffice, addressLine, city, country, phone, email, timezone, status`
`UserStatus = ACTIVE | INACTIVE | LOCKED | SUSPENDED`

## 2. Login flow

```text
Login screen (username + password)
        │
        ▼  POST /auth/login
  AuthResponse
        │
        ├─ mustChangePassword ──▶ /change-password (forced, not skippable)
        │
        ├─ store accessToken + refreshToken in secure storage
        ├─ hydrate SessionState from response.user (no extra /me round-trip)
        │
        ▼
  branchIds.length
        ├─ 0  ──▶ error: "No branch assigned. Contact your administrator."
        ├─ 1  ──▶ auto-select, go /dashboard
        └─ >1 ──▶ /select-branch (default = primaryBranchId, remembered next launch)
```

Non-happy paths handled explicitly, each with its own message:
`UNAUTHORIZED` → "Incorrect username or password"; `status != ACTIVE` → "Your account is
`LOCKED`/`SUSPENDED`"; network/timeout → retry affordance; `INTERNAL_ERROR` → generic message
plus the `correlationId` so support can trace it.

## 3. Token lifecycle

`accessTokenExpiresAt` is returned by the backend, so the app refreshes **proactively** rather
than waiting for a 401.

```text
AuthInterceptor.onRequest
  ├─ skip for /auth/login, /auth/refresh
  ├─ if now > expiresAt - 60s  ──▶ await refresh, then attach
  └─ attach: Authorization: Bearer <accessToken>

AuthInterceptor.onError (401)
  ├─ request was /auth/refresh  ──▶ hard logout
  ├─ refresh already in flight  ──▶ queue this request, replay on success
  └─ else                       ──▶ single-flight refresh, replay queued requests
```

The single-flight lock is the important detail: a dashboard that fires six parallel calls must
produce **one** refresh, not six. Implemented with a `Completer` guard in `TokenRefresher`.

Refresh failure → clear secure storage → `SessionState.unauthenticated` → GoRouter redirects
to `/login`. No screen needs to know this happened.

## 4. Storage rules

| Item | Where | Notes |
|---|---|---|
| accessToken, refreshToken | `flutter_secure_storage` | Keychain (`first_unlock_this_device`) / EncryptedSharedPreferences |
| accessTokenExpiresAt | secure storage | needed for proactive refresh |
| user profile, permissions | in-memory + optional encrypted cache | re-fetched via `/auth/me` on resume |
| selected branch id | `local_store` (prefs) | validated against `branchIds` on every launch |
| password | **never** | not even transiently beyond the login call |

## 5. Session state

```text
sealed SessionState
  ├── bootstrapping
  ├── unauthenticated(reason?)     // logout | expired | revoked
  ├── mustChangePassword(user)
  ├── branchRequired(user)
  ├── authenticated(user, branch, permissions)
  └── locked(user)                 // idle timeout / biometric
```

`SessionNotifier` owns transitions; `GoRouter.refreshListenable` watches it. **Idle timeout**
(configurable, default 15 min) uses a `Listener` on the app root to reset a timer on any
pointer event; `AppLifecycleState.paused` starts a background clock so backgrounding for an
hour also locks. On `LOCKED`, tokens stay in storage — unlock is biometric or password, not a
full re-login.

## 6. Branch context

`BranchContext` provider = `{company, branch, locations[], selectedLocation?}`.

- On selection: `GET /branches/{id}` + `GET /branches/{branchId}/locations`, cached for the
  session.
- Switching branch **invalidates every feature provider** (`ref.invalidate` on a branch-scoped
  family) so no Vientiane stock is ever shown under a Pakse header. This is the single most
  important correctness rule in the app.
- Branch shown persistently in `BranchContextBar`: `Institution › Branch › Location`.

**Institution/company name:** `UserResponse` has no company field. Resolution: read
`BranchResponse.companyId` → `GET /companies/{id}`. Flagged in the Phase 1 questions.

**Branch on requests:** backend takes `branchId` as an explicit query/body parameter
(`SecurityUtils.requireBranchAccess(branchId)`), not a header. `BranchContextInterceptor`
therefore injects `X-Branch-Id` for future use, while each repository passes `branchId`
explicitly. A single `ref.read(currentBranchIdProvider)` is the only source.

## 7. Permissions

`Permission` enum from the real backend codes (listed in Phase 1 §6), parsed leniently —
unknown server codes become `Permission.unknown(code)` rather than throwing, so the backend can
add permissions without breaking shipped apps.

```dart
hasPermission(Permission.inventoryTransfer)
hasAnyPermission([...])   hasAllPermissions([...])
```

Two widget policies, used deliberately:
- `PermissionGuard` — **hide** (nav tabs, quick actions, whole screens)
- `PermissionDisabled` — **show but disable** with an explanatory tooltip (an action inside a
  detail screen, where hiding it makes the UI look broken)

`superAdmin` in the JWT bypasses checks client-side to match the backend.

**Backend remains the authority.** A 403 anywhere still renders a clear "You do not have
permission" state rather than a crash — the UI's job is to avoid the dead end, not to enforce.

## 8. Security items

- Biometric unlock (`local_auth`) — opt-in in Settings, guards the `LOCKED` state only, never
  replaces login.
- `screen_guard.dart` applied to login, customer KYC, valuation and price screens
  (`FLAG_SECURE` on Android, blur-on-background on iOS).
- Logout calls `/auth/logout` with the refresh token, then clears storage regardless of the
  call's outcome (never strand a user on a failed logout).
- "Log out of all devices" wired to `/auth/logout-all`.
- Certificate pinning: interceptor seam defined; enable in Phase 17 once the production cert
  is known.

## 9. Screens

`LoginScreen` (branded, remembers username, show/hide password, offline-aware) ·
`ForcedChangePasswordScreen` · `BranchSelectorScreen` (searchable, grouped by company, shows
head-office badge) · `LockScreen` (biometric + password fallback) · `ProfileScreen` (user,
roles, permissions viewer, branch switch, logout, logout-all).

## 10. Deliverables & tests

Real login end-to-end; token persistence across cold start; proactive + reactive refresh;
single-flight verified; branch switch invalidating caches; permission gating live on nav.

Unit tests: token expiry maths, single-flight refresh under 6 concurrent 401s, permission
parsing with unknown codes, session state transitions, branch validation when a user's access
is revoked between sessions.
