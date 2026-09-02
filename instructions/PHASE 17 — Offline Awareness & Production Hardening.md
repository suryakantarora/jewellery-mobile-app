# PHASE 17 — Offline Awareness & Production Hardening

Prepare the mobile app for real-world showroom/warehouse usage.

## Offline

Support offline-aware behavior.

Clearly distinguish:

```text
ONLINE
OFFLINE
SYNCING
SYNC FAILED
```

## Read-only caching

Where appropriate, cache:

- Recently viewed jewellery
- Basic product information
- User profile
- Branch information

## Critical transactions

Do NOT blindly queue critical financial or inventory operations offline unless the backend has explicitly designed an idempotent offline synchronization mechanism.

Examples that should normally require connectivity:

- Selling jewellery
- Inventory transfer confirmation
- Buyback
- Exchange
- Payment
- Approval

## Security

Implement:

- Secure token storage
- Session timeout
- Optional biometric app unlock
- Screenshot/privacy considerations for sensitive screens
- Secure logout
- Certificate/document access controls

## Performance

Optimize:

- Image loading
- Pagination
- Search debounce
- API caching
- List rendering
- Scanner workflows

## Production

Prepare:

- Android build
- iOS build
- Environment configuration
- API endpoint configuration
- Crash/error reporting integration point
- Logging strategy
- App version checking

Do not expose backend secrets inside the mobile application.