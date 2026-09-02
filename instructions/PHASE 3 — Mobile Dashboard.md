# PHASE 3 — Mobile Dashboard

Build a role-aware mobile dashboard.

The dashboard must change according to user permissions and role.

## Dashboard

Display:

- Today's sales
- Inventory count
- Inventory value where permitted
- Pending transfers
- Pending approvals
- Pending repairs
- Notifications
- Tasks

## Quick Actions

Create configurable quick actions:

```text
Scan Jewellery
Search Inventory
Transfer Stock
Receive Stock
New Customer
Create Repair
Exchange
Buyback
```

Only show actions allowed by permissions.

## Branch Context

Always display:

```text
Institution
Branch
Location
```

clearly in the application.

## Role-specific Dashboard

Example:

### Salesperson

```text
Today's Sales
Customers
Scan Jewellery
Search Product
Create Customer
```

### Warehouse Staff

```text
Pending Transfers
Receive Stock
Scan Item
Stock Count
```

### Branch Manager

```text
Sales
Inventory
Approvals
Transfers
Branch Performance
```

### Repair Staff

```text
Pending Repairs
Assigned Jobs
Ready for Delivery
```

Use real backend APIs.

Do not use permanent mock data.