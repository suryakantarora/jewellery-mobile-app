# Backend Gaps & Decisions — Cross-Phase Summary

Everything the mobile app needs that the Spring Boot backend does not currently provide, found
by reading the actual controllers rather than the phase specs. Ordered by impact.

Each item says what ships **without** the backend change, so nothing here blocks development —
but several of the workarounds are things I would not want to ship as final.

---

## Blocking-ish — recommend fixing before the MVP ships

### 1. No dashboard summary endpoint · Phase 3 — ✅ resolved 14 Sep 2026
`GET /api/v1/dashboard/summary?branchId=&refresh=` returns permission-filtered sections (sales on SALE_VIEW — settles NEXT-STEPS 1.3 — inventory, inventoryValue, transfers, approvals, repairs, procurement, notifications, metalRates); absent section = not permitted. 30 s server cache. The app now makes one call instead of seven.

Original note:
The dashboard needs 8–15 parallel calls to render. Proposed:
`GET /api/v1/dashboard/summary?branchId=` returning sales / inventory / transfers / approvals /
repairs / notifications / tasks, **permission-filtered server-side**.
*Without it:* client fan-out with per-tile failure isolation and a 60 s cache. Works; slow on
poor connections, and "inventory value where permitted" becomes a client-side trust decision.

### 2. Notifications for staff · Phase 15 — ✅ mostly resolved 2 Sep 2026

**The original diagnosis here was partly wrong, and the wrong half was the actionable half.**
It claimed the two staff events had no templates. They do: `V15` seeds `IN_APP` templates for
both `ITEM_TRANSFERRED` and `LOW_STOCK`. And the events are published — `ItemTransferred` just
fires on *receive*, not on dispatch, and every test transfer had stopped at `DISPATCHED`, so the
pipeline had never once been exercised. Completing a transfer produced a real row immediately.

The genuine defect was on the **read** side. Both events queue with a `recipient_id` of `null`,
and the app filtered by `recipientId = me`, which such a row can never match. These are branch
broadcasts, not personal mail, and nothing treated them as such.

**Fixed** — `GET /notifications/mine`, `/mine/unread-count`, `POST /mine/{id}/read`,
`POST /mine/read-all`. Scope comes from the security context, never a parameter: messages
addressed to the caller, plus broadcasts for branches they work in. Customer mail is excluded.
An empty `branchIds` means *every* branch for a super admin, not none.

Read state is `notification_read (notification_id, user_id, read_at)`, **not** a column on the
notification. The first attempt did put it on the row, and one person's "mark all read" cleared
their whole branch's badges — a shared row cannot carry per-user state. Covered by
`NotificationInboxIntegrationTest`.

**The `?recipientId=` concern is closed for this app.** The admin `GET /notifications` search
still accepts an arbitrary recipient id, which is right for auditing the queue, but the app no
longer sends one. Constraining it server-side is still worth considering for other clients.

**Still open — all ✅ done 14 Sep 2026 (server + app):**
```
1. ✅ staff-directed events with a resolved recipient user id:
      TRANSFER_AWAITING_APPROVAL / TRANSFER_APPROVED / TRANSFER_REJECTED,
      PURCHASE_ORDER_APPROVED / _REJECTED, REPAIR_READY_STAFF, HIGH_VALUE_SALE,
      APPROVAL_INFO_REQUESTED / _ANSWERED, DISCOUNT_REQUESTED / DISCOUNT_DECIDED
      — app labels/tones in NotificationEventTypes (notification_models.dart)
2. ✅ POST /notifications/devices   DELETE /notifications/devices/{token}
      — app: push_registration_service.dart registers on sign-in, re-registers on
        token refresh, deletes on sign-out (best-effort)
3. ✅ server-side FCM send for NotificationChannel.PUSH
      — payload {eventType, referenceType, referenceId, notificationId}; app routes
        taps via NotificationRouter.pathFor; foreground shows a snackbar + refreshes
```
*Still needed from you:* the Firebase project config — `google-services.json` per Android
flavour, `GoogleService-Info.plist` per iOS flavour + Push Notifications capability + APNs key,
and service-account credentials on the server. Until those are in place the app detects the
missing config, logs once, and stays on the 60 s poll. `referenceType` `Sale` has no detail
route in the app yet, so a `HIGH_VALUE_SALE` tap opens the inbox.

