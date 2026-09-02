# Backend Gaps & Decisions — Cross-Phase Summary

Everything the mobile app needs that the Spring Boot backend does not currently provide, found
by reading the actual controllers rather than the phase specs. Ordered by impact.

Each item says what ships **without** the backend change, so nothing here blocks development —
but several of the workarounds are things I would not want to ship as final.

---

## Blocking-ish — recommend fixing before the MVP ships

### 1. No dashboard summary endpoint · Phase 3
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

**Still open:**
```
1. staff-directed events with a resolved recipient user id
   (transfer approved / awaiting-approval, PO approved, repair ready, high-value alert)
   — today only branch-wide broadcasts exist
2. POST /notifications/devices   DELETE /notifications/devices/{token}
3. server-side FCM send for NotificationChannel.PUSH
```
*Without those:* the inbox works but is **poll-on-open** — nothing reaches a locked phone.
Needs a Firebase project and a product decision, not more app work.

`referenceType` is now documented by observation: `BusinessEventListener` writes
`InventoryMovement`, `Location`, `Sale`, `Payment`, `RepairRequest`, `Exchange`, `Campaign`.
`NotificationRouter` matches these case-insensitively.

### 3. Item responses are all UUIDs, no names · Phases 4, 5, 7, 10
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

*Still open:* design images. Trivial to mirror if the catalogue needs them.

### 5. No unified approvals endpoint · Phases 3, 14
Five modules each with their own pending-status query and approve call. Proposed
`GET /api/v1/approvals/pending` + `POST /api/v1/approvals/{type}/{id}/decision`, scoped to what
the caller can actually approve.
*Without it:* client-side aggregation across five endpoints, skipping unpermitted ones.
**Discount approval and high-value-transaction approval have no backend at all** and cannot be
built — placeholders only.

---

## Should fix — real but workaroundable

### 6. No branch header · all phases
`SecurityUtils.requireBranchAccess(branchId)` takes branch as an explicit per-endpoint
parameter. Accepting a standard `X-Branch-Id` header would make branch scoping a single
interceptor concern instead of a parameter threaded through every repository.

### 7. Idempotency only on three endpoints · Phases 7, 8, 12, 13
`X-Idempotency-Key` is supported on `/sales`, `/payments` and `/procurement/goods-receipts`.
It is **not** supported on transfer creation, exchange steps or approvals — all of which a
flaky network can duplicate. A double-submitted ₭4M transfer is a real incident.

### 8. No bulk tag resolution · Phase 6
200 scanned tags = 200 sequential `by-tag` calls. Proposed
`POST /api/v1/inventory/items/by-tags {tags:[…]}` → resolved + unresolved.
*Without it:* concurrency-limited fan-out with a progress bar.

### 9. No cross-branch availability endpoint · Phase 10
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

### 11. No price range filter on item search · Phases 4, 5
The spec asks for it; `GET /inventory/items` has no `minPrice`/`maxPrice`. Client-side
filtering of a paged list would be wrong, so the filter is dropped unless the params are added.

### 12. No wishlist · Phases 10, 11
Nothing in the codebase. Options: add `/customers/{id}/wishlist`; or model it as a
**quotation**, which already exists and is arguably the correct commercial concept; or
device-local, which makes it invisible to colleagues and close to useless.
*Recommendation:* quotations now, a real wishlist later.

### 13. No "request information" approval action · Phase 14
The spec lists it; no backend supports it. I will not simulate it with a rejection.

### 14. No app version endpoint · Phase 17
Needed for the forced-update gate: `GET /api/v1/app/version?platform=` →
`minSupported`, `latest`, `storeUrl`.

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
