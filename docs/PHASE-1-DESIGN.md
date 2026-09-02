# Phase 1 — Foundation: Design for Review

Scope: the skeleton only. No business functionality, no real API calls beyond the plumbing
needed to prove the stack works. Everything below is chosen so Phases 2–17 bolt on without
rework.

---

## 1. Decisions taken (please confirm these)

| Decision | Choice | Why |
|---|---|---|
| State management | **Riverpod 3 (code-gen off, manual providers)** | Compile-safe DI, trivial to scope per-branch, no BuildContext coupling. Async/Notifier covers every later phase. Chosen over BLoC to avoid event-class boilerplate across 17 feature modules. |
| Navigation | **GoRouter** with a typed route registry + `refreshListenable` on auth state | Declarative redirect guards (unauthenticated → login, no-branch → branch picker) live in one place. |
| Networking | **Dio** + interceptor chain | Auth, branch context, correlation id, retry, error mapping are all interceptors, added incrementally per phase. |
| Serialization | **`json_serializable` + `freezed`** | Immutable models with `copyWith`/equality; unions for UI state. |
| Secure storage | **`flutter_secure_storage`** (Keychain / EncryptedSharedPreferences) for tokens only; **Hive** (or `shared_preferences`) for non-secret prefs | Backend is the authority; the app never persists passwords. |
| Package layout | Feature-first, layered inside each feature (`data / domain / presentation`) | Matches the backend's module boundaries, keeps 15 features independent. |
| Min SDK | Flutter 3.44 / Dart 3.12 (installed), Android minSdk 23, iOS 13 | Required by secure storage + camera/ML-kit scanner in Phase 6. |

**Open question for you:** the backend is UUID-based and branch-scoped, but I found **no
global branch header** — `SecurityUtils.requireBranchAccess(branchId)` is called with a
branch id passed explicitly per endpoint. So the mobile app will hold the selected branch in
a `BranchContext` provider and pass it as an explicit query/body param per call, *and* also
send `X-Branch-Id` for future-proofing. Confirm whether you want the backend to later accept
a standard `X-Branch-Id` header so we can make it purely an interceptor concern.

---

## 2. Backend contract the foundation is built against

Read from `erp-backend`, so the mobile layer matches exactly:

**Success envelope** — every endpoint:
```json
{ "success": true, "data": { }, "message": null, "timestamp": "2026-09-01T..." }
```

**Error envelope** — `GlobalExceptionHandler`:
```json
{ "success": false, "code": "VALIDATION_FAILED", "message": "...", "path": "/api/v1/...",
  "correlationId": "...", "fieldErrors": [{"field":"username","message":"..."}],
  "timestamp": "..." }
```

**Paged envelope** — `PageResponse`: `content, page, size, totalElements, totalPages, last`.

**Error codes** (mapped 1:1 to a Dart enum): `VALIDATION_FAILED`, `BUSINESS_RULE_VIOLATED`,
`NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`, `CONCURRENT_MODIFICATION`,
`IDEMPOTENCY_CONFLICT`, `INTERNAL_ERROR`.

**Correlation id**: `X-Correlation-Id`, echoed back. The app generates one per request and
surfaces it on error screens — makes production support traceable.

**Auth endpoints** (`/api/v1/auth`): `login`, `refresh`, `logout`, `logout-all`,
`change-password`, `me`. `AuthResponse` = `accessToken, refreshToken, tokenType,
accessTokenExpiresAt, mustChangePassword, user`.

`UserResponse` = `id, username, fullName, email, phone, employeeCode, status,
primaryBranchId, branchIds[], roles[], permissions[], lastLoginAt`.

> Phase 1 defines these models and the interceptors but wires **only** a health/ping call.
> Real login lands in Phase 2.

---

## 3. Project structure

