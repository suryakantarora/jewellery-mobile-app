# Build Log — Changes, Challenges and Blockers

A running record, updated as each phase completes. Purpose: keep the decisions,
the bugs that cost real time, and anything still blocked on a decision in one
place — so none of it has to be rediscovered later.

**Conventions**
- 🔴 **Blocked** — needs a decision or backend change; the phase shipped around it
- 🟡 **Worked around** — shipped, but the workaround should be revisited
- 🟢 **Resolved** — found and fixed

Backend: Spring Boot on `:8081`. Postgres on `:5433`. Live data seeded (see Phase 2).

---

## Phase 1 — Foundation

**Shipped:** project structure, session state machine, route guards, permission
system (all 67 codes), Dio stack with six interceptors, error model, theme
(6 palettes × light/dark), component library, `AsyncValueView<T>`, component
gallery at `/dev/components`, i18n in English/Lao/Thai, 4 currencies.

### Decisions
- **Riverpod** over BLoC, confirmed by the user. Irreversible in practice by now.
- **Fonts vendored, not fetched.** Dropped `google_fonts`: it downloads faces
  over the network on first use, wrong for an app that works in a warehouse.
  Inter + Noto Sans Lao + Noto Sans Thai + Roboto Mono ship as assets (~2 MB).
- **Inter has no Lao or Thai glyphs**, so both are wired as `fontFamilyFallback`
  on every text style. Without it those scripts render as empty boxes.
- **Themes beyond dark mode:** 6 accent palettes, each with separate light and
  dark seeds so colour keeps its chroma on dark surfaces.

### 🟢 Bugs found by running the app
1. **Permission-gated grid tiles left holes.** A guard returning an empty widget
   still occupies its grid cell. Filtering must happen *before* the grid is
   built, not inside it. Same bug in the quick-actions row, where hidden items
   still contributed list separators.
2. **Brand mark stretched flat** — the painter lays out from its width, so an
   unbounded box distorted it. Fixed with `SizedBox.square`.

---

## Phase 2 — Authentication

**Shipped:** real login, single-flight token refresh, proactive refresh from
`accessTokenExpiresAt`, forced password change, branch selection and switching,
institution resolution, secure logout.

### 🟢 Bugs found by running the app
1. **Super admins were locked out.** `SUPER_ADMIN` carries `branchIds: []` yet
   may act in every branch. The session controller short-circuited to "no branch
   assigned" before consulting the branch list — every super admin would have
   been blocked the moment a branch existed. Regression test added.
2. **iOS autocorrect rewrote usernames.** Typing `khamla` produced `khanka`,
   which the backend rejected — reading to the user as a wrong password rather
   than a mangled field. Autocorrect, suggestions and autocapitalisation are now
   off on the username field and on `AppSearchField` (which carries item codes
   and scanned tags).
3. **The iOS Keychain survives app deletion.** Preferences do not. A reinstalled
   app found credentials from the previous install and showed "session expired"
   on what was, to the user, a brand-new install. `clearIfFreshInstall` now wipes
   credentials when the preferences marker is absent.

### 🟢 Corrections to my own earlier analysis
- **`VAULT_MOVEMENT` and `BUYBACK_VALUATION` are not permissions.** They are
  `control_type` string literals inside a compliance SQL report; my original
  grep for quoted upper-case tokens swept them up. Buyback valuation is gated by
  `EXCHANGE_VALUE`.
- **`DISCOUNT_REQUEST` / `DISCOUNT_APPROVE` do exist**, seeded in a migration and
  never referenced by any `hasAuthority(...)`. So the permissions are defined but
  **nothing enforces them** — there is no discount-approval endpoint.
- The enum now matches `identity.permission` **1:1, 67 for 67**, asserted by a
  test so drift fails the build.

