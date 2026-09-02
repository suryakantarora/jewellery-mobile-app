# Phase 2 — Build Notes

Authentication wired to the live Spring Boot backend and verified end to end.

## Environment

The backend runs on **`:8081`**, not `:8080`. Dev defaults updated: Android emulator gets
`10.0.2.2:8081`, iOS simulator `localhost:8081`. Override with
`--dart-define=API_BASE_URL=...`.

## The contract matched

Pulled the live OpenAPI spec and compared it with the models written in Phase 1.
`AuthResponse`, `UserResponse`, `BranchResponse`, `LocationResponse` and the error envelope all
matched with no rework. A bad-credentials response comes back as
`{"success":false,"code":"UNAUTHORIZED","message":"Invalid username or password","correlationId":"..."}`,
which `ErrorMapper` already handled.

Two useful fields the spec surfaced, now on the models:

- `CompanyResponse.baseCurrency` — the institution's own trading currency, better than a device
  default where the app has to pick one.
- `LocationResponse.dualAuthorization` — the flag Phase 8's high-value vault flows need.

## Corrections to the earlier design docs

Comparing `identity.permission` (67 rows) against the enum produced two corrections. The
originals came from grepping Java source for quoted upper-case tokens, which was too blunt.

- **`VAULT_MOVEMENT` and `BUYBACK_VALUATION` are not permissions.** They are `control_type`
  string literals inside a compliance dual-authorisation SQL report. Removed. Buyback valuation
  is gated by `EXCHANGE_VALUE`, same as an exchange.
- **`DISCOUNT_REQUEST` and `DISCOUNT_APPROVE` do exist** and are granted to `SUPER_ADMIN`.
  They are seeded in a migration and never referenced by any `hasAuthority(...)` annotation —
  which is itself the finding: the permissions are defined but **nothing enforces them**,
  because no discount-approval endpoint exists.

The enum now matches the permission table **1:1, 67 for 67**, asserted by a test so drift fails
the build.

## Built

- **`AuthApi`** on a deliberately isolated `Dio` with **no auth interceptor**. Login and refresh
  must never carry a bearer token, and a refresh routed through the interceptor chain would
  recurse into the very refresh it is performing.
- **`SessionTokenProvider`** — single-flight refresh, plus in-memory token caching so the common
  path does not hit the keychain per request. Wired to the session controller through a
  callback, so the token layer never imports Riverpod.
- **`ApiAuthRepository`** — replaces `DevAuthRepository` behind the same interface. The session
  machine, route guards and permission gating from Phase 1 were not touched.
- **Real `POST /auth/change-password`** on the forced-change screen, with the `currentPassword`
  field the backend requires.
- `DevAuthRepository` still exists but is **off by default** — it needs
  `--dart-define=USE_DEV_AUTH=true` and is ignored entirely in production builds.

## Bug found and fixed: super admins were locked out

`SUPER_ADMIN` carries `branchIds: []` yet may act in **every** branch. The session controller
short-circuited to the "no branch assigned" state on an empty `branchIds` before ever consulting
the branch list — so every super admin would have been locked out of the app the moment a branch
existed. The branch list is now the authority for super admins. Regression test added.

This was only visible because the live account is a super admin with no branches; no amount of
compiling would have surfaced it.

## Verified against the live backend

- `POST /auth/login` with real credentials → token stored in the keychain
- **Cold start with no credentials typed** → session restored from the stored token via
  `/auth/me`, resuming at the correct state. Token persistence works.
- `admin` has no branches, so the app correctly shows the "no branch assigned" state rather than
  a dashboard
- 60 tests passing, `flutter analyze` clean

The single-flight refresh test is the one worth keeping: six concurrent requests on an expired
token collapse to **one** refresh call. Six would race, and five would replay a refresh token
the backend had already rotated — signing someone out mid-shift.

## Also fixed

- The login screen's development hint claimed "any password · sales · warehouse · repair ·
  manager" even when the build was talking to a real backend. It now shows the sign-in profiles
  only when `USE_DEV_AUTH` is on, and otherwise displays the API base URL. Claiming "any
  password" against a live server would send someone chasing a login failure that was never a bug.
- The no-branch empty state showed the generic "when there is something to show, it will appear
  here", which reads as a loading state rather than a dead end.
- Replaced scattered `// ignore:` comments with a proper `analysis_options.yaml`.

## Two bugs only running the app could find

**iOS autocorrect was rewriting usernames.** Typing `khamla` into the username field produced
`khanka`, which the backend correctly rejected — presenting to the user as a wrong password
rather than a mangled field. Autocorrect, suggestions and autocapitalisation are now off on the
username field and on `AppSearchField`, which will carry item codes, barcodes and RFID tags
from Phase 4 onward. That one would have been a support nightmare in a showroom.

**The iOS Keychain survives app deletion.** Preferences are wiped on uninstall; Keychain items
are not. A reinstalled app therefore found credentials from the previous installation, tried to
restore a revoked session, and greeted the user with "Your session has expired" on what was, to
them, a brand-new install. `SecureStorage.clearIfFreshInstall` now wipes credentials when the
install marker is absent from preferences — the absence being a reliable signal of a genuine
first run. Two regression tests cover it.

## Verified end to end against the live backend

Signed in as `khamla` (Branch Manager, 3 branches, 54 permissions):

```
login (real credentials)
  → forced password change   POST /auth/change-password
  → session established
  → company resolved         GET /companies/{id} from branch.companyId
  → "ABC Jewellery › Vientiane Showroom"
  → branch switcher shows all 3 real branches, head-office badge, current selection
  → switched to Pakse; context bar updated
```

Also verified: sign-out clears the session and returns to login; a cold start with no
credentials typed restores the session from the stored token.

## Seed data created

Created through the API with the admin token, as authorised:

```
Company   ABC Jewellery (ABC), baseCurrency LAK
Branches  VTE Vientiane Showroom (head office) · PKS Pakse Showroom · CWH Central Warehouse
Locations VTE: SHW, CTR1, VLT(dual)   PKS: PKS-SHW, PKS-VLT(dual)
          CWH: MAIN, CWH-STG, CWH-VLT(dual)
Users     password Staff@2026! (all forced to change on first sign-in)
          somchai  SALES_EXECUTIVE    VTE                24 permissions
          bounma   INVENTORY_OFFICER  VTE, CWH           18 permissions
          khamla   BRANCH_MANAGER     VTE, PKS, CWH      54 permissions
          noy      AUDITOR            VTE, PKS           23 permissions
```

`khamla`'s password is now `Khamla@2026!` — changed during the forced-change test.

**Backend finding:** `organization.location` has `UNIQUE (code)` — location codes are unique
*globally*, not per branch. Every branch naturally wants a `VLT` and a `SHW`, so the seed data
uses branch-prefixed codes as a workaround. This should almost certainly be
`UNIQUE (branch_id, code)`. Related: posting a location with a malformed enum value returns
`INTERNAL_ERROR` (500) rather than a validation error.

## Still outstanding

The database has **no companies and no branches** — only the bootstrap `admin` user. So
branch selection → dashboard cannot be exercised, and neither can anything in Phases 3+, all of
which is branch-scoped.

Needed before Phase 3 is meaningful:

```
1 company
1+ branches, with locations
1+ non-admin users assigned to those branches
```

Created through the admin portal, or via the API with the admin token.
