# Phase 3 — Dashboard: Design for Review

## 1. The blocking finding

The phase says *"Use real backend APIs. Do not use permanent mock data."*
**There is no dashboard or summary endpoint in the backend.** Every tile has to be composed
from a module endpoint, and several of the requested tiles have no cheap source at all.

| Tile | Real source available today | Cost |
|---|---|---|
| Today's sales | `GET /reports/sales?from=today&to=today&branchId=` | 1 call, good |
| Inventory count | `GET /inventory/items?branchId=&size=1` → `totalElements` | 1 call, acceptable |
| Inventory value | `GET /reports/inventory-valuation?branchId=` | 1 call, good |
| Pending transfers | `GET /inventory/transfers?status=PENDING_APPROVAL&size=1` | 1 call |
| Transfers to receive | `GET /inventory/transfers?status=DISPATCHED&toLocationId=` | 1 call |
| Pending repairs | `GET /repairs?status=...&branchId=&size=1` | **one call per status** — 4+ calls |
| Pending approvals | no unified endpoint — see Phase 14 | **5+ calls** |
| Notifications | no per-user inbox — see Phase 15 | **not available** |
| Tasks | `GET /crm/follow-ups/mine` is the closest thing | 1 call, partial |

**Recommendation:** add one backend endpoint —

```text
GET /api/v1/dashboard/summary?branchId={uuid}
→ { todaySales{count,gross,net,currency}, inventory{count,value?},
    transfers{pendingApproval,inTransitToMe,pendingDispatch},
    approvals{byType{...},total}, repairs{byStatus{...},overdue},
    notifications{unread}, tasks{dueToday,overdue} }
```

It should return only the sections the caller's permissions allow (omit `inventory.value`
without `REPORT_VIEW`/`FINANCE_VIEW`), which also solves the "inventory value where permitted"
requirement server-side rather than by client-side trust.

**Decision needed from you.** Option A: add that endpoint (recommended — one round trip, and
the permission filtering is authoritative). Option B: fan out client-side. The design below
works either way: `DashboardRepository` exposes one `DashboardSummary` model, and only its
implementation differs. I will build the fan-out implementation so Phase 3 is not blocked, and
swap it for the single call when the endpoint exists.

Fan-out safeguards if we go with B: all calls issued in parallel with `Future.wait`,
**each tile fails independently** (a `AsyncValue` per tile, so one 403 does not blank the
dashboard), `size=1` used purely for `totalElements`, and a 60-second in-memory cache so
pull-to-refresh is the only thing that re-fires them.

## 2. Layout

```text
┌─────────────────────────────────────────┐
│ ABC Jewellery › Vientiane › Showroom  ⌄ │  BranchContextBar (tap = switch)
│ Good morning, Somchai        🔔 3   ⚙   │  AppHeader
├─────────────────────────────────────────┤
│  ┌───────────┐ ┌───────────┐            │
│  │ Today's   │ │ Inventory │            │  StatTile grid, 2-up phone / 4-up tablet
│  │ Sales     │ │ 1,284 pcs │            │  each tile owns its own load/error state
│  │ ₭12.4M    │ │ ₭2.1B     │            │
│  └───────────┘ └───────────┘            │
├─────────────────────────────────────────┤
│ Quick actions                            │
│ [Scan] [Search] [Transfer] [Receive]     │  horizontal, permission-filtered
├─────────────────────────────────────────┤
│ Needs your attention                     │
│ • 3 transfers awaiting approval      ›   │  actionable rows, deep-link to filtered lists
│ • 2 shipments to receive             ›   │
│ • 5 repairs ready for delivery       ›   │
├─────────────────────────────────────────┤
│ My tasks                             ›   │  crm/follow-ups/mine
└─────────────────────────────────────────┘
```

Pull-to-refresh on the whole page. Skeleton tiles on first load, never a full-screen spinner.

## 3. Role-aware composition — how it actually works

Not `if (role == 'SALESPERSON')`. Roles are backend-configurable, so hardcoding role codes
would break the moment a customer defines "Senior Sales". Instead **every tile and quick action
declares its own required permission**, and the dashboard renders the ones that pass:

```dart
const _tiles = [
  DashboardTile.todaySales(requires: Permission.saleView),
  DashboardTile.inventoryValue(requires: Permission.reportView),
  DashboardTile.pendingTransfers(requires: Permission.inventoryTransfer),
  DashboardTile.pendingApprovals(requiresAny: [inventoryTransferApprove,
      procurementApprove, exchangeApprove, stockCountApprove]),
  DashboardTile.pendingRepairs(requires: Permission.repairView),
];
```

The role examples in the spec then fall out naturally — a salesperson with `SALE_VIEW`,
`CUSTOMER_*` and `INVENTORY_VIEW` sees exactly the sales/customer/scan set; warehouse staff
with `INVENTORY_TRANSFER` + `STOCK_COUNT_PERFORM` see transfers and counting. No role strings
in the mobile codebase at all.

**Ordering** is by role weight: a small `DashboardLayout` resolver ranks tiles using the
permission set (e.g. `STOCK_COUNT_PERFORM` present → warehouse-first ordering), so a manager
and a warehouse clerk get different *priorities*, not just different *subsets*. This is
presentation-only and safe.

Quick actions map 1:1 to the spec list, each gated:

| Action | Permission | Route |
|---|---|---|
| Scan Jewellery | `INVENTORY_VIEW` | `/scan` |
| Search Inventory | `INVENTORY_VIEW` | `/inventory` |
| Transfer Stock | `INVENTORY_TRANSFER` | `/transfers/new` |
| Receive Stock | `PROCUREMENT_RECEIVE` | `/procurement/receive` |
| New Customer | `CUSTOMER_MANAGE` | `/customers/new` |
| Create Repair | `REPAIR_PROCESS` | `/repairs/new` |
| Exchange | `EXCHANGE_PROCESS` | `/exchange/new` |
| Buyback | `EXCHANGE_PROCESS` | `/exchange/new?type=BUYBACK` |

User-reorderable, persisted locally; a "customise" sheet lists only permitted actions.

## 4. Money and sensitivity

- Every monetary figure passes through `Formatters.money(amount, currency)` with tabular
  figures; currency comes from the backend response, never assumed.
- A "hide amounts" toggle (persisted) blurs monetary tiles — genuinely useful on a shop floor
  where a customer can see the staff device. Cheap to add, and the kind of thing enterprise
  buyers ask for.
- Tiles the user lacks permission for are **absent**, not greyed — no signalling of what exists.

## 5. Deliverables

`DashboardScreen`, `StatTile`, `AttentionList`, `QuickActionBar`, `QuickActionCustomiseSheet`,
`DashboardRepository` (fan-out impl + single-call impl behind one interface),
`dashboard_providers.dart` with per-tile `AsyncValue`s, 60s cache, branch-scoped invalidation.

Tests: permission→tile resolution matrix for the four example roles, partial-failure rendering
(one tile 403, rest fine), branch switch clears figures.