### Seed data created (authorised by the user)
```
Company   ABC Jewellery (ABC), baseCurrency LAK
Branches  VTE Vientiane Showroom (HO) · PKS Pakse Showroom · CWH Central Warehouse
Locations VTE: SHW, CTR1, VLT(dual)   PKS: PKS-SHW, PKS-VLT(dual)
          CWH: MAIN, CWH-STG, CWH-VLT(dual)
Users     password Staff@2026! (forced change on first sign-in)
          somchai SALES_EXECUTIVE   VTE            24 permissions
          bounma  INVENTORY_OFFICER VTE,CWH        18 permissions
          khamla  BRANCH_MANAGER    VTE,PKS,CWH    54 permissions   → now Khamla@2026!
          noy     AUDITOR           VTE,PKS        23 permissions
admin / Admin@2026!  SUPER_ADMIN, 67 permissions, no branches
```

### 🔴 Backend issues raised
- `organization.location` has **`UNIQUE (code)` globally, not per branch**. Every
  branch wants a `VLT` and `SHW`; the second branch onward cannot use natural
  codes. Should be `UNIQUE (branch_id, code)`. Worked around with prefixed codes.
- **Missing required params return 500, not 400.** `GET /metal-rates/current`
  without `metalId`/`purityId`, and `POST /locations` with a bad enum, both
  produce `INTERNAL_ERROR`. Makes a client bug look like a server outage.
- Null fields are **omitted** rather than sent as null (`primaryBranchId` is
  simply absent). Every parser already reads with `as String?`; future ones must.

---

## Phases 3–6 — Dashboard, Passport, Inventory, Scanner

Built together because they interlock: search and inventory both route into the
passport, and all three route into the scanner.

**Shipped:** role-aware dashboard on live figures · reference-data cache ·
item search with exact-match scan shortcut · digital passport with lifecycle
timeline · inventory with grouping and multi-select · scanner abstraction with
camera implementation, RFID contract, shared `ScanSession`.

### Seed data added (authorised)
```
3 metals (Gold/Silver/Platinum) · 6 purities (24K 22K 18K 14K 925 PT950)
6 categories · 7 product types · 8 designs · 10 products
10 metal rates (BUYING + SELLING, all published today)
40 jewellery items — 34 AVAILABLE, 6 DRAFT, spread across VTE/PKS/CWH,
   each with RFID + QR + barcode + hallmark
```

### 🟢 The bug that cost the most time: a self-deadlocking Future

Every request returned **200**, yet the inventory list sat on skeletons forever.
The cause was one line in the reference cache:

```dart
.whenComplete(() => _productLoads.remove(id))
```

`whenComplete` **waits on a Future its callback returns**, and `Map.remove`
returns the removed value — which here *is* the future being chained. So each
product load waited on itself. It never completed and never threw, so there was
nothing in the logs and no error state to render.

Fixed by clearing the in-flight entry in a `finally` block and discarding the
removed value explicitly. Seven regression tests added, including a timeout
guard that fails rather than hangs. Worth remembering: **a hung screen with
clean logs and 200s is the signature of an awaited-future cycle**, not a
network problem.

### 🟢 Other bugs found by running it
1. **`ref.watch` after an `await`** inside `AsyncNotifier.build()` re-registered
   the dependency each rebuild, producing a loop that recreated the reference
   service and re-fetched every product (40 requests instead of 10). All
   dependencies are now read before the first await.
2. **`CancelToken` in `build()` raced Riverpod's own supersession** — a rebuild
   could cancel the request belonging to the build about to become current.
   Removed; the notifier already discards stale builds, and debounce keeps
   request volume down.
3. **`ItemSearchFilters` had no `==`**, so an identical filter set counted as a
   change and re-ran every dependent query.
4. **Dashboard showed `?` for currency** — the valuation report does not echo
   one. Now falls back to the institution's `baseCurrency`.
5. **"18 sales" on the stock-value tile** was actually an item count. Captions
   are now declared per tile rather than inferred from "is this money".

### Decisions
- **One inventory screen with a grouping selector**, not the six screens the
  specification lists — they are the same query with different filters.
- **Group totals are fetched per group** and shown as "6 of 42" until the real
  figure arrives, so a loaded window never reads as the whole.
- **Barcode and QR are one camera pipeline** with a format filter, because
  that is how decoders work and `by-tag` accepts any of them.
- **No price-range filter.** `GET /inventory/items` has no `minPrice`/`maxPrice`
  and filtering a paged list client-side would misreport the result count.