`referenceType` is now documented by observation: `BusinessEventListener` writes
`InventoryMovement`, `Location`, `Sale`, `Payment`, `RepairRequest`, `Exchange`, `Campaign`.
`NotificationRouter` matches these case-insensitively.

### 3. Item responses are all UUIDs, no names · Phases 4, 5, 7, 10 — ✅ resolved 14 Sep 2026 (Fix A)
`JewelleryItemResponse` now carries productName, productCode, designName, metalName, purityCode, currentLocationName, currentBranchName, binCode, supplierName, resolved in batch per page. The app's reference cache is now a fallback for names and the source for pickers.

Original note:
`JewelleryItemResponse` carries `productId`, `metalId`, `purityId`, `currentLocationId`,
`supplierId` — no display names. Rendering "22K Gold · Ladies Ring · Counter 2" for a 20-row
list needs ~60 extra lookups.
*Fix A (recommended):* denormalise `productName`, `metalName`, `purityCode`, `locationName`
onto the response. Helps the Admin portal too.
*Fix B (ships now):* a client reference-data cache with lazy per-id loading and request
coalescing. More moving parts, more failure modes offline.

### 4. Images · Phases 4, 5, 10, 12 — ✅ resolved for items 2 Sep 2026

**The original claim that there is "no image field anywhere" was wrong.**
`product.product_image` already exists — `storage_key`, `primary_image`, `display_order` — and
the `Product` entity already maps it. Nothing exposed it through the API, which is a much
smaller gap than a missing table, and the wrong version of this note would have sent someone to
design something that was already built.

**Fixed for items:** `inventory.item_image` mirrors that shape rather than inventing a second
one. The two answer different questions — a product image is catalogue artwork shared by every
item made to that product; an item image is *this* physical piece, which is what staff need
when identifying stock in a tray.

```
GET/POST /inventory/items/{id}/images     DELETE /inventory/items/{id}/images/{imageId}
```
Upload to `POST /files` first and link the returned key, so a photo that fails midway leaves no
half-written row. `primaryImageKey` comes back inline on the item response (batched, so a page
of thirty rows costs one extra query, not thirty). One primary per item, enforced by a partial
unique index: a new primary demotes the old, and removing the primary promotes the next.

