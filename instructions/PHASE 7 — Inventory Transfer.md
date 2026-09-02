# PHASE 7 — Inventory Transfer

Build the complete stock-transfer workflow.

## Transfer

```text
Source Location
       ↓
Select Items
       ↓
Destination
       ↓
Reason
       ↓
Submit
       ↓
Approval
       ↓
Dispatch
       ↓
In Transit
       ↓
Receive
       ↓
Completed
```

## Mobile workflow

Optimize item selection using scanning.

Example:

```text
Transfer #TR-10024

From:
Central Warehouse

To:
Vientiane Showroom

Items:
12

[ Scan Items ]

12 / 12 Scanned

[ Submit Transfer ]
```

## Receiving

Receiver should:

1. Open transfer
2. Scan physical items
3. Compare expected vs scanned
4. Report discrepancies
5. Confirm receipt

Never allow the mobile application to directly manipulate inventory state without going through backend APIs.