- **Lifecycle timeline renders real `LifecycleEvent`s**, not the fixed ladder in
  the specification — real items skip and repeat steps.

### 🟡 Worked around
- **No image field exists** on item, product or design. Thumbnails use the
  category icon tinted by metal colour, which at least distinguishes a gold ring
  from a silver chain. Real images need `imageKeys[]` on the backend.
- **Dashboard is 7 parallel calls** with per-tile failure isolation, because
  there is no summary endpoint. One 403 blanks one tile, not the screen.

### 🔴 Blocked — needs your input or a device
- **The scanner cannot be verified on this simulator.** `mobile_scanner` pulls
  in Google ML Kit, which ships no arm64 simulator slice, so the camera preview
  cannot run on an Apple Silicon simulator. The code paths (normalisation,
  debounce, session, feedback, not-found handling) are unit-testable and built,
  but **camera scanning must be verified on a physical device or an Android
  emulator**. Nothing to decide — just noting it cannot be signed off here.
- **`GET /metal-rates/current` requires `metalId` and `purityId`**; omitting
  them returns 500 rather than 400. Rates are seeded and readable with the
  params supplied.
---

## Phase 7 — Inventory Transfer

**Shipped:** transfer list (Incoming/Outgoing/All), detail with status-driven
actions, approve/reject/dispatch, and the scan-based receive-and-reconcile flow.

### 🟢 Discovered: the backend enforces dual authorisation
Approving a movement into a `dualAuthorization` location left it at
`PENDING_APPROVAL` with `approvedBy` set. A second approval attempt **by the
same user** returned:

```
CONFLICT: This movement needs a second, different approver
```

Verified end to end: `admin` approved, then `khamla` approved → `APPROVED` →
`DISPATCHED`. The UI already models this — an "1 of 2 approvals" badge, and both
signatures on the timeline — because `MovementResponse` exposes
`secondApprovedBy`/`secondApprovedAt`.

### Decisions
- **Tabs are framed around the job**, not the status enum: a dispatcher thinks
  "what am I sending", a receiver thinks "what is arriving". `Incoming` defaults
  to `DISPATCHED`, and those rows carry a **Receive** button directly.
- **Receive progress is local until confirm.** Nothing reaches the backend until
  the receiver commits, and a short receipt is allowed but never silent — the
  confirmation spells out what is missing and that it is recorded.
- **`X-Idempotency-Key` is sent on transfer creation** even though the backend
  does not yet honour it there, generated once per user intent rather than per
  retry. It costs nothing and the protection lands the moment the backend adds it.
- Weight deltas between dispatch and receipt are called out in red — for gold,
  that is the first thing a customer or auditor checks.

## Phase 8 — Warehouse & Vault

**Shipped:** warehouse hub, storage-location contents, bin directory, stock
count list, and the continuous-scan counting session with supervisor review.

### Decisions
- **Issue and return are not a separate domain.** Confirmed from
  `CreateMovementRequest`: they are `MovementType.ISSUE` / `RETURN` on the same
  movements endpoint, so they reuse `MovementRepository` rather than duplicating
  the lifecycle.
- **The counting engine is shared with Phase 5 and Phase 7.** One `ScanSession`
  handles matched/missing/unexpected/duplicate for stock counts, transfer
  receiving and physical verification.
- **The app can only submit observations.** `SubmitCountRequest` takes
  `foundItemIds` — there is no field through which the app could submit an
  adjusted quantity, and approval is a separate permission. The specification's
  "do not allow employees to silently modify stock counts" is therefore
  structural, not a convention.
- **Reconciliation figures come from the backend** (`missingCount`,
  `unexpectedCount`, `hasVariance`). Computing them client-side would risk
  disagreeing with the record of truth.
- **A count keeps the screen awake** and writes every scan through to local
  storage, so a killed app resumes rather than losing a thirty-minute job.
- Stock counts also support **dual authorisation** (`secondApprovedBy` on the
  response), mirroring movements.

### 🔴 Blocked
- **No item-to-bin assignment exists.** Bins can be created and listed
  (`ZONE/SHELF/TRAY/BIN/SAFE`) but nothing places an item in one, so vault "tray
  management" degrades to a bin *directory* plus a flat location item list. The
  screen says so rather than implying the tree is empty. Needs `binId` on the
  item or a `POST /warehouse/bins/{id}/items` endpoint.