```text
lib/
├── main.dart                      # bootstrap → runApp(ProviderScope(child: JewelleryErpApp()))
├── app.dart                       # MaterialApp.router, theme mode, locale
│
├── core/
│   ├── config/
│   │   ├── app_config.dart        # immutable config object (baseUrl, env, timeouts, flags)
│   │   ├── environment.dart       # enum dev|staging|prod, --dart-define driven
│   │   └── app_config_provider.dart
│   ├── constants/
│   │   ├── app_constants.dart     # page size, debounce, timeouts, storage keys
│   │   ├── api_endpoints.dart     # every path in one file, versioned /api/v1
│   │   └── permissions.dart       # Permission enum mirroring backend codes (§6)
│   ├── network/
│   │   ├── dio_client.dart        # Dio factory + interceptor assembly
│   │   ├── api_client.dart        # thin typed wrapper: get/post/put/delete → ApiResponse<T>
│   │   ├── api_response.dart      # ApiResponse<T>, PageResponse<T> (freezed)
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart          # Bearer + 401 refresh queue (stub in P1)
│   │       ├── branch_context_interceptor.dart# X-Branch-Id from BranchContext
│   │       ├── correlation_id_interceptor.dart
│   │       ├── error_interceptor.dart         # ApiError JSON → AppException
│   │       ├── retry_interceptor.dart         # idempotent GET only, exp. backoff
│   │       └── logging_interceptor.dart       # redacts Authorization, non-prod only
│   ├── storage/
│   │   ├── secure_storage.dart    # tokens ONLY
│   │   ├── local_store.dart       # prefs: theme, locale, last branch, onboarding
│   │   └── cache_store.dart       # Phase-17 read-only cache seam (interface only in P1)
│   ├── security/
│   │   ├── session_manager.dart   # session state machine (§5), idle timeout
│   │   ├── biometric_service.dart # integration point, stubbed
│   │   └── screen_guard.dart      # FLAG_SECURE / iOS screenshot blur wrapper
│   ├── router/
│   │   ├── app_router.dart        # GoRouter + redirect guard
│   │   ├── app_routes.dart        # path + name constants (no magic strings)
│   │   └── route_guards.dart      # auth guard, branch guard, permission guard
│   ├── theme/
│   │   ├── app_theme.dart         # light + dark ThemeData (Material 3)
│   │   ├── app_colors.dart        # semantic tokens, not raw hex at call sites
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart       # 4pt scale, radii, elevation
│   │   └── theme_provider.dart    # persisted ThemeMode
│   ├── errors/
│   │   ├── app_exception.dart     # sealed: Network, Timeout, Unauthorized, Forbidden,
│   │   │                          #   NotFound, Validation, Conflict, Business, Unknown
│   │   ├── error_code.dart        # mirrors backend ErrorCode enum
│   │   └── error_mapper.dart      # DioException → AppException → user-facing message
│   └── utils/
│       ├── formatters.dart        # currency (LAK/USD), weight (g/ct), date, purity
│       ├── validators.dart
│       ├── debouncer.dart
│       ├── logger.dart            # levelled, crash-reporter seam
│       └── result.dart            # Result<T> success/failure
│
├── shared/
│   ├── models/                    # PagedRequest, SortSpec, IdName, Money, Weight
│   ├── extensions/                # BuildContext (theme/media/l10n), String, DateTime, num
│   ├── helpers/                   # snackbars, dialogs, sheet launchers, haptics
│   └── widgets/                   # §4
│
└── features/
    ├── authentication/            # P2 — login, branch selector, session
    ├── dashboard/                 # P3
    ├── jewellery/                 # P4 — search + digital passport
    ├── inventory/                 # P5
    ├── scanner/                   # P6 — barcode/QR/RFID
    ├── transfers/                 # P7
    ├── warehouse/                 # P8
    ├── procurement/               # P9
    ├── sales/                     # P10
    ├── customers/                 # P11
    ├── repairs/                   # P12
    ├── exchange/                  # P13
    ├── approvals/                 # P14
    ├── notifications/             # P15
    ├── reports/                   # P16
    └── settings/                  # profile, theme, environment, about
```

Each feature folder gets the same three-layer skeleton so later phases never argue about placement:

```text
features/<name>/
├── data/        # dto/, <name>_api.dart, <name>_repository_impl.dart
├── domain/      # entities, repository interface
└── presentation/# providers/, screens/, widgets/
```

Phase 1 creates each feature with only a `presentation/screens/<name>_placeholder_screen.dart`.

---

## 4. Reusable component library (`shared/widgets/`)

Built and demonstrated in Phase 1 on a hidden `/dev/components` gallery route (dev builds
only) so you can review the whole design system on one screen before any feature exists.

