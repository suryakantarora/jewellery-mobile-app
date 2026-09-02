# Phase 9 — Procurement & Goods Receiving: Design for Review

## 1. Backend contract (verified)

```text
GET  /api/v1/procurement/requisitions?…                    PROCUREMENT_VIEW
GET  /api/v1/procurement/requisitions/{id}
POST /api/v1/procurement/requisitions                      PROCUREMENT_CREATE
POST /api/v1/procurement/requisitions/{id}/approve|reject  PROCUREMENT_APPROVE
GET  /api/v1/procurement/purchase-orders?…                 PROCUREMENT_VIEW
GET  /api/v1/procurement/purchase-orders/{id}
POST /api/v1/procurement/purchase-orders                   PROCUREMENT_CREATE
POST /api/v1/procurement/purchase-orders/{id}/approve|reject|cancel|close
GET  /api/v1/procurement/goods-receipts?…                  PROCUREMENT_VIEW
GET  /api/v1/procurement/goods-receipts/{id}
POST /api/v1/procurement/goods-receipts    + X-Idempotency-Key   PROCUREMENT_RECEIVE
POST /api/v1/procurement/goods-receipts/{id}/accept|reject
GET  /api/v1/suppliers , /api/v1/suppliers/{id}            SUPPLIER_VIEW
POST /api/v1/inventory/items                               INVENTORY_CREATE
POST /api/v1/inventory/items/{id}/tags                     INVENTORY_CREATE
POST /api/v1/inventory/items/{id}/release                  INVENTORY_CREATE  ← QC pass

PurchaseOrderStatus = DRAFT PENDING_APPROVAL APPROVED REJECTED
                      PARTIALLY_RECEIVED RECEIVED CANCELLED CLOSED
GoodsReceiptStatus  = DRAFT PENDING_QUALITY_CHECK ACCEPTED REJECTED CANCELLED
RequisitionStatus   = DRAFT PENDING_APPROVAL APPROVED REJECTED ORDERED CANCELLED
```

**Goods receipts accept `X-Idempotency-Key`** — essential, because receiving is the one
workflow where a network retry could duplicate real stock.

## 2. Scope decision

Creating purchase orders on a phone is not a real use case — POs are authored in the Admin
portal with supplier terms and pricing. Mobile scope is therefore:

- **Read** requisitions, POs and suppliers
- **Approve/reject** requisitions and POs (also surfaced in Phase 14)
- **Receive** goods — the genuinely mobile workflow, done at a loading bay

I am deliberately not building PO authoring on mobile. Say the word if you want it and I'll add
it as a fifth screen.

## 3. Purchase order screens

**List** — status chips (`PENDING_APPROVAL`, `APPROVED`, `PARTIALLY_RECEIVED`, `RECEIVED`),
each row: PO number, supplier, expected date, line count, received progress bar, status badge.

**Detail** —

```text
PO-2026-0142                       APPROVED
Supplier   Bangkok Gold Co.
Ordered    2026-08-14   Expected 2026-09-05
Total      ₭84,200,000                        ← FINANCE_VIEW / PROCUREMENT_VIEW gated
──────────────────────────────────────────────
Lines
  Ladies Ring 22K · 20 pcs · 168.000 g   12/20 received
  Gents Chain 18K · 10 pcs ·  92.500 g    0/10 received
──────────────────────────────────────────────
Receipts   GR-0091 (accepted) · GR-0104 (pending QC)
──────────────────────────────────────────────
[Approve] [Reject]        ← PROCUREMENT_APPROVE, PENDING_APPROVAL only
[Receive goods]           ← PROCUREMENT_RECEIVE, APPROVED/PARTIALLY_RECEIVED only
```

## 4. Goods receiving flow

This is the phase's real deliverable. It is long, so it is a resumable draft, not a modal.

```text
1  Pick PO                    approved / partially received only
        ↓
2  Per line: receive qty      expected vs actual, short/over flagged
        ↓
3  Create or scan items       serialised jewellery: one record per physical piece
        │                     ├ scan an existing supplier tag → reuse
        │                     └ create item → POST /inventory/items
        ↓
4  Verify weight              gross / net metal / stone, entered per item
        │                     variance vs PO line highlighted; large variance
        │                     needs a note (client-side prompt only)
        ↓
5  Quality check              condition, purity confirmed, stone details,
        │                     certificate attach, photos
        ↓
6  Tag item                   POST /items/{id}/tags  {rfidTag, qrCode, barcode}
        │                     scan the new tag rather than typing it
        ↓
7  Submit receipt             POST /goods-receipts  + X-Idempotency-Key
        ↓  PENDING_QUALITY_CHECK
8  Accept / reject            POST /goods-receipts/{id}/accept|reject
        ↓                     PROCUREMENT_RECEIVE
   Items released to stock    POST /items/{id}/release  → AVAILABLE
```

Design rules:

- **Draft persists locally at every step.** Receiving 40 pieces takes an hour; a dropped
  connection or a killed app must not lose the weights already captured. The draft is local
  only — nothing is submitted until step 7.
- **One number pad, big.** Weight entry is the highest-volume interaction: numeric keyboard,
  3-decimal fixed, unit shown, previous value visible, auto-advance to the next item.
- Weight variance is **displayed and flagged, never blocked** client-side — the backend owns
  the tolerance rule. The app shows expected, actual and delta with a warning colour.
- A running summary bar (received / remaining / flagged) is always visible.
- Photos and certificates upload via `POST /api/v1/files` (`FILE_UPLOAD`), and the returned
  storage key is attached to the record — matching the backend's deliberate
  file-then-reference design.
- Accept/reject of the receipt is a **separate step with its own permission check**, so the
  person who counted is not necessarily the person who accepts.

## 5. Quality check screen

Per item: item code, product, expected vs actual weight, purity, stone details, condition
(preset + free text), certificate (attach/view), photos, and Pass / Fail. A failed item is
excluded from the receipt with a mandatory reason. Requires `PROCUREMENT_RECEIVE`;
`INVENTORY_CREATE` is additionally needed for the release step.

## 6. Gaps to confirm

1. ✅ **Resolved.** `CreateItemRequest` requires `productId`, `grossWeight`, `locationId`;
   everything else (metal, purity, size, tags, hallmark, costs, supplier, stones) is optional.
   **`netMetalWeight` is derived server-side and cannot be supplied** — the API itself enforces
   the no-client-arithmetic rule.
2. Does `GoodsReceiptRequest` accept per-line actual weights and created item ids, or does it
   reference items created beforehand? The flow above assumes items are created first, then
   referenced. *Please confirm.*
3. Supplier tag reuse — is there a supplier-reference field on the item to record the tag the
   goods arrived with?

## 7. Deliverables

`PurchaseOrderListScreen`, `PurchaseOrderDetailScreen`, `RequisitionListScreen`,
`SupplierDetailScreen`, `GoodsReceivingFlow` (6 resumable steps), `WeightEntryPad`,
`QualityCheckScreen`, `ItemTaggingScreen`, `ReceiptSummaryScreen`, `ProcurementRepository`,
local draft store, `FileUploadService`.

Tests: draft persistence across kill, idempotency key reuse on retry, variance display,
partial-receipt maths, permission split between receive and accept.