### Tests added
14 covering scan reconciliation and tag normalisation — repeat-vs-duplicate,
serialisation round-trip for crash recovery, and URL-encoded QR reduction.
---

## Phases 9–17

Built in sequence: procurement, sales assistance, customers/CRM, repairs,
exchange & buyback, approvals, notifications, reports, and hardening.

### Phase 9 — Procurement
- **Contract question resolved.** `GoodsReceiptRequest.lines[].jewelleryItemId`
  confirms items are **created first, then referenced** by the receipt. The
  receiving flow follows that order and records each created item id on its
  draft, so a partial failure does not recreate items on retry.
- Scoped to **read + approve + receive**. Authoring a purchase order needs
  supplier terms and pricing that belong in the Admin portal, not on a phone at
  a loading bay.
- This is the one endpoint that already honours `X-Idempotency-Key`, and it
  matters most here — a retried submit could duplicate real stock. The key is
  generated once per receipt, never per retry.

### Phase 10 — Sales assistance
- `POST /pricing/calculate` returns a **complete server-computed breakdown**
  including `discountRequiresApproval`. Every line on the price sheet is a field
  from that response; the app performs no arithmetic on money or metal value.
- The rate's publish time is shown, and flagged when stale — quoting yesterday's
  gold rate to a customer is a real commercial loss.
- Cross-branch availability issues one count per **accessible** branch. A branch
  that refuses is omitted rather than reported as zero: "no stock" and "no
  access" are different claims.

### Phase 11 — Customers & CRM
- `GET /crm/customers/{id}/360` is a single call, so Customer 360 needs no
  aggregation.
- Phone numbers are **masked** unless the viewer holds `CUSTOMER_MANAGE` — a
  customer list on a counter device is visible to whoever is standing there.
- Creation runs a **duplicate phone check** before it will submit, offering to
  open the existing record instead. A second record for an existing customer is
  the most common data-quality failure in retail CRM.

### Phase 12 — Repairs
- **`conditionPhotoKeys` question resolved:** it is opaque free text capped at
  1000 characters, stored verbatim. The app therefore owns the format and stores
  a JSON array of `{key, type}`, giving the before/damage/after typing the
  specification needs, with the list trimmed to fit rather than failing a save.
- One primary action per status, from `allowedTransitions ∩ permissions`.
  Repair staff should not choose between eight buttons at a bench.
- Weight in vs out is shown with the delta in red — for gold, that is the first
  thing a customer checks on collection.

### Phase 13 — Exchange & Buyback
- **The no-client-arithmetic rule is now enforced by a test.** It reads the
  module's source and fails the build if a guarded field (`netValuation`,
  `grossValuation`, `ratePerUnit`, `pureWeight`, `netWeight`…) appears next to an
  arithmetic operator, and asserts the valuation request sends only a deduction
  percentage. A convention would have eroded; this cannot.
- Server-computed figures are visually tinted so staff can never mistake an
  input for a calculated result.
- Approving a payout restates net weight and net payable in a danger-toned
  confirmation before the call.

### Phase 14 — Approval centre
- Assembled from **five modules** with no unified endpoint. A module the user
  cannot approve is never queried — that keeps the queue honest and avoids a
  pile of 403s; a module that fails is skipped rather than failing the screen.
- Sorted **oldest first**, because the metric that matters in a queue is how
  long someone has been blocked. Items over 24h are tinted.
- Anything carrying an amount, and anything vault-grade, forces a confirmation
  that restates reference, summary, requester and amount. A mis-tap must not
  authorise a payout.

### Phase 15 — Notifications 🔴 **substantially blocked**
Built: the centre, read tracking, grouping, and **deep-link routing with tests**
for every reference type including the unknown case.

Not possible without backend work:
- No `/mine` endpoint → the app must pass its own user id. **If the backend does
  not constrain `recipientId` to the caller, one user could read another's
  notifications** — worth checking server-side regardless of this app.