| Group | Widgets |
|---|---|
| Scaffolding | `AppScaffold`, `AppHeader` (title + branch chip + actions), `AppBottomNav` (permission-filtered), `AppDrawer` |
| Context | `BranchContextBar` (Institution › Branch › Location), `BranchSwitcherSheet`, `ConnectivityBanner` (online/offline/syncing/failed — Phase 17 states defined now) |
| Surfaces | `AppCard`, `SectionCard`, `AppBottomSheet`, `AppDialog`, `ConfirmationDialog`, `AppExpansionTile` |
| Data display | `KeyValueRow`, `StatTile`, `StatusBadge` (semantic status→colour map), `MetalPurityChip`, `AppTimeline` + `TimelineEvent`, `AppDataList`, `PaginatedListView` (infinite scroll + pull-to-refresh) |
| Input | `AppTextField`, `AppSearchField` (debounced), `AppDropdown`, `AppDatePicker`, `AppNumberField`, `QuantityStepper`, `FilterSheet` + `FilterChipBar`, `AppButton` (primary/secondary/danger/text, loading state) |
| Media | `AppNetworkImage` (cached, shimmer placeholder), `ImageViewer` (pinch-zoom, gallery), `ImageThumbStrip` |
| State | `AppLoader`, `SkeletonBox`/`SkeletonList` (shimmer), `EmptyState` (icon+title+message+action), `ErrorState` (message + correlation id + retry), `AsyncValueView<T>` — one widget that maps a Riverpod `AsyncValue` to skeleton/error/empty/data |
| Access | `PermissionGuard` (hide), `PermissionDisabled` (show-but-disable + tooltip), `RoleBuilder` |

`AsyncValueView<T>` is the load-state contract for every future screen — it is why the
loading/empty/error work is done once, in Phase 1.

---

## 5. Session & routing state machine

```text
                 ┌──────────────┐
   app start ───▶│ BOOTSTRAPPING│  read secure storage, config, theme
                 └──────┬───────┘
              no token  │  token present
        ┌───────────────┴────────────────┐
        ▼                                ▼
 ┌─────────────┐                 ┌────────────────┐
 │UNAUTHENTICATED│               │  AUTHENTICATED │
 │  → /login     │               └───────┬────────┘
 └─────────────┘                          │
        ▲                    branches > 1 & none selected
        │                                 ▼
        │                        ┌──────────────────┐
        │                        │ BRANCH_REQUIRED  │ → /select-branch
        │                        └───────┬──────────┘
        │                                ▼
        │                          ┌──────────┐
        │  logout / 401 / expiry    │  READY   │ → /dashboard
        └───────────────────────────┤          │
                                    └────┬─────┘
                                idle timeout / biometric on
                                         ▼
                                  ┌─────────────┐
                                  │   LOCKED    │ → /lock
                                  └─────────────┘
```

GoRouter's `redirect` reads this single `SessionState` — no per-screen auth checks anywhere.
Phase 1 ships the machine with a fake in-memory auth so the flow is walkable; Phase 2 swaps
the implementation behind the same interface.

**Routes registered in Phase 1** (all placeholders except the shell + gallery):

```text
/splash  /login  /select-branch  /lock
/dashboard                          (shell tab 1)
/inventory   /inventory/:id         (shell tab 2)
/scan                               (shell tab 3, centre FAB)
/transfers   /transfers/:id         (shell tab 4)
/more                               (shell tab 5)
  ├── /warehouse  /procurement  /customers  /repairs
  ├── /exchange   /approvals    /reports
  └── /notifications  /profile  /settings
/dev/components                     (dev builds only)
```

Bottom nav is a `StatefulShellRoute` (independent stack per tab) and its items are filtered
by permission, so a warehouse-only user never sees a Sales tab.

---

## 6. Permission model

Dart `Permission` enum mirrors the backend codes exactly — these are the real ones I read
out of the backend, not the illustrative list in the phase doc:

