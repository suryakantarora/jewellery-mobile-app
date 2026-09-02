# PHASE 15 — Mobile Notifications

Implement push notifications.

Examples:

```text
Transfer Approved
Transfer Received
New Approval Request
Repair Ready
Purchase Order Approved
High-value Transaction Alert
```

Create:

- Notification center
- Read/unread state
- Notification detail
- Deep linking

Example:

```text
Notification
     ↓
"Transfer TR-10024 approved"
     ↓
Tap
     ↓
Transfer Details
```

Prepare Firebase Cloud Messaging integration for Android/iOS.

The backend should remain responsible for deciding when notifications are generated.