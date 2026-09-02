# PHASE 6 — Barcode, QR & RFID Integration

Build the scanning framework.

## Barcode

Support device camera barcode scanning.

## QR

Support QR code scanning.

After scanning:

```text
Scan
 ↓
Identify Item
 ↓
Fetch Jewellery Item
 ↓
Display Digital Passport
```

## Scanner UX

Create a fast scanning interface:

```text
┌─────────────────────┐
│                     │
│     CAMERA          │
│                     │
│   ┌─────────────┐   │
│   │             │   │
│   │   SCAN      │   │
│   │             │   │
│   └─────────────┘   │
│                     │
│ Point at barcode/QR │
└─────────────────────┘
```

## RFID

Do not hardcode a specific RFID device.

Create an abstraction:

```text
ScannerService
    ├── BarcodeScanner
    ├── QRScanner
    └── RFIDScanner
```

The RFID implementation can later be connected to the retailer's selected hardware/SDK.

## Bulk Scan

Prepare architecture for:

```text
Scan multiple items
       ↓
Collect Item IDs
       ↓
Validate with Backend
       ↓
Display Result
```