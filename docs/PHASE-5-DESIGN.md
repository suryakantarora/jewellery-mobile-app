# Phase 5 — Mobile Inventory: Design for Review

Builds on the Phase 4 search/passport foundation. Adds the operational views and the stock
count workflow.

## 1. Backend contract (verified)

```text
GET  /api/v1/inventory/items?...            (as Phase 4)
POST /api/v1/inventory/reservations         RESERVE
POST /api/v1/inventory/items/{id}/release-reservation
POST /api/v1/inventory/items/{id}/status    ADJUST
GET  /api/v1/reports/inventory-valuation?branchId=
GET  /api/v1/reports/stock-ageing?branchId=
GET  /api/v1/branches/{branchId}/locations
GET  /api/v1/warehouse/bins?locationId=
GET  /api/v1/warehouse/stock-counts?status=&locationId=&branchId=
GET  /api/v1/warehouse/stock-counts/{id}
POST /api/v1/warehouse/stock-counts                      STOCK_COUNT_PERFORM
POST /api/v1/warehouse/stock-counts/{id}/submit          STOCK_COUNT_PERFORM
POST /api/v1/warehouse/stock-counts/{id}/approve         STOCK_COUNT_APPROVE
POST /api/v1/warehouse/stock-counts/{id}/cancel?reason=
StockCountStatus = IN_PROGRESS PENDING_REVIEW APPROVED CLOSED CANCELLED
LocationType = HEAD_OFFICE CENTRAL_WAREHOUSE BRANCH_WAREHOUSE SHOWROOM COUNTER
               VAULT STORE_ROOM IN_TRANSIT
```

## 2. Inventory views — one screen, not six

The spec lists six screens (list, by branch, by location, by category, by metal, aging). Six
separate screens would be six near-identical code paths. Instead: **one `InventoryScreen` with
a grouping selector**, because the backend exposes them all as filters on the same endpoint.

```text
┌────────────────────────────────────────┐
│ Inventory            [⌗ scan]  [⚙ view]│
│ Group: ( None | Location | Category |  │  segmented control
│          Metal | Status )              │
│ [Available ×] [Vientiane ×]      Clear │
├────────────────────────────────────────┤
│ ▼ Showroom · Counter 2          42 pcs │  collapsible group headers with counts
│   ▢ JW-000241  Ladies Ring          …  │
│   ▢ JW-000242  Gents Ring           …  │
│ ▼ Vault                        318 pcs │
└────────────────────────────────────────┘
```

Grouping is applied to the **loaded page window** with the group's total taken from a
`size=1` count call per group — honest counts, no pretending a client-side group total is the
real one. Toggle between list and grid (grid is genuinely better for showroom staff browsing
visually).

**Stock aging** is a distinct screen because its data source is different
(`/reports/stock-ageing`): buckets (0–30 / 31–60 / 61–90 / 91–180 / 180+ days), each tapping
through to a filtered item list. Requires `REPORT_VIEW`.

**Inventory value** (`/reports/inventory-valuation`) is shown only with `REPORT_VIEW`, and the
per-item cost fields (`purchaseCost`, `makingCost`, `stoneCost`, `totalCost`) are gated the
same way — a salesperson sees `currentPrice`, never cost. This is a real commercial concern,
not a formality.

## 3. Item card

```text
┌────────────────────────────────────────┐
│ ▢    JW-000241              AVAILABLE  │
│ IMG  Classic Solitaire · Ladies Ring   │
│      22K Gold · 8.420 g                │
│      ₭4,250,000                        │
│      Showroom › Counter 2              │
└────────────────────────────────────────┘
```

Weights always 3 decimals with tabular figures; prices formatted per item `currency`. Long-press
opens a quick-action sheet (View, Transfer, Reserve, Repair, Copy code) — the same
`allowedTransitions ∩ permissions` resolution as Phase 4, so the logic lives in one place.

Multi-select mode (long-press then tap) feeds bulk transfer in Phase 7.

## 4. Stock count workflow

The one genuinely mobile-first workflow in this phase — it is done standing in a vault with a
phone in one hand.

```text
 Select location (+ bin)          POST /warehouse/stock-counts
        ↓                          → StockCountResponse with expected items
 Expected list loaded  (250)
        ↓
 ┌─────────────────────────────┐
 │ CONTINUOUS SCAN MODE        │   camera stays open, no per-scan confirmation
 │  Expected 250               │   haptic + tone on each result:
 │  Scanned  247               │     ✓ matched      short tick
 │  ✓ Matched    245           │     ⚠ unexpected   double buzz
 │  ✗ Missing      5           │     ↺ duplicate    soft click, no count change
 │  ⚠ Unexpected   2           │
 │  [Missing] [Unexpected] ▸   │   tap a counter to review that list
 └─────────────────────────────┘
        ↓
 Review discrepancies → note per line
        ↓
 Submit                          POST /stock-counts/{id}/submit
        ↓ PENDING_REVIEW
 Supervisor approves             POST /stock-counts/{id}/approve   (STOCK_COUNT_APPROVE)
```

Design rules that matter here:

- **Local-only until submit.** Scans accumulate in local session state; nothing touches the
  backend until `submit`. This is the one place offline scanning is safe, because no inventory
  state changes until the submit call — and if the app dies mid-count, the session is restored
  from local storage. A half-finished 250-item count must never be lost.
- **The counter never edits stock.** The app submits observations; the backend decides. The
  submit body carries scanned item ids and discrepancy notes only — no adjusted quantities.
  Approval is a separate permission and, per the spec, cannot be self-served.
- Screen stays awake (`wakelock`) during counting; large touch targets; one-handed reachable
  controls at the bottom.
- Duplicate scans are detected and ignored with distinct feedback — the most common real-world
  error.
- Manual entry fallback for a damaged/unreadable tag, flagged as manual in the submission.

## 5. Item actions

View · Transfer (→ Phase 7) · Reserve / Release · Receive (→ Phase 9) · Repair (→ Phase 12) ·
Return. Each gated by permission and `allowedTransitions`. "Return" has no direct endpoint —
it is `POST /items/{id}/status` with `RETURNED`, requires `INVENTORY_ADJUST`, a mandatory
reason and a confirmation dialog. Flagged for your confirmation that this is the intended
mapping.

## 6. Deliverables

`InventoryScreen` (grouping, filters, list/grid), `StockAgeingScreen`,
`InventoryValuationCard`, `ItemCard`, `ItemQuickActionSheet`, multi-select,
`StockCountListScreen`, `StockCountSessionScreen` (continuous scan), `DiscrepancyReviewScreen`,
`StockCountRepository` with crash-safe local session persistence.

Tests: grouping/count correctness, duplicate-scan handling, session restore after kill,
cost-field permission gating, submit payload shape.