- No read/unread field → read state is **device-local**: correct on one phone,
  wrong across two. A stopgap, not a design.
- No device registration and no FCM anywhere → **push does not function**.
- Only seven domain events exist, five aimed at customers, and the two staff
  events pass a null recipient — so **no notification is addressable to a staff
  user today**. The screen says so plainly rather than presenting an empty list
  as though nothing had happened.

### Phase 16 — Reports
- Deliberately small; finance and compliance reports are excluded as portal work.
- Ageing renders as a labelled bar chart where **every bar carries its own
  number**, so colour is never the only encoding and the chart and table agree.
- A report that fails says **"Unavailable"**, never zero — a zero would read as
  "no stock" or "no sales", a materially worse claim.
- 🟡 Report ranges use local dates. Correct while every branch is Asia/Vientiane;
  `BranchResponse.timezone` is carried and should drive this once branches span
  timezones.

### Phase 17 — Offline awareness & hardening
- **Connectivity has five states**, including `degraded` — transport up but the
  API unreachable. That is the common showroom case, and treating it as online
  is what produces spinners that never resolve.
- **`OfflineGuard` refuses mutations rather than queueing them.** The backend
  has no idempotent offline design; replaying a transfer an hour later would
  create phantom stock. The three workflows that *do* accumulate locally (stock
  count, receive reconciliation, goods-receipt draft) are safe precisely because
  no server state changes until one atomic submit.
- `ScreenGuard` applied to login and to exchange valuations.
- Connectivity banner lives at the app root, so no feature can forget it.

### 🟢 Bug found by running it: cross-branch location names
The transfer list showed **"Origin → Destination"**. The reference cache only
prefetched the *current* branch's locations, but a cross-branch transfer names a
source location belonging to another branch. Now locations load for every branch
the user can act in — cheap, since that is typically one to three. Fixed and
verified: the row reads "Main Vault → Branch Vault".

### 🟢 Removed the phase badges
The "Phase N" chips in the More menu marked unbuilt placeholders. With every
destination now built, leaving them would imply screens are still stubs.

### Status
```
146 Dart files · ~25,000 lines · 103 tests · analyzer clean
iOS and Android both build
```

---

## Backend fixes — 2 September 2026

Five items previously recorded as blockers were fixed in `erp-backend`, and the
scanner was verified on a physical Android device (V2404, Android 16). All
backend changes are covered by tests: **120 backend tests pass**.

### 🟢 Staff notifications now reach staff (Phase 15 unblocked)

The original diagnosis was **partly wrong** and worth correcting, because the
wrong version would have sent someone to write templates that already exist.

What is actually true:

- `V15` **does** seed `IN_APP` templates for `ITEM_TRANSFERRED` and `LOW_STOCK`.
- Both events **are** published — but `ItemTransferred` fires on *receive*, not
  on dispatch. Every test transfer had stopped at `DISPATCHED`, so the pipeline
  had simply never been exercised. Completing one produced a real row.
- The genuine defect was on the **read** side: both events queue with a
  `recipient_id` of `null`, and the app filtered by `recipientId = me`, which
  such a row can never match. Operational events are branch broadcasts, not
  personal mail, and nothing treated them as such.

Added `GET /notifications/mine`, `/mine/unread-count`, `POST /mine/{id}/read`
and `/mine/read-all`. Scope comes from the security context, never a parameter:
a message addressed to the caller, or a broadcast for a branch they work in.
Customer mail is excluded outright.

This also closes the security question raised earlier. The admin
`GET /notifications` search accepts an arbitrary `recipientId` — appropriate for
auditing the delivery queue, but it would have let any holder of
`NOTIFICATION_VIEW` read a colleague's mail had the inbox been built on it. The
app no longer sends a recipient id at all.

Verified against the live backend with four real users:

| user | branches | sees |
|---|---|---|
| somchai | Vientiane | Vientiane broadcast only |
| noy | Vientiane, Pakse | both broadcasts, not khamla's personal message |
| khamla | all three | own message + both broadcasts |
| admin | super admin | everything; empty `branchIds` means *every* branch, not none |

Marking another user's message read returns **403**.

### 🔴→🟢 A defect introduced by the first fix, caught before it shipped

