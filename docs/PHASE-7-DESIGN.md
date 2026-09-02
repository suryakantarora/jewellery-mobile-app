# Phase 7 — Inventory Transfer: Design for Review

## 1. Backend contract (verified)

```text
GET  /api/v1/inventory/transfers?status=&movementType=&fromLocationId=&toLocationId=
                                &from=&to=&page=&size=      INVENTORY_VIEW
GET  /api/v1/inventory/transfers/{id}                       INVENTORY_VIEW
POST /api/v1/inventory/transfers                            INVENTORY_TRANSFER
POST /api/v1/inventory/transfers/{id}/approve               INVENTORY_TRANSFER_APPROVE
POST /api/v1/inventory/transfers/{id}/reject   {reason}     INVENTORY_TRANSFER_APPROVE
POST /api/v1/inventory/transfers/{id}/dispatch              INVENTORY_TRANSFER
POST /api/v1/inventory/transfers/{id}/receive  {…}          INVENTORY_TRANSFER
POST /api/v1/inventory/transfers/{id}/cancel                INVENTORY_TRANSFER

MovementStatus = DRAFT PENDING_APPROVAL APPROVED REJECTED DISPATCHED COMPLETED CANCELLED
MovementType   = GOODS_RECEIPT TRANSFER ISSUE RETURN ADJUSTMENT SALE_DELIVERY
                 SALE_RETURN REPAIR_OUT REPAIR_IN SCRAP
```

Note the endpoint is `/inventory/transfers` but the domain is **movements** — the same
controller serves issues, returns and adjustments (Phase 8 reuses it). The mobile module is
built as `movements` with a transfer-shaped default filter, so Phase 8 needs no new repository.

## 2. Status model

```text
DRAFT ──submit──▶ PENDING_APPROVAL ──approve──▶ APPROVED ──dispatch──▶ DISPATCHED
                        │                                                  │
                        └──reject──▶ REJECTED                       receive │
                                                                            ▼
   cancel (before dispatch) ──▶ CANCELLED                              COMPLETED
```

Items go `IN_TRANSIT` on dispatch and land at the destination on receive — the backend does
that, and the app must never simulate it. Every screen renders the status the server returned.

## 3. Screens

**Transfer list** — three tabs, because staff think in terms of their own job, not statuses:

| Tab | Filter | Who uses it |
|---|---|---|
| Outgoing | `fromLocationId ∈ my branch locations` | dispatcher |
| Incoming | `toLocationId ∈ my branch locations`, status `DISPATCHED` | receiver |
| All | branch-scoped, status filter chip row | manager |

Each row: transfer number, from → to, item count, status badge, age. An "Incoming" row with
`DISPATCHED` gets a prominent **Receive** affordance — that's the action people open the app
for.

**Create transfer** — a 4-step flow, scanner-first:

```text
1  Source location      (from my accessible locations)
2  Items                ┌──────────────────────────┐
                        │ [⌗ Scan items]           │  continuous ScanSession
                        │ or [Search & pick]       │  Phase 4 search, multi-select
                        │                          │
                        │ 12 items · 98.420 g      │  running totals
                        │  JW-000241  ✓            │  swipe to remove
                        └──────────────────────────┘
3  Destination          (branch → location; cross-branch allowed if permitted)
4  Reason + notes       then Review → Submit
```

Validation before submit, all client-side hints only: item must be `AVAILABLE` and at the
source location; duplicates rejected; destination ≠ source. Anything the backend rejects is
surfaced with its own message — the client checks are for speed, not authority.

**Transfer detail** — header (number, status, from → to, requested by, dates), item list with
per-item status, an approval/dispatch/receipt timeline built from the movement's history, and
a contextual action bar:

| Status | Actions shown |
|---|---|
| `DRAFT` | Edit, Submit, Cancel |
| `PENDING_APPROVAL` | Approve, Reject *(needs `INVENTORY_TRANSFER_APPROVE`)*, Cancel |
| `APPROVED` | Dispatch, Cancel |
| `DISPATCHED` | Receive |
| `COMPLETED` / `REJECTED` / `CANCELLED` | read-only |

Approve/Reject are also surfaced in the Phase 14 approval centre — same repository, same
confirmation dialogs, one implementation.

## 4. Receiving — the scan-and-reconcile flow

```text
Open dispatched transfer  ──▶ expected items (12)
        ↓
 ┌──────────────────────────────┐
 │ TR-10024  ·  Receiving       │
 │ Expected 12                  │
 │ Scanned  10   ✓ matched 10   │  continuous scan, no per-item taps
 │ Missing   2   ⚠ unexpected 1 │
 │ [Missing ▸] [Unexpected ▸]   │
 └──────────────────────────────┘
        ↓
 Discrepancy review — note per line, optional photo
        ↓
 [Confirm receipt]     POST /transfers/{id}/receive
```

Rules:

- Scan progress is **local until confirm**, restored after an app kill. Nothing is reported
  until the receiver commits.
- **Confirming a short receipt is allowed but never silent** — a full-screen confirmation
  spells out "2 items missing, 1 unexpected. This will be recorded against you and
  <sender>." Discrepancies go in the receive payload; the backend decides the consequence.
- A clean 12/12 receipt is one tap after the last scan.
- Receiving requires connectivity — this is an inventory state change, and per Phase 17 it is
  explicitly not offline-queueable.

**Contract confirmed.** `ReceiveMovementRequest = {lines: [{jewelleryItemId, receivedWeight,
discrepancyNote}], notes}` — per-item discrepancies and re-weighing are both supported, so the
flow above works as drawn. `MovementLineResponse` also carries a denormalised `itemCode`, so
transfer lines render without reference lookups.

## 5. Correctness rules

- Every mutating call carries the movement `version` where the response exposes one;
  `CONCURRENT_MODIFICATION` → "Someone else updated this transfer. Reload."
- Mutations use `X-Idempotency-Key` where the backend accepts it, and the app generates the key
  once per user intent (not per retry) so a flaky-network double-tap cannot create two
  transfers. **Transfers do not currently accept the header** — sales, payments and goods
  receipts do. Worth adding; a duplicated transfer of a ₭4M ring is a real incident.
- After any successful mutation, the affected item providers and the transfer list are
  invalidated so no stale `AVAILABLE` badge survives.

## 6. Deliverables

`TransferListScreen` (3 tabs), `TransferDetailScreen`, `CreateTransferFlow` (4 steps),
`TransferReceiveScreen` (scan reconcile), `DiscrepancyReviewScreen`, `TransferItemPicker`,
`MovementRepository`, status→action resolver, idempotency key manager.

Tests: status→action matrix, reconciliation maths (matched/missing/unexpected/duplicate),
session restore, idempotency key stability across retries.
