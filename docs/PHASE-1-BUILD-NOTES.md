# Phase 1 — Build Notes

What was actually built, what was verified, and what is deliberately not done yet.

## Decisions taken (as authorised)

| Item | Decision |
|---|---|
| State management | Riverpod 2 (`flutter_riverpod`), `Notifier`/`NotifierProvider` |
| Application id | `com.finotechsoftware.jewelleryapp` (Android + iOS aligned) |
| Languages | English (source), Lao, Thai — all three live |
| Currencies | LAK (primary, 0 decimals), USD, THB, INR |
| Institution name | Resolved from `branch.companyId` → `GET /companies/{id}`, cached per session. **No backend change needed.** |

## Two things worth knowing

**Fonts are vendored, not fetched.** I dropped the `google_fonts` package. It downloads faces
over the network on first use, which is wrong for an app that has to work in a warehouse on
poor connectivity and must not make an unexpected outbound request on launch. Inter (5 weights)
plus Noto Sans Lao, Noto Sans Thai and Roboto Mono now ship as assets — about 2 MB.

Inter carries no Lao or Thai glyphs, so those scripts are wired as `fontFamilyFallback` on every
style. Without that, Lao and Thai text renders as empty boxes on any device lacking a system
face. Verified on the simulator: Lao navigation labels render correctly.

**Build flavours.** `dev` / `staging` / `prod` with distinct application ids and app names, so a
staging build is unmistakable on a home screen.

## What is real

- **Session state machine** — bootstrapping → unauthenticated → mustChangePassword →
  branchRequired → authenticated → locked, with idle timeout (15 min, configurable) and a
  background clock so backgrounding for an hour also locks.
- **Route guards** — one redirect rule for the whole app, reading only the session. No screen
  performs its own authentication check.
- **Permission system** — all ~65 backend codes; unknown codes are preserved, not dropped, so
  the backend can add a permission without a shipped app discarding it. Navigation, quick
  actions and dashboard tiles all filter on permissions. **No role string appears anywhere.**
- **Network stack** — Dio with correlation-id, branch-context, auth (proactive refresh from
  `accessTokenExpiresAt` plus single-retry 401 recovery), retry (idempotent methods only),
  logging (redacting) and error-mapping interceptors. `ApiClient` unwraps the backend's
  `ApiResponse` / `PageResponse` envelopes.
- **Error model** — the backend's nine `ErrorCode` values mapped to a sealed Dart hierarchy,
  with `fieldErrors` and `correlationId` carried through to the error UI.
- **Theme** — 6 accent palettes × light/dark/system, all persisted. Semantic status colours are
  a `ThemeExtension` so they never derive from the accent.
- **Component library** — cards, status badges, stat tiles, timeline, inputs, search with scan
  affordance, buttons, skeletons, empty/error/permission states, dialogs, sheets, permission
  widgets, and `AsyncValueView<T>` as the one load-state contract for every future screen.
- **Component gallery** at `/dev/components` (non-production builds), so the whole design
  system can be reviewed in both themes and all three languages before features are built.

## Verified on an iPhone 16 Pro simulator

- Cold start → login → dashboard, signed in as the `warehouse` profile
- Permission filtering: warehouse staff see Operations + Account only in "More"; no Sales,
  Customers, Repairs, Approvals or Reports, and no Customer/Repair quick actions
- All four currencies format correctly (LAK without decimals, the rest with two)
- Dark mode + Royal Emerald + Lao, all at once
- 43 tests passing, `flutter analyze` clean

Two layout bugs were found and fixed during this verification: hidden permission-gated tiles
were still occupying grid cells (leaving holes), and hidden quick actions were still
contributing list separators. Both now filter the list before building rather than blanking
out a child.

## Development sign-in

Phase 1 ships `DevAuthRepository`, registered only outside production. Any password is
accepted; the **username** selects a permission profile:

```
sales      · view inventory, reserve, customers, CRM         1 branch
warehouse  · inventory, transfers, stock count, receiving    3 branches
repair     · repairs, estimates, file upload                 1 branch
manager    · everything                                      3 branches
newuser    · triggers the forced password-change flow
```

Phase 2 replaces this class with the Spring Boot client. Nothing else changes — the session
machine, guards and permission gating are already final.

## Known gaps (deliberate)

- **Dashboard strings are hardcoded English.** The l10n infrastructure is live and proven
  (navigation, settings, all state widgets translate), but the dashboard's own copy —
  "Quick actions", "Needs your attention", the quick-action labels — was not added to the ARB
  files because Phase 3 rebuilds that screen entirely. Worth doing then, not twice.
- **No real API call yet.** The Dio stack is assembled and unit-tested but nothing calls the
  backend until Phase 2.
- **Biometric unlock is a stub.** The lock screen and its state transitions are real; the
  credential check is not. Phase 2.
- **Certificate pinning is a seam.** `AppConfig.certificatePins` exists and is empty; wiring is
  Phase 17, once the production certificate is known.
- **iOS flavours not configured.** Android has dev/staging/prod schemes; iOS needs matching
  Xcode configurations before a staging TestFlight build.

## Commands

```bash
flutter run --dart-define=ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8080
flutter test
flutter analyze
flutter build apk --release --flavor prod --dart-define=ENV=prod --dart-define=API_BASE_URL=https://api.example.com
```

The Android emulator reaches a host-machine backend at `10.0.2.2`; an iOS simulator uses
`localhost`.
