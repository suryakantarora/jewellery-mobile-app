# Phase 8 — Warehouse & Vault Operations: Design for Review

Reuses Phase 5's stock-count engine and Phase 7's movement repository. Little new plumbing;
mostly new framing for a different user.

## 1. Backend contract (verified)

```text
GET    /api/v1/warehouse/bins?locationId=                WAREHOUSE_VIEW
POST   /api/v1/warehouse/bins                            WAREHOUSE_MANAGE
DELETE /api/v1/warehouse/bins/{id}                       WAREHOUSE_MANAGE
GET    /api/v1/warehouse/stock-counts?status=&locationId=&branchId=
GET    /api/v1/warehouse/stock-counts/{id}
POST   /api/v1/warehouse/stock-counts                    STOCK_COUNT_PERFORM
POST   /api/v1/warehouse/stock-counts/{id}/submit        STOCK_COUNT_PERFORM
POST   /api/v1/warehouse/stock-counts/{id}/approve       STOCK_COUNT_APPROVE
POST   /api/v1/warehouse/stock-counts/{id}/cancel?reason=
GET    /api/v1/branches/{branchId}/locations
GET    /api/v1/inventory/items?locationId=
POST   /api/v1/inventory/transfers  (movementType = ISSUE | RETURN)   INVENTORY_TRANSFER

BinType     = ZONE SHELF TRAY BIN SAFE
LocationType= HEAD_OFFICE CENTRAL_WAREHOUSE BRANCH_WAREHOUSE SHOWROOM COUNTER
              VAULT STORE_ROOM IN_TRANSIT
```

**Key mapping:** "issue" and "return" are not separate endpoints — they are movements with
`movementType = ISSUE` / `RETURN` on the Phase 7 controller, with the same
approve/dispatch/receive lifecycle. **Confirmed:** `CreateMovementRequest` is `{movementType, fromLocationId,
toLocationId, itemIds[], notes}`, so issue and return are movement types on the shared
controller. The mobile module reflects that rather than pretending they're a new domain.

"Tray management" maps to **bins**: `BinType.TRAY` under a location. There is no
item→bin assignment endpoint that I can find — bins can be listed and created, but nothing
places an item in one. If tray-level placement is required (and for a vault it usually is),
the backend needs `POST /warehouse/bins/{id}/items` or a `binId` on the item. *Decision needed.*

## 2. Vault inventory screen

```text
┌────────────────────────────────────────┐
│ Vault · Central Warehouse       [⌗]    │
│ 1,842 pcs · 14.2 kg · ₭2.1B            │  value gated by REPORT_VIEW
├────────────────────────────────────────┤
│ ▼ SAFE-1                        420 pcs│
│   ▼ TRAY-A                       84 pcs│
│       JW-000241 Ladies Ring …          │
│   ▶ TRAY-B                      112 pcs│
│ ▶ SAFE-2                      1,422 pcs│
└────────────────────────────────────────┘
```

Hierarchical bin tree (`ZONE › SHELF › TRAY › BIN › SAFE`) over `GET /warehouse/bins`, with
item counts. Without the bin→item link above, this degrades to a flat location item list plus
a bin directory — still useful, but the tree is the version worth having.

## 3. Issue flow

```text
Select item(s)     ──▶ from vault list or scan
      ↓
Scan to verify     ──▶ physical possession confirmed by scanning the tag,
      ↓                 not by tapping a row  ← the whole point
Destination        ──▶ location (showroom / counter / branch)
      ↓
Reason             ──▶ required, free text + preset reasons
      ↓
Authorization      ──▶ high-value: approval required (§4)
      ↓
Submit             POST /inventory/transfers  {movementType: ISSUE, …}
```

The scan-to-verify step is non-negotiable in the UI: an issue can only be raised for items
whose tags were physically read in this session. Manual override exists but is flagged in the
payload as manual, with a reason.

**Return** is the mirror: scan items coming back → destination vault location →
`movementType: RETURN` → condition note.

## 4. High-value operations

The backend decides what "high value" means — the app must not invent a threshold. What the
app does:

- Renders the approval state the movement comes back with (`PENDING_APPROVAL` → "Waiting for
  approval by …").
- Shows the full audit panel the spec asks for: **Requested By, Approved By, Item, Location,
  Reason, Timestamp** — sourced from the movement's history entries.
- Requires an explicit confirmation dialog restating item, value and destination before submit.
- Never renders "Issued" until the server says `COMPLETED`.

**Confirmed and better than expected.** `MovementResponse` carries `createdBy`, `approvedBy`/
`approvedAt`, `dispatchedBy`, `receivedBy`, `requiresApproval`, `rejectionReason` — and
**`secondApprovedBy`/`secondApprovedAt`**, meaning the backend already models dual
authorisation for high-value movements. The audit panel renders both signatures, and a movement
awaiting its second approval gets a distinct "1 of 2 approvals" state.

## 5. Physical verification

Exactly the Phase 5 stock-count session, entered from the warehouse context and defaulted to a
vault location. Same continuous scan, same matched/missing/unexpected counters, same
crash-safe local session, same submit-then-approve split:

```text
Expected: 250      Matched:    245
Scanned:  247      Missing:      5
                   Unexpected:   2
```

The reuse is deliberate — one counting engine, two entry points. Warehouse staff get a larger
touch target layout and a persistent wakelock, since a 250-item vault count is a 30-minute job.

**"Do not allow employees to silently modify stock counts"** is enforced structurally: the
submit payload contains observations only, `STOCK_COUNT_APPROVE` is a separate permission, and
the app offers no path from a count to a direct stock adjustment.

## 6. Reconciliation

After approval, a read-only reconciliation summary: expected vs counted, variance by category
and by metal, the resulting adjustments the backend made, and who approved. Requires
`STOCK_COUNT_APPROVE` or `REPORT_VIEW`. The app displays; it never computes the adjustment.

## 7. Deliverables

`VaultScreen` (bin tree), `BinDirectoryScreen`, `IssueFlow`, `ReturnFlow`,
`PhysicalVerificationScreen` (stock-count reuse), `ReconciliationSummaryScreen`,
`HighValueAuditPanel`, `WarehouseRepository`.

Tests: bin tree assembly, issue payload shape, scan-verified gating, count reuse regression.
