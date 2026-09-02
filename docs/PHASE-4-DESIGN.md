# Phase 4 — Jewellery Search & Digital Passport: Design for Review

This is the app's centre of gravity — Phases 5, 6, 7, 10 and 13 all navigate into it.

## 1. Backend contract (verified)

```text
GET /api/v1/inventory/items?search=&productId=&status=&locationId=&branchId=
                            &metalId=&purityId=&page=&size=&sort=itemCode
    → PageResponse<JewelleryItemResponse>
GET /api/v1/inventory/items/{id}            → JewelleryItemResponse
GET /api/v1/inventory/items/by-tag?tag=     → JewelleryItemResponse   ← RFID/QR/barcode/itemCode
GET /api/v1/inventory/items/{id}/passport   → ItemPassportResponse
GET /api/v1/jewellery-items/{itemId}/stones → List<StoneResponse>
GET /api/v1/stone-certificates
GET /api/v1/files?key=                      → binary (FILE_DOWNLOAD)
```

```text
ItemPassportResponse = { item, stones[], history[] }
JewelleryItemResponse = id, itemCode, productId, designId, metalId, purityId,
    grossWeight, netMetalWeight, stoneWeight, stoneCount, totalCarat, sizeId,
    rfidTag, qrCode, barcode, hallmarkNumber, purchaseCost, makingCost, stoneCost,
    totalCost, currentPrice, currency, status, allowedTransitions[],
    currentLocationId, currentBranchId, reservedForCustomerId, reservedUntil,
    supplierId, receivedDate, soldDate, ownerCustomerId, qualityChecked, notes, version
ItemStatus = DRAFT AVAILABLE RESERVED IN_TRANSIT SOLD UNDER_REPAIR RETURNED
             EXCHANGED BUYBACK SCRAPPED
LifecycleEventType = CREATED QUALITY_CHECKED TAGGED STATUS_CHANGED LOCATION_CHANGED
             RESERVED RESERVATION_RELEASED PRICE_UPDATED SOLD RETURNED REPAIRED
             EXCHANGED BOUGHT_BACK SCRAPPED
```

Two things to note, because they shape the whole design:

**`allowedTransitions` ships with every item.** The action buttons are therefore driven by the
backend's own state machine intersected with the user's permissions — the app never guesses
whether an item can be reserved.

**Everything else is a bare UUID.** `productId`, `metalId`, `purityId`, `currentLocationId`,
`supplierId` — no names. A list of 20 items would need ~60 extra lookups to render "22K Gold ·
Ring · Showroom Counter 2". See §2.

## 2. Reference-data cache (the fix for the UUID problem)

A `ReferenceDataService` loaded once per session (and on branch switch), holding id→name maps
for the small, slow-changing master sets:

```text
GET /api/v1/metals            GET /api/v1/metals/{id}/purities
GET /api/v1/product-categories  GET /api/v1/product-types
GET /api/v1/branches/{id}/locations
GET /api/v1/products (paged, lazily cached by id)  GET /api/v1/designs (same)
```

Metals, purities, categories, types and locations are small enough to prefetch outright.
Products/designs are lazy per-id with an LRU and request coalescing (20 list rows referencing
5 products issue 5 calls, not 20). Cached to disk with a version/TTL so a cold start on a slow
showroom connection isn't a blank list.

**Alternative worth raising with you:** have `JewelleryItemResponse` carry denormalised
`productName`, `metalName`, `purityCode`, `locationName`. That's the cheaper, more robust fix
and benefits the Admin portal too. If you'd rather not change the backend, the cache above
works — it's just more moving parts. *Please decide.*

## 3. Search

```text
┌──────────────────────────────────────┐
│ 🔍 Item code, barcode, RFID…    [⌗]  │  ⌗ = scan, opens Phase 6 camera
│ [Available ×] [22K ×] [Ring ×]  Clear│  active filter chips
├──────────────────────────────────────┤
│ ▢ IMG  JW-000241            AVAILABLE│
│        Ladies Ring · Classic Solitaire│
│        22K Gold · 8.420 g · ₭4,250,000│
│        Showroom · Counter 2           │
└──────────────────────────────────────┘
```

- 350 ms debounce; in-flight request cancelled on new keystrokes (Dio `CancelToken`).
- **Exact-match shortcut:** if the query looks like a tag or item code, `by-tag` is tried first
  and a single hit navigates straight to the passport. This is what makes a barcode typed by
  hand behave the same as a scan.
