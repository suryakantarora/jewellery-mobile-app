# Phase 12 — Jewellery Repair Mobile: Design for Review

The best-specified module in the backend — the mobile app follows its state machine exactly.

## 1. Backend contract (verified)

```text
GET  /api/v1/repairs?status=&customerId=&branchId=&assignedTo=&page=   REPAIR_VIEW
GET  /api/v1/repairs/{id}                        (includes history)   REPAIR_VIEW
GET  /api/v1/repairs/overdue?branchId=                                REPAIR_VIEW
POST /api/v1/repairs                                                  REPAIR_PROCESS
POST /api/v1/repairs/{id}/inspection                                  REPAIR_PROCESS
POST /api/v1/repairs/{id}/estimate                                    REPAIR_ESTIMATE
POST /api/v1/repairs/{id}/customer-decision                           REPAIR_PROCESS
POST /api/v1/repairs/{id}/assign                                      REPAIR_PROCESS
POST /api/v1/repairs/{id}/complete-work                               REPAIR_PROCESS
POST /api/v1/repairs/{id}/quality-check                               REPAIR_PROCESS
POST /api/v1/repairs/{id}/deliver                                     REPAIR_PROCESS
POST /api/v1/repairs/{id}/cancel?reason=                              REPAIR_PROCESS
POST /api/v1/files                                                    FILE_UPLOAD

RepairStatus = RECEIVED INSPECTION ESTIMATION APPROVAL_PENDING DECLINED
               IN_PROGRESS QUALITY_CHECK READY DELIVERED CANCELLED
```

`RepairResponse` carries `allowedTransitions`, `conditionPhotoKeys`, `history[]`
(`fromStatus, toStatus, performedBy, notes, occurredAt`), plus `estimatedCost`,
`estimatedDays`, `customerApproved`, `assignedTo`, `finalCost`, `receivedWeight`,
`deliveredWeight`, `promisedDate`, `readyAt`, `deliveredAt`.

Two gifts here: `allowedTransitions` drives the action buttons with zero client logic, and
`history` makes the job-card timeline free.

## 2. Repair board

The spec's status list is a board, so it renders as one — a horizontally scrollable set of
status columns on tablet, a status tab bar on phone.

```text
┌──────────────────────────────────────────────┐
│ Repairs           [My jobs] [All]     [+ New]│
│ ◀ New(4) Inspection(2) Approval(3) …        ▶│
├──────────────────────────────────────────────┤
│ ▢  RP-0184                      APPROVAL_PEND│
│ IMG Somchai Vong · Ladies Ring 22K           │
│     Broken clasp · est ₭180,000 · 3 days     │
│     Promised 05 Sep          ⚠ overdue by 2  │
└──────────────────────────────────────────────┘
```

- **"My jobs"** filters on `assignedTo` = current user — the default view for an artisan.
- **Overdue** items (from `/repairs/overdue` and `promisedDate`) are pinned and flagged. A
  jewellery repair promised to a customer and forgotten is a reputational event; the app makes
  it impossible to miss.
- Status counts on the tabs come from `size=1` count calls per status (see Phase 3 — a single
  counts endpoint would replace ~8 calls here too).

## 3. Job card

```text
RP-0184                             APPROVAL_PENDING
──────────────────────────────────────────────────
Customer   Somchai Vong  +856 20 •••• 4821  [Call]
Item       JW-000241 Ladies Ring 22K  ›   (or free-text description)
Received   28 Aug   ·   Promised 05 Sep  ⚠
Weight in  8.420 g
──────────────────────────────────────────────────
Photos     [before] [damage] [+]        ← tap to view, long-press to caption
Problem    "Clasp broken, stone loose at 3 o'clock"
Condition  "Minor scratches on band"
──────────────────────────────────────────────────
Estimate   ₭180,000 · 3 days · by Nok  (2 Sep 10:14)
Customer   awaiting decision            [Record decision]
Artisan    unassigned                   [Assign]
──────────────────────────────────────────────────
History
  ● 02 Sep  ESTIMATION → APPROVAL_PENDING · Nok
  ● 01 Sep  INSPECTION → ESTIMATION · Nok
  ● 28 Aug  RECEIVED · Somchai (counter)
──────────────────────────────────────────────────
[ Primary action for current status ]
```

The action bar shows **one primary action** derived from `allowedTransitions ∩ permissions`,
with the rest under an overflow. Repair staff should not have to choose between eight buttons.

| Status | Primary action | Permission |
|---|---|---|
| `RECEIVED` | Start inspection | `REPAIR_PROCESS` |
| `INSPECTION` | Add estimate | `REPAIR_ESTIMATE` |
| `ESTIMATION` / `APPROVAL_PENDING` | Record customer decision | `REPAIR_PROCESS` |
| approved | Assign artisan | `REPAIR_PROCESS` |
| `IN_PROGRESS` | Complete work | `REPAIR_PROCESS` |
| `QUALITY_CHECK` | Pass / fail QC | `REPAIR_PROCESS` |
| `READY` | Deliver | `REPAIR_PROCESS` |

## 4. Camera & photos

The spec calls for Before / Damage / After images. Implementation:

```text
capture ──▶ compress (max 1920px, ~85% JPEG) ──▶ POST /api/v1/files?category=repair
        ──▶ storage key ──▶ attached via the relevant repair step request
```

- Photo **type** (before / damage / after) is solved: `conditionPhotoKeys` is an **opaque
  free-text field** (`max 1000`) stored verbatim, so the app defines the format. I will store a
  JSON array of `{key, type, capturedAt}`, giving full before/after typing with no backend
  change. **Caveat:** 1000 characters caps it at roughly 8–10 photos per repair — enough in
  practice, but the app will enforce the limit rather than let a save fail.
- Multiple captures in one session without leaving the camera.
- Upload is queued with retry and shows per-photo progress; a failed upload is visible and
  retryable rather than silently dropped. Photos are the evidence in a damage dispute, so
  "probably uploaded" is not acceptable.
- Before/after side-by-side comparison view on delivery.

## 5. Intake flow (new repair)

```text
Customer      ──▶ search / create (Phase 11 reuse)
Item          ──▶ scan an owned item (links jewelleryItemId) OR free-text
                  description for a customer's own piece not in inventory
Weigh in      ──▶ receivedWeight, 3 decimals
Photos        ──▶ before + damage, mandatory (locally enforced prompt)
Problem       ──▶ reported problem + condition on arrival
Promise date  ──▶ date picker
Submit        ──▶ POST /repairs
```

Weighing in **and** out (`receivedWeight` / `deliveredWeight`) is displayed prominently with
the delta on delivery — for a gold item, an unexplained weight change is the single thing a
customer will check.

## 6. Delivery

Requires the full picture on one screen: final cost, before/after photos, weight in vs out,
QC result, and who is collecting. `POST /repairs/{id}/deliver` with the recipient name.
A confirmation dialog restates the weight delta if it is non-zero.

## 7. Deliverables

`RepairBoardScreen`, `RepairJobCardScreen`, `RepairIntakeFlow`, `InspectionSheet`,
`EstimateSheet`, `CustomerDecisionSheet`, `AssignSheet`, `CompleteWorkSheet`, `QualityCheckSheet`,
`DeliverySheet`, `RepairPhotoCapture` + `PhotoUploadQueue`, `BeforeAfterComparison`,
`RepairRepository`.

Tests: status→action resolution across all 10 statuses, upload retry, overdue calculation,
weight delta display, permission split between `REPAIR_ESTIMATE` and `REPAIR_PROCESS`.
