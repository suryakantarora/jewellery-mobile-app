# Phase 13 — Exchange & Buyback Mobile: Design for Review

The most financially sensitive module. Its central rule — *the app must never independently
calculate or approve financial values* — shapes every decision below.

## 1. Backend contract (verified)

```text
GET  /api/v1/exchanges?status=&exchangeType=&customerId=&branchId=&page=  EXCHANGE_VIEW
GET  /api/v1/exchanges/{id}                                              EXCHANGE_VIEW
POST /api/v1/exchanges                                                   EXCHANGE_PROCESS
POST /api/v1/exchanges/{id}/weigh                                        EXCHANGE_PROCESS
POST /api/v1/exchanges/{id}/purity-test                                  EXCHANGE_PROCESS
POST /api/v1/exchanges/{id}/valuation                                    EXCHANGE_VALUE
POST /api/v1/exchanges/{id}/approve                                      EXCHANGE_APPROVE
POST /api/v1/exchanges/{id}/reject?reason=                               EXCHANGE_APPROVE
POST /api/v1/exchanges/{id}/complete                                     EXCHANGE_PROCESS
POST /api/v1/exchanges/{id}/return?reason=                               EXCHANGE_PROCESS
GET  /api/v1/metal-rates/current                                         METAL_VIEW
GET  /api/v1/metal-rates?…                                               METAL_VIEW

ExchangeType   = EXCHANGE | BUYBACK
ExchangeStatus = RECEIVED WEIGHED PURITY_TESTED VALUED PENDING_APPROVAL
                 APPROVED REJECTED COMPLETED RETURNED_TO_CUSTOMER CANCELLED
RateType       = SELLING | BUYING | EXCHANGE
```

The backend's step endpoints map one-to-one onto the spec's flow. **Correction from the first
draft:** there is no `BUYBACK_VALUATION` permission — I had mistaken a `control_type` string
literal in a compliance SQL report for a permission code. Buyback valuation is gated by
`EXCHANGE_VALUE`, the same as an exchange. Exchange and buyback are **one workflow
distinguished by `exchangeType`** — so the mobile module is one flow with a type switch, not
two near-duplicate implementations.

`RateType` having a distinct `BUYING` rate is the reason the app must not reuse the selling
rate it already has cached from Phase 10. Rates are fetched per purpose.

## 2. The calculation rule, made structural

Not a guideline — enforced by how the code is written:

1. **No arithmetic on money or metal value exists in the mobile codebase.** Net weight,
   deductions, rate application, and final valuation are all read from
   `ExchangeResponse`. There is no `calculateValuation()` function to accidentally call.
2. The valuation step **posts inputs** (weights, purity result, deduction notes) and
   **renders the returned figures**. If the backend returns nothing, the screen shows "Awaiting
   valuation", never a locally derived number.
3. Any number displayed to a customer is traceable to a field in a server response. Code review
   rule for this module: if a `BigDecimal`-equivalent is combined with `*` or `+` in
   `features/exchange/`, it is a bug.
4. Approval is a server call. There is no local "approved" state.

**Confirmed by the contract.** `ValuationRequest` is `{deductionPercentage, notes}` — the
client posts a deduction percentage and nothing else; the backend derives net weight, applies
the buying rate and returns the valuation. The design is not merely a convention here, it is
the only thing the API allows.

## 3. Flow

```text
   New exchange / buyback
        │  type: EXCHANGE | BUYBACK
        ▼
   Customer            (Phase 11 reuse; required)
        ▼
   Receive item        POST /exchanges   → RECEIVED
        │  description, photos, metal, claimed purity
        ▼
   Weigh               POST /{id}/weigh  → WEIGHED
        │  gross weight, stone weight  (net is returned, not computed)
        ▼
   Purity test         POST /{id}/purity-test → PURITY_TESTED
        │  method (touchstone / XRF / acid), tested purity, tester
        ▼
   Valuation           POST /{id}/valuation   → VALUED / PENDING_APPROVAL
        │  deductions + notes in; rate, gross value, deductions,
        │  net payable out  ← all server-side
        ▼
   Approval            POST /{id}/approve | /reject     EXCHANGE_APPROVE
        ▼
   Complete            POST /{id}/complete → COMPLETED
   or Return           POST /{id}/return   → RETURNED_TO_CUSTOMER
```

Each step is its own screen with a single purpose and a large numeric pad — this is done at a
counter with a customer watching and a scale on the desk.

## 4. Valuation screen

```text
┌──────────────────────────────────────┐
│ EX-0042 · BUYBACK          VALUED    │
│ Somchai Vong                         │
├──────────────────────────────────────┤
│ Gross weight            12.480 g     │  entered
│ Stone weight             1.200 g     │  entered
│ Net metal weight        11.280 g     │  ← from server
│ Purity tested            21.6 K      │  entered
│ Buying rate         ₭398,000/g       │  ← from server, with timestamp
│                                      │
│ Gross value          ₭4,489,440      │  ← server
│ Deductions             ₭120,000      │  ← server
│ ──────────────────────────────────── │
│ Net payable          ₭4,369,440      │  ← server
│                                      │
│ Rate as of 09:14 today               │
│ Valued by Nok · 02 Sep 11:20         │
├──────────────────────────────────────┤
│ ⚠ Requires approval before payout    │
│ [Submit for approval]                │
└──────────────────────────────────────┘
```

Server-sourced figures are visually distinct from entered ones (subtle background tint plus a
legend), so staff can never mistake an input for a computed result. The rate timestamp is
shown for the same reason as Phase 10 — an old buying rate is money lost.

## 5. Approval & audit

Approval is available here and in the Phase 14 approval centre, sharing one implementation.
The approval screen shows the complete chain: who received, who weighed, who tested purity,
who valued, with timestamps — an old-gold buyback is exactly the transaction an auditor will
ask about, and the four-eyes trail must be visible on the device that authorised it.

Confirmation dialog restates customer, item, net weight, purity and payable amount before the
approve call. Rejection requires a reason.

## 6. Photos

Item photos at receipt (mandatory prompt) and at completion, via the Phase 12 upload queue.
For a buyback, the photo is the record of what was handed over.

## 7. Screens

`ExchangeListScreen` (type + status filters, "needs my approval" pinned),
`ExchangeDetailScreen` (status timeline + step actions), `NewExchangeFlow`,
`WeighScreen`, `PurityTestScreen`, `ValuationScreen`, `ApprovalScreen`, `CompleteScreen`,
`ReturnToCustomerScreen`, `MetalRateCard`.

## 8. Deliverables & tests

`ExchangeRepository`, step-wise flow with resumable local drafts (before the first POST only —
after `RECEIVED` the server holds state), rate fetching with `RateType.BUYING`, screen guard on
valuation screens.

Tests: status→action matrix across all 10 statuses, permission split
(`EXCHANGE_PROCESS` / `EXCHANGE_VALUE` / `EXCHANGE_APPROVE`), a static-analysis test asserting **no multiplication or
addition of monetary fields in `features/exchange/`**, rate staleness warning.
