# Phase 6 — Barcode, QR & RFID: Design for Review

## 1. Backend contract

One endpoint does the identification work:

```text
GET /api/v1/inventory/items/by-tag?tag={value}   → JewelleryItemResponse
```

Its doc string is explicit: *"Resolve an item by RFID, QR, barcode or item code."* So the app
does **not** need to know which symbology produced a value — it passes the string through.
That is the right split, and the whole scanner design leans on it.

Bulk validation has no endpoint. See §5.

## 2. Abstraction

```text
abstract ScannerService
   Stream<ScanResult> scans
   Future<void> start() / stop() / dispose()
   ScannerCapabilities get capabilities   // torch, zoom, continuous, bulk

   ├── CameraScannerService   (mobile_scanner — barcode + QR, one implementation)
   ├── RfidScannerService     (abstract; NoOpRfid ships in Phase 6)
   └── ManualEntryService     (keyboard fallback, always available)

ScanResult = { rawValue, format, source: camera|rfid|manual, timestampMs }
```

Barcode and QR are deliberately **not** separate implementations — they are one camera
pipeline with a format filter, because that is how every scanning SDK actually works. The
spec's tree is honoured at the `ScanResult.format` level rather than by duplicating a service.

**RFID stays unimplemented on purpose.** `RfidScannerService` defines
`connect() / disconnect() / setPower() / Stream<TagRead> tags` plus a discovery hook, and the
app ships a `NoOpRfidScanner` that reports unavailable. When the retailer picks hardware
(Zebra, Chainway, TSL…), one class implements the interface and registers itself — no screen
changes. A `ScannerRegistry` provider picks the best available source at runtime and the UI
shows an "RFID reader connected" chip when one appears.

## 3. Scanner UX

```text
┌─────────────────────┐
│  ⚡torch      ✕ close│
│                     │
│    ┌───────────┐    │  reticle, dimmed surround
│    │           │    │  green flash + haptic on hit
│    │           │    │
│    └───────────┘    │
│  Point at barcode   │
│  or QR code         │
│ ─────────────────── │
│ [Single] [Bulk]  ⌨  │  mode switch + manual entry
└─────────────────────┘
```

Fast path is everything here:

- **No confirmation step.** A successful single scan resolves and navigates straight to the
  passport. A staff member scanning 40 items must not tap "OK" 40 times.
- Torch toggle (vaults are dark), pinch zoom, tap-to-focus.
- Haptic + short tone per outcome — distinct patterns for hit, not-found, duplicate. Staff
  learn the sounds and stop looking at the screen, which is the actual speed win.
- Camera permission denied → an explanatory state with a deep link to system settings, plus
  manual entry, not a dead end.
- Debounce: the same value within 1.5 s is ignored (camera decoders fire repeatedly).
- Scanner is a full-screen route (`/scan`), reachable from the centre FAB, from any search
  field's scan icon, and from workflows that need it (transfer, receive, count) via a
  `ScanRequest` argument declaring what the caller wants back.

**Not-found handling** matters more than the happy path: `NOT_FOUND` from `by-tag` shows the
scanned value, offers "Search manually" and "Scan again", and stays in camera mode. In a
warehouse, an unknown tag is a finding, not an error.

## 4. Scan → item flow

```text
ScanResult ─▶ normalise (trim, strip URL prefix if a QR encodes a link)
           ─▶ GET /items/by-tag?tag=
                ├─ 200 ──▶ push /inventory/item/{id}   (passport)
                ├─ 404 ──▶ not-found sheet, stay scanning
                └─ 403 ──▶ permission state
```

QR normalisation is worth calling out: if the retailer encodes QRs as
`https://…/item/JW-000241`, the raw value must be reduced to the code before the lookup. A
small, configurable `TagNormaliser` handles prefix stripping; the rules live in config, not in
code.

## 5. Bulk scan

```text
Continuous scan  ──▶ local ScanSession (ordered, de-duplicated)
       ↓                 shows running count + last 5 scanned
Review list      ──▶ remove individual entries, add manually
       ↓
Validate         ──▶ backend
       ↓
Result           ──▶ valid / not-found / not-permitted / wrong-status
```

**There is no bulk endpoint.** Options:

- **A (recommended):** add `POST /api/v1/inventory/items/by-tags` taking `{tags: [...]}` and
  returning resolved items plus an `unresolved[]` list. One round trip for 200 tags.
- **B (ships now):** the app resolves each tag via `by-tag` with a concurrency limit of 4 and
  a progress indicator. Works, but 200 scans = 200 requests, which on showroom wifi is slow
  enough to be felt.

I will build B behind a `BulkResolver` interface and swap to A when it exists. *Decision needed.*

`ScanSession` is a shared, feature-agnostic component — Phase 5 stock count, Phase 7 transfer
picking and receiving, Phase 8 verification all consume it rather than each writing their own.
That reuse is the main architectural point of this phase.

## 6. Deliverables

`ScannerService` + implementations, `ScannerRegistry`, `ScanScreen`, `ScanOverlay`,
`ScanFeedback` (haptic/audio), `TagNormaliser`, `ScanSession` + `BulkScanReviewScreen`,
`ManualEntrySheet`, permission-denied state, `BulkResolver`.

Android: `CAMERA` permission, camera2 config. iOS: `NSCameraUsageDescription`. Both documented
in the phase output.

Tests: normalisation rules, debounce, session de-duplication, not-found flow, no-camera device.