*Design/product images — ✅ 14 Sep 2026:* `GET/POST/DELETE /designs/{id}/images` and
`/products/{id}/images`, with `primaryImageKey` inline on `DesignResponse` / `ProductResponse`
(parsed by the app's `Design` / `Product` models). The catalogue cannot yet fall back to them:
`CatalogueItemResponse` carries no `designId`/`productId`, so add those (or a
`fallbackImageKey`) to the catalogue response if that fallback is wanted. The app's item photo
gallery (`item_image_gallery.dart` on the passport) uses `POST /files` → `POST .../images`.

### 5. No unified approvals endpoint · Phases 3, 14 — ✅ resolved 14 Sep 2026
`GET /approvals/pending`, `GET /approvals/pending/count`, `POST /approvals/{type}/{id}/decision` (APPROVE / REJECT / REQUEST_INFO, idempotent by X-Idempotency-Key), `GET|POST /approvals/{type}/{id}/information[/{requestId}/answer]`. Discount approval now has a backend: `/sales/discount-requests` with DISCOUNT_REQUEST / DISCOUNT_APPROVE enforced and `discountRequestId` honoured on `POST /sales`. High-value transactions raise a HIGH_VALUE_SALE staff notification rather than an approval gate.

Original note:
Five modules each with their own pending-status query and approve call. Proposed
`GET /api/v1/approvals/pending` + `POST /api/v1/approvals/{type}/{id}/decision`, scoped to what
the caller can actually approve.
*Without it:* client-side aggregation across five endpoints, skipping unpermitted ones.
**Discount approval and high-value-transaction approval have no backend at all** and cannot be
built — placeholders only.

---

## Should fix — real but workaroundable

### 6. No branch header · all phases — ✅ resolved 14 Sep 2026
`X-Branch-Id` is validated by a filter (foreign branch → 403) and exposed as `SecurityUtils.currentBranchId()`; the dashboard uses it as a fallback. Existing endpoints still take branchId explicitly.

Original note:
`SecurityUtils.requireBranchAccess(branchId)` takes branch as an explicit per-endpoint
parameter. Accepting a standard `X-Branch-Id` header would make branch scoping a single
interceptor concern instead of a parameter threaded through every repository.

### 7. Idempotency only on three endpoints · Phases 7, 8, 12, 13 — ✅ resolved 14 Sep 2026
Transfer creation already accepted the key; added to `POST /exchanges`, `POST /repairs` and every approval decision.

Original note:
`X-Idempotency-Key` is supported on `/sales`, `/payments` and `/procurement/goods-receipts`.
It is **not** supported on transfer creation, exchange steps or approvals — all of which a
flaky network can duplicate. A double-submitted ₭4M transfer is a real incident.

### 8. No bulk tag resolution · Phase 6 — ✅ resolved 14 Sep 2026
`POST /inventory/items/by-tags {tags[]}` → resolved/unresolved; the app chunks at 200 and shows a resolution sheet after a bulk scan.

Original note:
200 scanned tags = 200 sequential `by-tag` calls. Proposed
`POST /api/v1/inventory/items/by-tags {tags:[…]}` → resolved + unresolved.
*Without it:* concurrency-limited fan-out with a progress bar.

### 9. No cross-branch availability endpoint · Phase 10 — ✅ resolved 14 Sep 2026
`GET /inventory/availability?productId=` scoped to the caller's branches, zeros included.

Original note:
Proposed `GET /api/v1/inventory/availability?productId=` returning per-branch counts, filtered
to the caller's branch access.
*Without it:* one count call per accessible branch, in parallel.

### 10. Bin→item assignment · Phase 8 — ✅ resolved 2 Sep 2026
Bins existed and could be listed and created, but nothing placed an item in one — and
`stock_count_line.bin_id` already recorded where a piece was *found*, with nothing to compare it
against.

**Fixed:** `bin_id` on the item, `POST /inventory/items/{id}/bin` (null clears it), and a
`binId` filter on the item search so a tray's contents reuse the existing paging and
permissions rather than a bespoke endpoint.

The bin must belong to the item's **current location**. Without that an item could be recorded
in a tray on the other side of the country — worse than no bin at all, because a stock count
would report it missing from a vault nobody had reason to search. Every change writes a
lifecycle event and an audit entry.

Two things surfaced doing it, both fixed: `storage_bin` had the same **global** `UNIQUE (code)`
that `organization.location` had (so a second vault could not have its own TRAY-1) — now
`(location_id, code)`, in the schema *and* in the service, which was still checking globally
after the constraint changed. And serving the new `BinDirectory` port from `WarehouseService`
closed a **constructor cycle** — warehouse already depends on inventory through
`InventoryOperations` — so the port lives in its own bean that reaches only the bin repository.

### 11. No price range filter on item search · Phases 4, 5 — ✅ resolved 14 Sep 2026
`minPrice` / `maxPrice` on `GET /inventory/items`; filter sheet row in the app.

Original note:
The spec asks for it; `GET /inventory/items` has no `minPrice`/`maxPrice`. Client-side
filtering of a paged list would be wrong, so the filter is dropped unless the params are added.

### 12. No wishlist · Phases 10, 11 — ✅ resolved 14 Sep 2026
Real table: `/customers/{id}/wishlist` (item, product or design entries). Shown on the customer 360 and added from the sales assistance screen.

Original note:
Nothing in the codebase. Options: add `/customers/{id}/wishlist`; or model it as a
**quotation**, which already exists and is arguably the correct commercial concept; or
device-local, which makes it invisible to colleagues and close to useless.
*Recommendation:* quotations now, a real wishlist later.

### 13. No "request information" approval action · Phase 14 — ✅ resolved 14 Sep 2026
See item 5: REQUEST_INFO creates an information request without changing status; the creator answers it in-app.

Original note:
The spec lists it; no backend supports it. I will not simulate it with a rejection.

### 14. No app version endpoint · Phase 17 — ✅ resolved 14 Sep 2026 (both sides)
Backend: `GET /api/v1/app/version` public, config `jewellery.app.versions.{android,ios}.*` (env APP_ANDROID_MIN_SUPPORTED etc.).
Needed for the forced-update gate: `GET /api/v1/app/version?platform=ANDROID|IOS&current=<x.y.z>`
(public, no token) → `{platform, minSupported, latest, storeUrl, message?, forceUpdate}`.

App side is in place (`lib/core/settings/app_version_service.dart`, `update_gate.dart`):
`forceUpdate: true` blocks the app behind a full-screen update prompt; `latest > current`
shows a one-off nudge; any failure (404 while the endpoint is unbuilt, offline, malformed body)
resolves to *unknown* and the app carries on. The backend's `forceUpdate` flag is authoritative;
`minSupported` is only the fallback when the flag is absent.

---

## Contract questions — RESOLVED by reading the backend

These were open in the first draft. I read the request/response records; no input needed from
you on any of them. Recorded here so the answers are not lost.

15. **`ReceiveMovementRequest`** (Phase 7) — ✅ **supports discrepancies.**
    `{lines: [{jewelleryItemId, receivedWeight, discrepancyNote}], notes}`. The scan-reconcile
    receive flow works as designed, including per-item re-weighing.
16. **`MovementResponse`** (Phase 8) — ✅ **richer than expected.** Carries `createdBy`,
    `approvedBy`/`approvedAt`, **`secondApprovedBy`/`secondApprovedAt`** (the backend already
    supports dual authorisation for high-value movements), `dispatchedBy`, `receivedBy`,
    `requiresApproval`, `rejectionReason`. The high-value audit panel is fully buildable.
    Bonus: `MovementLineResponse` carries a denormalised **`itemCode`**, so transfer lines
    render without extra lookups.
17. **`GoodsReceiptRequest`** (Phase 9) — still to verify; low risk, it only reorders steps
    within a flow I control.
18. **`CreateItemRequest`** (Phase 9) — ✅ mandatory: `productId`, `grossWeight`, `locationId`.
    Optional: metal, purity, size, tags, hallmark, costs, supplier, stones.
    **`netMetalWeight` is derived server-side, never supplied** — which is exactly the
    no-client-arithmetic rule, enforced by the API.
19. **`conditionPhotoKeys`** (Phase 12) — ✅ **an opaque free-text field** (`max 1000`), stored
    verbatim. So the *app* defines the format: I will store a small JSON array of
    `{key, type, capturedAt}` giving before/damage/after typing with no backend change.
    Caveat: 1000 characters caps it at roughly 8–10 photos per repair.
20. **`ValuationRequest`** (Phase 13) — ✅ **confirms the design.** The client posts only
    `{deductionPercentage, notes}`; the backend computes net weight, applies the rate and
    returns the valuation. The app never calculates money. Exactly as designed.
21. **Notification `referenceType`** (Phase 15) — see the escalated finding in §2 above.
22. **Issue / return mapping** (Phase 8) — ✅ confirmed. `CreateMovementRequest` takes
    `{movementType, fromLocationId, toLocationId, itemIds[], notes}`, so `ISSUE` and `RETURN`
    are movement types on the same controller, as designed.
23. **"Return" item action** (Phase 5) — ✅ confirmed. `ChangeStatusRequest` is
    `{targetStatus, reason}` with `reason` **mandatory** — the app's forced-reason dialog
    matches the contract.

Also confirmed in passing: `ReserveItemRequest` is `{jewelleryItemId, customerId, holdHours,
notes}`, so the Phase 10 reservation sheet needs a duration picker.

---

## Corrections after testing against the live backend

Verified against a running instance on `:8081`, comparing `identity.permission` (67 rows) with
my enum. Recorded here because the first draft stated two of these as fact.

31. **`VAULT_MOVEMENT` and `BUYBACK_VALUATION` are not permissions.** They are `control_type`
    string literals inside a compliance dual-authorisation SQL report. My original extraction
    grepped for quoted upper-case tokens and swept them up. The mobile enum now matches the
    permission table 1:1. Buyback valuation is gated by `EXCHANGE_VALUE`, the same as exchange.
32. **`DISCOUNT_REQUEST` and `DISCOUNT_APPROVE` do exist**, granted to `SUPER_ADMIN`. I missed
    them because they are seeded in a migration and never referenced by any
    `hasAuthority(...)` annotation — which is itself the finding: **the permissions are defined
    but nothing enforces them**, since no discount-approval endpoint exists. This narrows gap
    #5: the discount workflow needs an endpoint, not new permissions.
33. **Null fields are omitted, not sent as null.** `primaryBranchId` is simply absent for a user
    without one. Every mobile parser already reads with `as String?`, so absent and null behave
    identically — but any future model must keep doing so.
34. **`organization.location` had `UNIQUE (code)` — globally, not per branch.** ✅ **Fixed**
    (`V25`): now `UNIQUE (branch_id, code)`. Verified both ways — the same code in two branches
    inserts, a duplicate inside one branch still fails. The branch-prefixed seed codes are no
    longer necessary and can be simplified whenever convenient.
35. **Missing or malformed parameters returned 500, not 400.** ✅ **Fixed** for the missing case:
    `MissingServletRequestParameterException` had no handler and fell through to the catch-all,
    so `/metal-rates/current` with no `metalId` looked like a server outage. It now returns
    `400 VALIDATION_FAILED` with a `fieldErrors` entry. A malformed *enum* value still yields
    500 and is worth the same treatment.
35b. **Unknown paths returned 500 rather than 404.** ✅ **Fixed.** `NoHandlerFoundException` was
    already handled and simply never thrown: since Spring 6.1 an unmatched path falls through to
    the static-resource handler and raises `NoResourceFoundException`. A malformed enum value or
    unreadable JSON body now returns 400 as well, naming the field and its accepted values.
35c. **The integration test suite could not run at all.** ✅ **Fixed.** Every Testcontainers test
    aborted with *"Could not find a valid Docker environment"* against a healthy daemon —
    Docker Engine 29 rejects API versions below ~1.41 (`v1.32` → 400, `v1.41` → 200) and
    docker-java negotiates from v1.32. `api.version` is now pinned in the surefire config, so it
    works from a clean checkout with no environment variables. 120 tests pass.
36. **The bootstrap `admin` has no branches** (`branchIds: []`). Correct behaviour on mobile is
    the "no branch assigned" state, not the dashboard. A branch-assigned user is needed to
    exercise the full flow.

---

## Product decisions for you

24. **Institution name** — `UserResponse` has no company field. Resolve via
    `branch.companyId` → `GET /companies/{id}`? The branch bar shows Institution › Branch ›
    Location on every screen, so this is needed from Phase 2.
25. **Localisation** — is Lao in scope? Cheap now, expensive across 60 screens later.
26. **Currency** — LAK primary? Multi-currency display rules?
27. **State management** — confirming Riverpod; effectively irreversible by Phase 5.
28. **Package id** — `com.finotech.jewellery.mobile`?
29. **PO authoring on mobile** — I have scoped it out (read + approve + receive only).
30. **Finance / compliance reports on mobile** — I have scoped them out.

---

## Multi-tenancy — verified 2 September 2026

Checked before designing a customer storefront, because the tenancy model
determines the customer identity model and is painful to change once accounts
exist.

### 37. Branch is the authorization boundary; company is not enforced anywhere

`Branch.java` says so explicitly — *"Branches are the primary authorization
boundary"* — and the principal bears this out: `AuthenticatedUser` carries
`branchIds` and `superAdmin`, and **no company at all**. No query filters by
company.

With one company on the platform this is invisible. With two it means there is
no isolation between them of any kind.

### 38. Reads are not branch-scoped; writes are

Eleven services call `SecurityUtils.requireBranchAccess(...)` — sale, quotation,
payment, purchase order, goods receipt, repair, exchange, daily closing, stock
count. Every one of them is a **mutation**. No read path calls it.

Demonstrated with `somchai`, who is granted Vientiane Showroom only:

```
GET /inventory/items?branchId=<Central Warehouse>   → 9 items    (not their branch)
GET /inventory/items                                → 40 items   (every branch)
```

`branchId` is a filter, not a boundary.

**This may well be intentional, and it is not obviously wrong.** A salesperson
asking "do we have this in Pakse?" is a real workflow, and this app already
relies on cross-branch reads — the transfer list names the *other* branch's
locations, and the reference cache deliberately loads every accessible branch.
Locking reads down would break that.

So it is recorded as a decision to make rather than a defect fixed:

- **One company, many branches** (today) — current behaviour is defensible.
  Staff see group stock; mutations stay branch-guarded.
- **Many companies on one platform** (the stated direction) — it is not
  survivable. Company A would read Company B's stock, customers and prices.

### 39. Product master data is global, not per company

`product.product`, `product.metal` and `product.product_category` have **no
company or branch column**. `metal_rate` is branch-scoped and
`jewellery_item` is branch-scoped, but the catalogue they hang off is shared
platform-wide.

For a second tenant this means shared product definitions and categories, not
merely visible ones. That is a schema change, not a query change, so it is worth
settling before the data grows.

### 40. Customers are only loosely branch-associated

`customer.customer` has a **nullable** `registered_branch_id` and nothing filters
on it. (Its `company_name` column is the *customer's* employer — easy to misread
as a tenant key; it is not one.)

This matters most for the planned customer app: a customer account needs to
belong to a tenant, and today there is no field that reliably says which.

### 🟢 What was done about it now

The catalogue — the one surface written to be shown outside the business — is
scoped, without disturbing staff read behaviour elsewhere:

- omitting `branchId` means *"where I am"*, not *"everything"*
- requesting a branch the caller lacks returns **403**
- a super admin, who has no home branch by design, still sees all

Verified: `somchai` 19 items unscoped, 403 for Central Warehouse; `admin` 34.

---

## Multi-tenancy — implemented 14 September 2026

Items 37–40 are closed. The company is now a real tenant boundary: a second
company on the same platform cannot see the first one's data, and nothing
changed for the single existing company.

### The model

```
Authentication  →  Tenant (company)  →  Branch
```

- **The principal carries the company.** `AuthenticatedUser` has a
  `companyId` component next to `branchIds` and `superAdmin`. It travels in the
  access token as the **`co` claim** (a UUID string).
- **A super administrator has no company** (`companyId` null, no `co` claim)
  and sees every company — they are a platform user, as before. A super admin
  *can* be given a company, in which case they are confined to it like anyone
  else.
- **A token without `co` for an ordinary user is legacy.** Any company-scoped
  read throws `401 UNAUTHORIZED` — *"Your session predates company scoping.
  Sign in again."* The app should treat that exactly like an expired token:
  drop the session and re-login. Tokens issued after this deploy always carry
  the claim.
- **Reads stay cross-branch within the company.** The "do we have this in
  Pakse?" workflow (item 38) is unchanged; `branchId` is still a filter, not a
  boundary, inside the company. Mutations are still guarded by
  `requireBranchAccess`, which now *also* refuses a branch of another company
  even when a grant names it.
- **Another company's record is a 404, never a 403** — existence is not
  leaked.

### What is scoped (V30 adds `company_id`, backfilled, NOT NULL)

| table | scoped by | code uniqueness now |
|---|---|---|
| `product.product` | own column | `(company_id, sku)` |
| `product.product_category` | own column | `(company_id, code)` |
| `product.jewellery_design` | own column | `(company_id, design_code)` |
| `product.metal` (purity inherits through `metal_id`) | own column | `(company_id, code)` |
| `product.gemstone` | own column | `(company_id, code)` |
| `customer.customer` | own column | `(company_id, customer_code)`, `(company_id, phone)` |
| `procurement.supplier` | own column | `(company_id, code)` |
| `identity.app_user` | own column, **nullable** (super admins) | unchanged |
| `inventory.jewellery_item` | through `current_branch_id → branch.company_id` | — |
| catalogue read model | joins `organization.branch` on the item | — |
| `organization.company` / `branch` | list = own company only; foreign get = 404 | — |

Gemstone is scoped, not shared, for the same reason metal is: the list is what
a company's staff pick from, its codes are the company's vocabulary, and a
shared list would let one tenant rename what another tenant's items refer to.

Every list/search/get in the services above passes
`SecurityUtils.currentCompanyIdOrNull()` into the repository with the
`(:companyId is null or e.companyId = :companyId)` idiom — explicit in the
query, not a Hibernate `@Filter`, so the scope is visible and testable.
Cross-module ports (`ProductCatalog.requireProduct`,
`CustomerDirectory.requireCustomer`, `SupplierDirectory.requireSupplier`) go
through the same scoped lookups, so a sale for another company's customer
fails as *not found*.

### What is not scoped (deliberately)

- `product_type`, `brand`, `collection`, `size` — platform-wide lookup lists,
  referenced by products but carrying no business data.
- Pricing rules, tax rates, discount policies, loyalty programmes, metal rates
  — these are branch-scoped (or global) as before; the branch carries the
  company. A pass adding `company_id` to the global ones is straightforward
  when a second tenant actually lands.
- Notifications, audit, finance, reporting — branch-scoped or user-scoped
  already.
- Label lookups used to name rows in lists (`labelsFor`, `branchNames`) are
  unfiltered: they resolve ids the caller already holds.

### Creating records

- An ordinary user's creates are stamped with **their** company. Passing a
  different `companyId` is a `400 VALIDATION_FAILED` ("Cannot create records
  for another company").
- A super administrator **must say which company** when creating master data:
  `companyId` in the request, or an `X-Branch-Id` header (the branch decides),
  or there is exactly one company on the platform. Otherwise
  `400 VALIDATION_FAILED` — "companyId is required".
- Users: the company comes from the request's `companyId`, else the creator's
  company, else the company of the user's branches. Every branch granted to a
  user must belong to that company (`400` otherwise). A user given a
  super-admin role may have no company.
- Customers: `registeredBranchId`, where given, decides the company and must
  agree with the caller's.

### Request / response changes (exact JSON names)

- `GET /auth/me`, login and refresh `user`, `GET /users`, `GET /users/{id}`:
  **`companyId`** (UUID, null for a platform super admin) and
  **`companyName`** (string, null when no company) added to `UserResponse`.
- Optional **`companyId`** (UUID) added to: `POST /users` (`CreateUserRequest`),
  `POST /products` (`ProductRequest`), `POST /designs` (`DesignRequest`),
  `POST /categories` (`CategoryRequest`), `POST /metals` (`MetalRequest`),
  `POST /gemstones` (`GemstoneRequest`), `POST /suppliers` (`SupplierRequest`),
  `POST /customers` (`CustomerRequest`). Omit it as a normal user.
- `GET /companies` returns only the caller's company unless they are a
  platform super admin. `GET /branches` is confined to the caller's company
  (`companyId` filter naming another company yields an empty page).
  `GET /branches/mine` unchanged.
- JWT: new **`co`** claim.

### Migration

`V30__company_tenancy.sql` — adds `company_id` to the eight tables above,
backfills every row to the oldest company (users: company of their primary
branch, else of any granted branch, else the oldest company; super admins
stay null), sets NOT NULL (except `app_user`), indexes each column, and
replaces the global code/phone unique constraints with per-company ones.

### Tests

`CompanyTenancyIntegrationTest` (8 tests): company B with a branch, user,
product, customer and item; an A user sees none of B's products, customers or
items in lists and gets 404 on get-by-id (service and HTTP); the super admin
sees both; creating a product as an A user stamps A and a `companyId` of B is
refused; the same SKU is free in B; assigning a B branch to an A user fails;
`requireBranchAccess` rejects B's branch for an A user even when granted; a
legacy token without `co` is told to sign in again.
