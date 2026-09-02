# PHASE 14 — Mobile Approval Center

Build a centralized approval system.

## Pending approvals

Display:

```text
Discount
Stock Transfer
Buyback
Exchange
Purchase Order
Repair Estimate
High-value Transaction
```

## Approval detail

Display:

```text
Request
Requested By
Branch
Customer
Item
Amount
Reason
Documents
History
```

Actions:

```text
Approve
Reject
Request Information
```

## Security

For sensitive operations:

- Require confirmation
- Show complete details
- Show approval history
- Never approve using client-side assumptions

All final authorization must happen on the backend.