- Infinite scroll on `PageResponse` (`last` flag drives the end), pull-to-refresh, `size=20`.
- Recent searches and recently viewed items persisted locally (also the Phase 17 read-only
  cache seed).
- Filter sheet: Branch (limited to `branchIds`), Location, Category, Metal, Purity, Status,
  Price range. **Price range is not a backend parameter** — either add `minPrice`/`maxPrice` to
  the item search, or I drop the filter. Client-side filtering of a paged list would be wrong
  and I won't do it silently. *Decision needed.*

## 4. Digital Passport screen

Collapsing header with the image gallery, then sectioned content. Sticky action bar at the
bottom.

```text
╔══════════════════════════════╗
║        [ image gallery ]     ║  pinch-zoom, page dots
╠══════════════════════════════╣
║ JW-000241          AVAILABLE ║  itemCode + StatusBadge
║ Classic Solitaire · Ladies Ring
║ ₭4,250,000                   ║  currentPrice (PRICE/SALE_VIEW gated)
╟──────────────────────────────╢
║ ▸ Product   design, category, type, brand, collection, size
║ ▸ Metal     metal, purity, gross / net metal / stone weight, hallmark
║ ▸ Gemstones stone count, total carat, per-stone list → shape, carat,
║             colour, clarity, cut, setting
║ ▸ Certificate  number, issuer, date, [View document]
║ ▸ Location  branch › location › bin, since
║ ▸ Identifiers  RFID · QR · Barcode  (long-press to copy)
║ ▸ Lifecycle timeline
║ ▸ History   transfers · repairs · sales · exchanges
╟──────────────────────────────╢
║ [Transfer] [Reserve] [⋯]     ║  from allowedTransitions ∩ permissions
╚══════════════════════════════╝
```

**Lifecycle timeline** renders `passport.history` (`LifecycleEventResponse`) through the shared
`AppTimeline`, newest-first, each node showing event type, actor, location and timestamp. The
spec's illustrative chain (Purchased → Quality Checked → RFID Tagged → Warehouse → Branch →
Showroom → Counter) maps onto `CREATED / QUALITY_CHECKED / TAGGED / LOCATION_CHANGED`, so it is
rendered from real events rather than a hardcoded ladder — which matters, because real items
skip and repeat steps.

**Certificate** comes from `/stone-certificates`; the document is fetched via
`GET /files?key=` and needs `FILE_DOWNLOAD`. The endpoint returns
`Content-Disposition: attachment` + `application/octet-stream`, so the app downloads to a
temp file and opens it in a native viewer rather than trying to render it inline.

**Images: no image field exists on the item, product or design responses.** Files are uploaded
generically and referenced by storage key, but nothing links a key to an item. Either add
`imageKeys[]` to product/design/item, or the app shows a tasteful category-icon placeholder
everywhere an image is specified. *Decision needed* — this affects Phases 4, 5, 10 and 12
visibly.

## 5. Actions

| Action | Gate | Call |
|---|---|---|
| Transfer | `INVENTORY_TRANSFER` + status permits | → Phase 7 draft with item prefilled |
| Reserve | `INVENTORY_RESERVE` + `AVAILABLE` | `POST /inventory/reservations` |
| Release reservation | `INVENTORY_RESERVE` + `RESERVED` | `POST /items/{id}/release-reservation` |
| Start repair | `REPAIR_PROCESS` | → Phase 12 with item prefilled |
| View certificate | `FILE_DOWNLOAD` | `GET /files?key=` |
| Change status | `INVENTORY_ADJUST` | `POST /items/{id}/status` — confirmation dialog, reason required |

Buttons are computed as `allowedTransitions ∩ permissions`; anything else is hidden. Actions
that mutate use `PermissionDisabled` (visible, disabled, tooltip) rather than vanishing, so
staff can see what they'd need rights for.

`version` is carried on every mutation for optimistic locking — a `CONCURRENT_MODIFICATION`
error maps to "This item was changed by someone else. Reload?" with a reload button.

## 6. Deliverables

`ItemSearchScreen`, `ItemPassportScreen` + 8 section widgets, `ItemCard`, `LifecycleTimeline`,
`StoneList`, `CertificateViewer`, `ItemActionBar`, `ReferenceDataService` + cache,
`JewelleryRepository`, price-visibility gating, recently-viewed store.

Tests: by-tag exact-match routing, reference cache coalescing, action resolution against every
`ItemStatus`, optimistic-lock conflict handling.
