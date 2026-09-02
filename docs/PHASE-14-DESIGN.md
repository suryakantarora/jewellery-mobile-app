# Phase 14 — Mobile Approval Center: Design for Review

## 1. The finding

**There is no unified approvals endpoint.** Approvals live on each module, each with its own
status filter and its own approve/reject call:

| Approval type | List source | Approve | Permission |
|---|---|---|---|
| Stock transfer | `GET /inventory/transfers?status=PENDING_APPROVAL` | `POST /transfers/{id}/approve` | `INVENTORY_TRANSFER_APPROVE` |
| Purchase order | `GET /procurement/purchase-orders?status=PENDING_APPROVAL` | `POST /purchase-orders/{id}/approve` | `PROCUREMENT_APPROVE` |
| Requisition | `GET /procurement/requisitions?status=PENDING_APPROVAL` | `POST /requisitions/{id}/approve` | `PROCUREMENT_APPROVE` |
| Exchange / buyback | `GET /exchanges?status=PENDING_APPROVAL` | `POST /exchanges/{id}/approve` | `EXCHANGE_APPROVE` |
| Stock count | `GET /warehouse/stock-counts?status=PENDING_REVIEW` | `POST /stock-counts/{id}/approve` | `STOCK_COUNT_APPROVE` |
| Repair estimate | `GET /repairs?status=APPROVAL_PENDING` | `POST /repairs/{id}/customer-decision` | `REPAIR_PROCESS` |
| Discount | **no endpoint** (permissions exist) | — | `DISCOUNT_REQUEST` / `DISCOUNT_APPROVE` |
| High-value transaction | **no endpoint found** | — | — |

So: the spec lists seven approval types; five map cleanly, one (repair estimate) is a
*customer* decision rather than a staff approval, and two have no backend at all.

**Recommendation:** add `GET /api/v1/approvals/pending` returning a normalised list
(`{type, id, reference, requestedBy, branchId, amount?, currency?, summary, requestedAt}`)
scoped to what the caller can actually approve, plus `POST /api/v1/approvals/{type}/{id}/decision`.
One call replaces five, the counts for the Phase 3 dashboard become free, and — the real
argument — the *set of things I can approve* becomes a server-side decision rather than
something the client assembles from permission guesses.

**Ships now:** an `ApprovalAggregator` that fans out to the five real sources in parallel,
skipping any the user lacks permission for, and normalises them into one `ApprovalItem` model.
Same UI either way; only the repository changes. *Decision needed.*

Discount and high-value approvals are **not buildable** without backend support. I will leave
placeholders that render an empty state rather than fake them.

**Correction from the first draft:** `DISCOUNT_REQUEST` and `DISCOUNT_APPROVE` *do* exist in
`identity.permission` and are granted to `SUPER_ADMIN` — I missed them originally because they
are seeded in a migration and never referenced by a `hasAuthority(...)` annotation. That is the
finding: the permissions are defined but **nothing enforces them**, because no discount-approval
endpoint exists. `/api/v1/pricing/discount-policies` manages policies, not approvals.

## 2. Approval centre

```text
┌──────────────────────────────────────────┐
│ Approvals                          (11)  │
│ [All] [Transfers 3] [Exchanges 2] [POs 4]│
│ [Counts 1] [Repairs 1]                   │
├──────────────────────────────────────────┤
│ ⬤ EXCHANGE · BUYBACK                     │  colour-coded by type
│   EX-0042 · Somchai Vong                 │
│   ₭4,369,440                             │  amount prominent when present
│   Nok · Vientiane · 2h ago               │
│   [Approve] [Reject]              ›      │  inline actions
├──────────────────────────────────────────┤
│ ⬤ TRANSFER                               │
│   TR-10024 · 12 items                    │
│   Warehouse → Vientiane Showroom         │
│   Bounma · 5h ago                   ›    │
└──────────────────────────────────────────┘
```

- Sorted by age, oldest first, with an ageing indicator — approvals are a queue, and the
  metric that matters is how long someone has been blocked.
- Type tabs with counts; empty state per tab.
- Pull-to-refresh; auto-refresh on resume.
- Inline Approve/Reject for **low-risk, low-value** items only. Anything with a monetary
  amount, or any exchange/buyback, forces the detail screen first — see §4.

## 3. Approval detail

Renders every field the spec asks for, sourced per type:

```text
Request        EX-0042 · Buyback
Requested by   Nok (Sales Associate)          from the record's history/audit
Branch         Vientiane
Customer       Somchai Vong                    where applicable
Item           Old gold chain · 12.480 g · 21.6K
Amount         ₭4,369,440
Reason         "Customer buyback, walk-in"
Documents      [purity report] [photo 1] [photo 2]
History        ● valued by Nok      02 Sep 11:20
               ● purity tested Nok  02 Sep 11:05
               ● weighed by Nok     02 Sep 11:00
               ● received by Nok    02 Sep 10:52
```

Where a field is unavailable for a type, it is omitted rather than shown blank.

## 4. Security design

The spec's *"never approve using client-side assumptions"* is implemented as:

1. **Two-step for consequential approvals.** Anything with an amount, or of type exchange /
   buyback / purchase order, cannot be approved from the list — the detail screen must be
   opened, and the confirmation dialog restates request, amount, requester and item. A
   mis-tap must not authorise ₭4M.
2. **Fresh read before decision.** The detail screen re-fetches the record immediately before
   showing the confirm dialog; if the status is no longer pending, the action is blocked with
   "This was already decided by …". Prevents the double-approve race when two managers open
   the same item.
3. **Rejection requires a reason** — free text, minimum length, no preset-only path.
4. **Optional biometric re-authentication** for approvals above a configurable amount, reusing
   the Phase 2 biometric service. Off by default, enabled per deployment.
5. The app **never** shows "Approved" until the server responds with the new status.
6. Every decision invalidates the source module's providers so the transfer/exchange list is
   immediately correct.
7. Approve/reject buttons appear only when the user holds the specific permission for **that
   type** — a `PROCUREMENT_APPROVE` holder sees exchanges in the list only if they also hold
   `EXCHANGE_APPROVE`; otherwise those items are not fetched at all.

## 5. "Request information"

The spec lists a third action. **No backend supports it.** Closest available: for exchanges and
repairs there are reject-with-reason paths, and CRM activities can record a note — but neither
is "return to requester for more information". Options: add a `REQUEST_INFO` decision to the
approval endpoint, or drop the action. I will not simulate it with a rejection. *Decision needed.*

## 6. Deliverables

`ApprovalCenterScreen`, `ApprovalDetailScreen` (per-type renderers), `ApprovalItem` normalised
model, `ApprovalAggregator` (+ single-endpoint implementation behind the same interface),
`ApprovalConfirmDialog`, `RejectReasonSheet`, ageing indicators, biometric gate.

Tests: aggregation with partial permissions, stale-status race blocking, two-step enforcement
for amount-bearing items, per-type permission gating, decision→invalidation propagation.