```text
INVENTORY_VIEW  INVENTORY_CREATE  INVENTORY_ADJUST  INVENTORY_RESERVE
INVENTORY_TRANSFER  INVENTORY_TRANSFER_APPROVE
PRODUCT_VIEW  PRODUCT_CREATE  PRODUCT_UPDATE  PRICE_CHANGE
GEMSTONE_VIEW  GEMSTONE_MANAGE  METAL_VIEW  METAL_MANAGE  METAL_RATE_PUBLISH
WAREHOUSE_VIEW  WAREHOUSE_MANAGE
STOCK_COUNT_PERFORM  STOCK_COUNT_APPROVE
PROCUREMENT_VIEW  PROCUREMENT_CREATE  PROCUREMENT_APPROVE  PROCUREMENT_RECEIVE
SUPPLIER_VIEW  SUPPLIER_MANAGE
SALE_VIEW  SALE_CREATE  SALE_RETURN  DISCOUNT_REQUEST  DISCOUNT_APPROVE
CUSTOMER_VIEW  CUSTOMER_MANAGE  CUSTOMER_KYC_VERIFY  CRM_VIEW  CRM_MANAGE
LOYALTY_VIEW  LOYALTY_MANAGE  LOYALTY_REDEEM  LOYALTY_ADJUST  CAMPAIGN_MANAGE
REPAIR_VIEW  REPAIR_ESTIMATE  REPAIR_PROCESS
EXCHANGE_VIEW  EXCHANGE_VALUE  EXCHANGE_PROCESS  EXCHANGE_APPROVE
PAYMENT_VIEW  PAYMENT_COLLECT  PAYMENT_REFUND  PAYMENT_RECONCILE
FINANCE_VIEW  FINANCE_POST  FINANCE_MANAGE
REPORT_VIEW  COMPLIANCE_REPORT  AUDIT_VIEW
NOTIFICATION_VIEW  NOTIFICATION_MANAGE
FILE_UPLOAD  FILE_DOWNLOAD
ORGANIZATION_VIEW  ORGANIZATION_MANAGE  USER_VIEW  USER_MANAGE  ROLE_VIEW  ROLE_MANAGE
```

API: `ref.watch(hasPermissionProvider(Permission.inventoryTransfer))`, plus
`PermissionGuard`/`PermissionDisabled` widgets. Unknown codes from the backend are parsed
into an `unknown` variant rather than throwing — the backend can add permissions without
breaking deployed apps. **The UI only hides and disables; the backend stays the authority.**

---

## 7. Design system

Not a consumer shopping app — enterprise tool with a premium finish.

- **Colour**: near-black/deep-charcoal neutral base with a restrained champagne-gold accent
  used *only* for primary actions and selection, never as decoration. Semantic tokens:
  `success` (in stock / approved), `warning` (pending / in transit), `danger` (rejected /
  shortage), `info` (draft), `vault` (secured). Full light + dark palettes; every colour is
  a token, never a literal at a call site.
- **Type**: single family (Inter or Plus Jakarta Sans), tabular figures for all monetary and
  weight values so column-aligned lists don't jitter.
- **Density**: 4pt spacing scale, 12pt card radius, 1dp hairline dividers, elevation used
  sparingly. Comfortable one-handed touch targets (min 48dp) — staff use this on a counter.
- **Motion**: 150–250ms, functional only.
- **Responsive**: phone-first with a `Breakpoints` helper; ≥600dp gets two-pane list/detail
  (tablet in the vault/warehouse is a real use case for Phase 8).
- **A11y**: contrast ≥ 4.5:1, semantic labels on icon buttons, text scaling to 1.3× without
  clipping.

---

## 8. Configuration & build

- `--dart-define` for `ENV` and `API_BASE_URL`; three flavours (dev/staging/prod) with
  distinct app ids, names and icons so a staging build can't be mistaken for production.
- **No secrets in the app.** Config holds only base URLs and feature flags.
- `logger.dart` and `crash_reporter.dart` are seams — real Sentry/Crashlytics wiring is
  Phase 17, but call sites exist from day one.
- App version check endpoint hook defined, unimplemented.

---

## 9. Deliverable of Phase 1

1. Flutter project created, dependencies pinned, analysis options + lints strict.
2. Full folder tree with every file above created and compiling.
3. Theme (light + dark) and the full component gallery, reviewable at `/dev/components`.
4. GoRouter with all routes, shell nav, and the session/permission guards, walkable with
   fake auth.
5. Dio stack with all interceptors and the error mapper, verified against a real backend
   ping.
6. All 15 feature folders scaffolded with placeholder screens.
7. `flutter analyze` clean; a handful of smoke tests (theme builds, router redirects,
   error mapper cases).

**Not in Phase 1:** real login, any business API call, scanner hardware, offline cache.

---

## 10. Things I'd like your decision on

1. **Branch header** — confirm the `X-Branch-Id` approach in §1, or tell me branch stays an
   explicit per-endpoint parameter only.
2. **Currency & locale** — LAK primary? Do we need Lao/English localisation from Phase 1
   (cheap now, expensive to retrofit), or English-only for the MVP?
3. **Riverpod vs BLoC** — confirm Riverpod, since it is irreversible in practice by Phase 5.
4. **Institution/tenant** — `UserResponse` exposes branches but no institution name. Is there
   a company/tenant endpoint the header bar should read, or do we derive it from the branch?
5. **Package name / app id** — e.g. `com.finotech.jewellery.mobile`?
