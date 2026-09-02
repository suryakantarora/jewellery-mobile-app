# Phase 16 — Mobile Reports: Design for Review

Deliberately small. The spec is explicit: do not rebuild the Admin BI system.

## 1. Backend contract (verified)

```text
GET /api/v1/reports/sales?from=&to=&branchId=            REPORT_VIEW
GET /api/v1/reports/inventory-valuation?branchId=        REPORT_VIEW
GET /api/v1/reports/stock-ageing?branchId=               REPORT_VIEW
GET /api/v1/reports/loyalty-liability                    REPORT_VIEW
GET /api/v1/sales/daily-closing                          SALE_VIEW
GET /api/v1/compliance/reports/high-value-transactions   COMPLIANCE_REPORT
GET /api/v1/compliance/reports/kyc-status                COMPLIANCE_REPORT
GET /api/v1/compliance/reports/audit-summary             COMPLIANCE_REPORT
GET /api/v1/finance/reports/…                            FINANCE_VIEW
```

Counts for the "pending" reports come from the module list endpoints with `size=1`
(`totalElements`), as in Phase 3.

## 2. Scope

| Report | Source | Gate |
|---|---|---|
| Today's sales | `/reports/sales?from=today&to=today` | `REPORT_VIEW` |
| Branch sales (period) | `/reports/sales?from=&to=&branchId=` | `REPORT_VIEW` |
| Inventory summary | `/reports/inventory-valuation` | `REPORT_VIEW` |
| Stock ageing | `/reports/stock-ageing` | `REPORT_VIEW` |
| Pending repairs | `/repairs?status=…` counts | `REPAIR_VIEW` |
| Pending transfers | `/inventory/transfers?status=…` counts | `INVENTORY_VIEW` |
| Pending approvals | Phase 14 aggregator | per-type |
| Customer summary | `/crm/…` + `/loyalty/loyalty-liability` | `CRM_VIEW` |
| Daily closing | `/sales/daily-closing` | `SALE_VIEW` |

Finance and compliance reports are **out of mobile scope** — they are dense, tabular and
regulated, and belong in the portal. The permissions exist, so they could be added; I'm
recommending against it unless you ask.

## 3. Design

```text
┌────────────────────────────────────────┐
│ Reports          Vientiane ⌄  Sep ⌄    │  branch + period selector, sticky
├────────────────────────────────────────┤
│ Sales                                  │
│  ₭128.4M    ▲ 12% vs last month        │
│  ┌──────────────────────────────────┐  │
│  │      ▁▂▃▅▇▆▅▃▂▁                  │  │  simple bar/line, no axes clutter
│  └──────────────────────────────────┘  │
│  42 sales · avg ₭3.05M                 │
│                                    ›   │
├────────────────────────────────────────┤
│ Inventory                              │
│  1,284 pcs · ₭2.1B                     │
│  ┌──────────────────────────────────┐  │
│  │ ███████░░░░  aging 0–30  62%     │  │  stacked bar, tap → item list
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

Chart rules, since charts are where mobile reports usually go wrong:

- **One idea per chart.** A phone-width chart with five series is unreadable; if a report needs
  five series, it is a portal report.
- Charts use `fl_chart` with the Phase 1 semantic palette, and every chart has a **table
  fallback** reachable by a toggle — a number you can read beats a trend you can squint at,
  and it is also the accessible path.
- Colour is never the only encoding (labels + patterns), and all charts render correctly in
  both themes.
- Every figure is tappable and drills into the underlying list, filtered — a report that can't
  answer "which items?" is decoration.
- No axis clutter, no gridlines below 3 values, no pie charts with more than 4 slices.

## 4. Permission and sensitivity

- Report tiles absent (not greyed) without permission.
- The branch selector is limited to `branchIds`; there is no "all branches" option unless the
  user is `superAdmin`, because an aggregate across branches would leak the ones they can't see.
- The "hide amounts" toggle from Phase 3 applies here too.
- **Export/share is deliberately omitted.** Emailing a branch P&L out of a phone is a data-loss
  vector, and the spec does not ask for it. If you want it, it should be a separate permission
  and a server-generated file, not a client-side CSV.

## 5. Deliverables

`ReportsScreen` (tiles), `SalesReportScreen`, `InventorySummaryScreen`, `StockAgeingScreen`
(shared with Phase 5), `PendingWorkScreen`, `CustomerSummaryScreen`, `DailyClosingScreen`,
`ReportChart` widgets + table fallbacks, period selector, `ReportingRepository` with a 5-minute
cache.

Tests: period boundary handling with branch timezones (`BranchResponse.timezone` — reports must
use the branch's day, not the device's), permission gating, chart/table parity.