`V24` put `read_at` on the notification row. That is right for a personal
message and wrong for a broadcast, which is **one row shared by a whole
branch** — so one person opening it cleared everybody's badge. Confirmed
live: khamla's "mark all read" took somchai's unread count from 1 to 0.

`V25` moves read state into `notification_read (notification_id, user_id,
read_at)`. Re-tested: khamla reading no longer touches somchai or noy.

Worth keeping in mind generally — **whenever a row is shared by several people,
per-user state cannot live on it.**

### 🟢 Missing required parameters return 400, not 500

`MissingServletRequestParameterException` had no handler, so it fell through to
the catch-all. `/metal-rates/current` with no `metalId` now returns:

```
400 VALIDATION_FAILED  Required parameter 'metalId' is missing
```

with a `fieldErrors` entry. A 500 tells a client to retry something that can
never succeed.

### 🟢 Location codes are unique per branch

`organization.location` had `UNIQUE (code)` **globally**, so a second branch
could not have its own `VAULT` and the seed data carried invented prefixes.
`V25` scopes it to `(branch_id, code)`. Verified both directions: the same code
in two branches now inserts, a duplicate within one branch still fails.

### 🟢 The backend test suite could not run at all

Every Testcontainers test aborted with *"Could not find a valid Docker
environment"* while the daemon was perfectly healthy — including tests nobody
had touched, so this was pre-existing and hid the whole integration suite.

Docker Engine 29 rejects API versions below ~1.41, and docker-java negotiates
from v1.32. Probing the socket directly is what showed it:

```
v1.32 → 400      v1.41 → 200
```

Pinned `api.version` in the surefire configuration (and bumped Testcontainers to
1.20.6). No environment variable needed; it works for everyone from a clean
checkout.

### 🔴 Still open

- **No push delivery.** There is no device registration endpoint and no FCM, so
  the inbox is poll-on-open. Needs a Firebase project and a decision from the
  product side.
- **No item-to-bin assignment**, so vault tray management stays a bin directory.
- **No image fields** on item, product or design — the passport has no photo.
- **Unknown paths return 500 rather than 404** (`NoHandlerFoundException` is
  never thrown unless Spring is configured to). Noticed in passing; harmless but
  misleading.

---

## Scanner verified on a physical device

`mobile_scanner` pulls in ML Kit, which ships **no arm64 simulator slice**, so
the camera path had never once run. On an attached Android phone it works
end to end: the live preview, torch and Single/Bulk toggle render, and scanning
a QR of a real tag (`QR-JW-000001`) navigates straight to that item's passport.

### 🟢 Bug this exposed: names resolved unevenly, and never recovered

The scanned passport showed **"Metal: Gold" beside "Purity: —"** — one field
resolved, its neighbour blank, no error anywhere. The same item in the list
showed "22K Gold" correctly.

The reference cache is a mutable service behind a plain `Provider`, so filling
its maps **notifies nobody**. Purities load in a *second* wave, after the metals
they hang off. Scanning straight after sign-in caught the cache between the two
waves, and because nothing rebuilt the route, the blank persisted for the life
of the screen.

Two things made it hard to see: it is a race, so it does not always reproduce,
and it degrades *partially* — a fully blank screen would have been noticed
immediately.

Fixed with a shared `ReferenceGate` widget rather than six one-off guards, since
every future screen that turns ids into names has the same exposure. A cache
that fails outright still renders the screen — names are supporting detail, and
losing them must not block the work behind them. Applied to the passport,
dashboard, transfer detail, vault, warehouse, goods receiving and exchange.
Covered by `test/features/reference_gate_test.dart`.

### Status
```
147 Dart files · 105 Flutter tests · analyzer clean
120 backend tests · Flyway at V25
Android verified on device · iOS builds
```

---

## Remaining open items — 2 September 2026

Push was left aside at your request. Everything else on the list is now closed.

### 🟢 The error contract

Three cases, all diagnosed by reading what the server actually threw rather than
guessing from the 500:

| case | was | now |
|---|---|---|
| missing required parameter | 500 | 400, naming the parameter |
| malformed enum value | 500 | 400, naming the field **and its accepted values** |
| malformed JSON body | 500 | 400 |
| unknown path | 500 | 404 |

