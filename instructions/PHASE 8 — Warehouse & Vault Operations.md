# PHASE 8 — Warehouse & Vault Operations

Build mobile workflows for warehouse and vault employees.

## Features

- View vault inventory
- Tray management
- Issue item
- Return item
- Scan item
- Physical stock verification
- Stock reconciliation

## Issue

```text
Select Item
 ↓
Scan Item
 ↓
Verify
 ↓
Destination
 ↓
Authorization
 ↓
Issue
```

## High-value operations

Require backend-defined approval.

Display:

```text
Requested By
Approved By
Item
Location
Reason
Timestamp
```

## Physical Verification

Optimize for rapid scanning:

```text
Expected: 250
Scanned: 247

Matched: 245
Missing: 5
Unexpected: 2
```

Allow discrepancy submission.

Do not allow employees to silently modify stock counts.