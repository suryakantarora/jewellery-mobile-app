# Phase 10 — Mobile Sales Assistance: Design for Review

Assistance, not transaction. Payment and final sale stay in POS/backend, as the spec requires.

## 1. Backend contract (verified)

```text
GET  /api/v1/inventory/items?search=&branchId=&status=AVAILABLE     INVENTORY_VIEW
GET  /api/v1/inventory/items/by-tag?tag=
GET  /api/v1/inventory/items/{id}/passport
POST /api/v1/inventory/reservations                                 INVENTORY_RESERVE
POST /api/v1/inventory/items/{id}/release-reservation
POST /api/v1/pricing/calculate                                      (pricing authority)
GET  /api/v1/metal-rates/current                                    METAL_VIEW
GET  /api/v1/customers?…  /api/v1/customers/by-phone?…              CUSTOMER_VIEW
POST /api/v1/customers                                              CUSTOMER_MANAGE
GET  /api/v1/quotations , POST /api/v1/quotations                   SALE_VIEW / SALE_CREATE
GET  /api/v1/sales , GET /api/v1/sales/{id}                         SALE_VIEW
GET  /api/v1/sales/daily-closing                                    SALE_VIEW
GET  /api/v1/branches                                               ORGANIZATION_VIEW
```

**Pricing is a backend call.** `POST /pricing/calculate` exists precisely so clients don't do
metal-rate arithmetic. The app never multiplies a rate by a weight — it posts the item and
renders what comes back, including making charges, stone value, tax and any discount policy.

## 2. Sales assistance flow

```text
Customer (optional)  ──▶ search by phone, or create, or continue anonymous
        ↓
Find jewellery       ──▶ scan (fast path) or search
        ↓
Digital passport     ──▶ Phase 4 screen, reused as-is
        ↓
Price               ──▶ POST /pricing/calculate  → breakdown sheet
        ↓
Availability        ──▶ this branch + other branches (§4)
        ↓
Reserve  ─or─  Quotation  ─or─  Hand off to POS
```

The whole flow is designed to be usable while standing next to a customer: large type, no
nested navigation deeper than three levels, and every screen reachable from the scanner.

## 3. Price display

```text
┌─────────────────────────────────┐
│ JW-000241 · Classic Solitaire   │
│                                 │
│ Metal   22K · 8.420 g           │
│   @ ₭412,000/g        ₭3,469,040│
│ Making charge            ₭280,000│
│ Stones                   ₭420,000│
│ Subtotal               ₭4,169,040│
│ Tax                       ₭80,960│
│ ─────────────────────────────── │
│ Total                  ₭4,250,000│
│                                 │
│ Rate as of 09:14 today          │  ← staleness matters
└─────────────────────────────────┘
```

Every line comes from the backend response. The rate timestamp is shown because a metal rate
from yesterday quoted to a customer is a real commercial risk; if the current rate is older
than a configurable window, a warning chip appears.

Price visibility is permission-gated. Cost fields (`purchaseCost`, `totalCost`) are **never**
shown here regardless of permission — this screen faces a customer.

**Discounts:** `GET /pricing/discount-policies` exists, and `PRICE_CHANGE` is a permission.
A salesperson without `PRICE_CHANGE` sees list price only; with it, a discount request can be
raised — and per Phase 14, discount approval is a backend decision, not a local override.

## 4. Cross-branch availability

```text
Vientiane        Available  (2)
Pakse            Available  (1)
Luang Prabang    0
```

**No aggregate endpoint exists.** Implementation: one `GET /inventory/items?productId=&branchId=
&status=AVAILABLE&size=1` per accessible branch, in parallel, reading `totalElements`. With
3–8 branches this is fine; beyond that it is not.

Two hard rules:
- **Only branches in the user's `branchIds`** are queried and shown. The spec is explicit that
  employees must not see branches they lack permission for, and the backend enforces
  `requireBranchAccess` anyway — so a forbidden branch would 403 rather than leak.
- Availability is by **product**, not by item — the customer wants "a ring like this", so the
  count is of comparable available items at each branch.

*Recommendation:* add `GET /api/v1/inventory/availability?productId=` returning per-branch
counts filtered to the caller's branch access. One call, no leak surface, and the Admin portal
wants it too.

## 5. Customer selection & wishlist

Customer search by phone (`/customers/by-phone`) is the fast path — it is how a returning
customer is actually identified. Creation uses the Phase 11 multi-step form, reused.

**Wishlist has no backend support.** No wishlist endpoint, table or field exists anywhere in
the codebase. Options:
- **A:** add a small backend wishlist (`/customers/{id}/wishlist`) — proper, shared with POS
  and the customer app later.
- **B:** model it as a **quotation** (`POST /quotations`), which already exists and is
  arguably what "items a customer is interested in" means commercially.
- **C:** device-local only — but then it is invisible to every other staff member, which makes
  it close to useless.

I recommend **B for now, A later**. *Decision needed.*

## 6. Sharing

"Share product details where permitted" — a share sheet producing a plain text/image summary
(item code, product, metal, purity, weight, price, branch). Gated by `SALE_VIEW`; cost fields
and internal identifiers are never included, and a config flag can disable sharing entirely for
a tenant. Sharing is an outbound disclosure of business data, so it is off by default and
enabled per deployment.

## 7. Reservation

`POST /inventory/reservations` with `{jewelleryItemId, customerId, holdHours, notes}` — so the
sheet needs a duration picker (presets: 2h / 24h / 48h / 7d). The item goes `RESERVED` with
`reservedUntil`. The item card then shows "Reserved for <customer> until <time>", and
`INVENTORY_RESERVE` holders can release it. Reservation is the app's legitimate substitute for
"holding" an item — no local hold state exists.

## 8. Deliverables

`SalesAssistScreen`, `PriceBreakdownSheet`, `CrossBranchAvailabilitySheet`,
`CustomerPickerSheet`, `ReserveItemSheet`, `ShareItemSheet`, `QuotationCreateFlow`,
`DailyClosingScreen`, `PricingRepository`, `AvailabilityRepository`.

Tests: pricing render from backend payload (no client arithmetic), branch filtering to
`branchIds`, rate-staleness warning, share payload field allow-list.