The 404 is worth a note. `NoHandlerFoundException` was already handled — it is
simply never thrown. Since Spring 6.1 an unmatched path falls through to the
static-resource handler and raises `NoResourceFoundException` instead, so the
existing handler had never once fired.

### 🟢 Item-to-bin assignment

`storage_bin` and `stock_count_line.bin_id` already existed, so a count could
record where an item was *found* — with nothing to compare it against, because
the item itself had no bin. Bins could be created and listed and never filled.

Added `bin_id` on the item, `POST /inventory/items/{id}/bin` (null clears it),
and a `binId` filter on the item search so a tray's contents reuse the existing
paging and permissions instead of a bespoke endpoint.

The bin must belong to the item's **current location**. Without that check an
item could be recorded in a tray on the other side of the country — worse than
having no bin at all, because a stock count would then report it missing from a
vault nobody had reason to search.

Every assignment writes a lifecycle event and an audit entry. Verified on the
device: the passport reads "Bin · SAFE-1 · Main Safe" and the timeline shows
"Placed in bin SAFE-1 — admin".

**A circular dependency surfaced here.** Warehouse already depends on inventory
through `InventoryOperations`; making inventory depend back on
`WarehouseService` closed a constructor cycle and the context refused to start.
Fixed by serving the new `BinDirectory` port from its own small bean that
depends on the bin repository alone.

Also fixed: `storage_bin` had `UNIQUE (code)` globally — the same mistake
`organization.location` had — so a second vault could not have its own TRAY-1.
Now `(location_id, code)`, in the schema *and* in the service, which was still
checking globally after the constraint changed.

### 🟢 Item images

**The earlier note that there are "no image fields" was wrong.**
`product.product_image` exists, with `storage_key`, `primary_image` and
`display_order`, and the `Product` entity already maps it. It was simply never
exposed through the API. Worth correcting, because the wrong version would have
sent someone to design a table that was already there.

Added `inventory.item_image` mirroring it rather than inventing a second shape.
The two answer different questions: a product image is catalogue artwork shared
by every item made to that product, while an item image is *this* physical
piece — which is what staff need when identifying stock in a tray.

- `GET/POST /inventory/items/{id}/images`, `DELETE .../images/{imageId}`
- Upload goes to the existing `POST /files` first; only the returned key is
  linked. A large photo that fails midway therefore leaves no half-written row.
- `primaryImageKey` is returned **inline** on the item response, so a page of
  results costs no extra request per row. The collection is `@BatchSize(100)`;
  without it thirty rows would fire thirty extra queries.
- One primary image per item, enforced by a partial unique index. A new primary
  demotes the old one, and removing the primary promotes the next — otherwise
  the passport header silently falls back to a placeholder.

Verified on the device: an uploaded photo appears as the list thumbnail and as
the passport hero, while items without one keep the category glyph.

### 🟢 Testcontainers, again

The Docker API pin from earlier held. `mvn test` runs the whole suite from a
clean checkout: **128 tests**, including 8 new ones for bins and images.

### A mistake worth recording

Running `dart format lib/` across the whole codebase — rather than the files I
had touched — reformatted unrelated code and broke
`exchange_no_arithmetic_test`. That test anchored on the literal string
`_step(id, 'valuation'`, which the formatter wrapped across two lines.

The test was right to fail; its anchor was brittle. A source-reading guard must
key off something stable, so it now anchors on the method declaration. Two
`curly_braces_in_flow_control_structures` lints appeared from the same sweep
and were fixed properly rather than reverted.

### Status
```
149 Dart files · 105 Flutter tests · analyzer clean
128 backend tests · Flyway at V26
Android verified on device · iOS builds (Runner.app)
```

### Still open
- **Push delivery** — deferred at your request. Needs device registration, FCM
  and a Firebase project.
- **Staff-directed events** — only branch-wide broadcasts exist today; "transfer
  awaiting *your* approval" has no event behind it.
- **Design images** — `product` and `jewellery_item` now have them; design does
  not. Trivial to mirror if the catalogue needs it.
