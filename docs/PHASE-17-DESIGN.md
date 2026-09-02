# Phase 17 — Offline Awareness & Production Hardening: Design for Review

## 1. Connectivity model

```text
sealed ConnectivityState
  ├── online
  ├── offline            no transport
  ├── degraded           transport up, API unreachable or very slow
  ├── syncing(progress)
  └── syncFailed(reason)
```

`connectivity_plus` gives transport; it is **not** sufficient — showroom wifi that resolves but
can't reach the API is the common case. So a lightweight reachability probe against a cheap
endpoint (`/actuator/health` or `/auth/me`) with backoff distinguishes `offline` from
`degraded`. A persistent `ConnectivityBanner` shows the state; `online` shows nothing.

## 2. Caching policy — read-only, by design

Cached (encrypted, TTL'd, cleared on logout and branch switch):

| Data | TTL | Why |
|---|---|---|
| User profile, permissions | session | needed to render anything |
| Branches, locations, bins | 24h | small, slow-changing |
| Metals, purities, categories, types | 24h | the Phase 4 reference cache |
| Products, designs | 12h, LRU 500 | resolves the UUID→name problem offline |
| Recently viewed items (last 50) | 1h | a scanned item stays readable |
| Recently viewed customers | id + name only | **no PII cached** |
| Metal rates | **not cached** | a stale rate is a financial error |
| Prices, valuations | **not cached** | same |

Every cached screen shows an explicit "Offline · last updated 14:20" banner. There is no silent
serving of stale data — staff must know whether the number in front of them is live.

## 3. What is never queued offline

Per the spec, and enforced structurally: a mutating call made while offline fails fast with a
clear "You're offline. This action needs a connection." state, not a queue.

```text
Never queued: sale, payment, transfer submit/dispatch/receive, goods receipt,
              exchange/buyback any step, approval of anything, reservation,
              status change, stock count submit, repair status change
```

The reason is stated in the spec and is correct: the backend has idempotency support on only
three endpoints (`/sales`, `/payments`, `/procurement/goods-receipts` via `X-Idempotency-Key`)
and no offline reconciliation design. Queuing an inventory transfer offline and replaying it an
hour later would create phantom stock.

**The one exception, already designed in:** the **stock count session** (Phases 5 and 8)
accumulates scans locally and submits as a single call. That is safe precisely because no
server state changes until submit. Same for **receiving reconciliation** and **goods-receipt
drafts** — local drafts, single atomic submit, never a background replay.

`OfflineGuard` is a single wrapper every mutating repository call passes through, so this rule
cannot be forgotten in one feature.

## 4. Security hardening

| Item | Implementation |
|---|---|
| Token storage | Keychain (`first_unlock_this_device`) / EncryptedSharedPreferences; never in prefs or logs |
| Session timeout | idle 15 min (configurable) + background clock; → `LOCKED` |
| Biometric unlock | `local_auth`, opt-in, guards `LOCKED` only, password fallback always available |
| Screenshot / privacy | `FLAG_SECURE` + iOS blur-on-background on login, KYC, valuation, price, reports, approvals |
| Secure logout | `/auth/logout` → clear secure storage → clear caches → deregister push token → reset providers, in that order, and unconditionally even if the API call fails |
| Certificate pinning | SHA-256 SPKI pins in `DioClient`, with a documented rotation procedure and a backup pin |
| Root/jailbreak | detect and warn (configurable to block) — a device holding vault authority warrants it |
| Document access | certificates and KYC documents fetched per-view, opened from a temp file, deleted after; never persisted to the gallery or Downloads |
| Clipboard | sensitive fields excluded from clipboard where the platform allows |
| Logging | `Logger` redacts `Authorization`, tokens, passwords, document numbers; release builds log warn+ only |
| Secrets | none in the app; config holds base URLs and flags only |

Screen guard is opt-**in** per screen but the list above is enforced by a test that asserts each
named route is wrapped.

## 5. Performance

- **Images** — `cached_network_image`, memory + disk cache sized to device, correct
  `cacheWidth`, shimmer placeholders, cancellation on scroll-away.
- **Lists** — `ListView.builder` everywhere, `itemExtent` where fixed, `const` widgets,
  `RepaintBoundary` on cards, provider `select` to avoid whole-list rebuilds.
- **Pagination** — 20/page, prefetch at 80% scroll, `PageResponse.last` as the terminator.
- **Search** — 350 ms debounce + `CancelToken` on the superseded request.
- **API** — 60 s cache for dashboard, 5 min for reports, ETag support if the backend adds it,
  gzip on, connection reuse, parallel fan-out with a concurrency cap of 4.
- **Scanner** — camera resolution capped for decode speed, decoder throttled, session released
  on background; the single hottest path in the app.
- **Startup** — deferred non-critical init, splash until the session resolves only.

Budgets to hold: cold start < 2 s to first frame, search results < 400 ms after response,
scan→passport < 1 s, list scroll without dropped frames on a mid-range Android.

## 6. Production

- **Flavours** dev / staging / prod: distinct application ids, names, icons and base URLs via
  `--dart-define`. A staging build must be unmistakable on the home screen.
- **Android**: minSdk 23, target latest, R8 + shrinking, app bundle, signing config documented
  outside the repo.
- **iOS**: deployment target 13, bitcode off, camera / biometric / notification usage strings.
- **Crash & error reporting**: `CrashReporter` seam wired to Sentry (recommended) or
  Crashlytics; PII scrubbing before send; `correlationId` attached to every API error so a
  mobile crash can be tied to a backend request.
- **Logging strategy**: levelled, structured, in-memory ring buffer exportable from Settings →
  Diagnostics for support (redacted), never auto-uploaded.
- **Version check**: on launch, hit a version endpoint (**does not exist — needs adding**,
  e.g. `GET /api/v1/app/version?platform=`) returning `minSupported` / `latest` / `storeUrl`.
  Below `minSupported` → blocking update screen. This matters because a mobile client with a
  stale understanding of a financial workflow is a liability you cannot recall.
- **Environment switcher** in dev/staging builds only, behind a hidden gesture.

## 7. Accessibility & localisation

Contrast ≥ 4.5:1 in both themes, semantic labels on every icon-only control, text scaling to
1.3× without clipping, minimum 48 dp targets, screen-reader pass on the primary flows.

Localisation: `flutter_localizations` + ARB. **Decide in Phase 1** whether Lao is in scope —
retrofitting 60 screens is expensive. All money, weight and date formatting already goes
through `Formatters` with an explicit locale, so the plumbing is ready either way.

## 8. Release checklist (deliverable of this phase)

Analyzer clean · tests green · no `print`/`debugPrint` in release · no hardcoded URLs or
secrets · pinning verified against staging · screen guard verified on the named routes ·
logout clears everything (verified by test) · offline states verified per screen · crash
reporting verified · both store builds produced and installed on real devices · a documented
rollback plan.
