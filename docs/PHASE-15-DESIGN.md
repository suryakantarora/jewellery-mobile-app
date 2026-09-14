# Phase 15 — Mobile Notifications: Design for Review

## 1. The finding — this phase needs backend work

What exists:

```text
GET  /api/v1/notifications?status=&channel=&eventType=&recipientId=&page=  NOTIFICATION_VIEW
GET  /api/v1/notifications/templates                                        NOTIFICATION_VIEW
POST /api/v1/notifications/templates                                        NOTIFICATION_MANAGE
PUT  /api/v1/notifications/templates/{id}
POST /api/v1/notifications/templates/{id}/active

NotificationChannel = EMAIL SMS PUSH IN_APP
NotificationStatus  = PENDING SENT FAILED ABANDONED CANCELLED
RecipientType       = CUSTOMER USER ADDRESS
NotificationResponse = id, eventType, channel, recipientType, recipientId,
    recipientAddress, subject, body, status, branchId, referenceType,
    referenceId, attemptCount, sentAt, failureReason, createdAt
```

This is an **outbound delivery log**, not an inbox. Concretely, what Phase 15 asks for and what
is missing:

| Requirement | Status |
|---|---|
| Notification centre (list) | ✅ possible via `?recipientType=USER&recipientId=<me>` |
| Read / unread state | ❌ **no field, no endpoint** |
| Notification detail | ✅ `subject` + `body` are on the response |
| Deep linking | ✅ `referenceType` + `referenceId` are exactly right for this |
| Push (FCM) | ❌ **no device registration, no FCM anywhere in the backend** |

`NotificationChannel.PUSH` exists as an enum value, but nothing consumes it — I found no
Firebase dependency, no device-token entity and no send path.

**Backend work required for a complete Phase 15:**

```text
POST   /api/v1/notifications/devices     {token, platform, appVersion, deviceId}
DELETE /api/v1/notifications/devices/{token}          (on logout — important)
GET    /api/v1/notifications/mine?unreadOnly=         (server-side "me", not client-supplied id)
POST   /api/v1/notifications/{id}/read
POST   /api/v1/notifications/read-all
GET    /api/v1/notifications/unread-count             (drives the badge + dashboard tile)
```

Plus FCM send integration server-side, keyed to `NotificationChannel.PUSH`.

Note that `?recipientId=` being client-supplied is also a concern: without a `/mine` endpoint,
the app must pass its own user id, and if the backend doesn't constrain that parameter to the
caller, a curious user could read another user's notifications. **Worth checking on the backend
side regardless of this phase.**

**What I will build now** without backend changes: the notification centre reading
`?recipientType=USER&recipientId=<me>`, detail view, deep linking (fully working), and
**locally-tracked read state** — read ids in local storage, correct on one device, wrong across
devices. That limitation is real and I would not ship it as final. *Decision needed:* add the
endpoints, or accept device-local read state for the MVP.

## 2. Notification centre

```text
┌────────────────────────────────────────┐
│ Notifications          [Mark all read] │
│ [All] [Transfers] [Approvals] [Repairs]│  eventType grouping
├────────────────────────────────────────┤
│ ●  Transfer TR-10024 approved          │  ● = unread, bold
│    Bounma approved your transfer       │
│    2h ago                          ›   │
├────────────────────────────────────────┤
│    Repair RP-0184 ready for delivery   │
│    Yesterday 16:20                 ›   │
└────────────────────────────────────────┘
```

Grouped by day, infinite scroll, swipe to mark read, empty state per filter. Unread count
badges the bottom-nav bell and the Phase 3 dashboard tile.

## 3. Deep linking — the part that must be exactly right

`referenceType` + `referenceId` on every notification map to a route:

```dart
const _routes = {
  'MOVEMENT':      '/transfers/:id',
  'JEWELLERY_ITEM':'/inventory/item/:id',
  'REPAIR':        '/repairs/:id',
  'PURCHASE_ORDER':'/procurement/purchase-orders/:id',
  'EXCHANGE':      '/exchange/:id',
  'STOCK_COUNT':   '/warehouse/stock-counts/:id',
  'CUSTOMER':      '/customers/:id',
  'SALE':          '/sales/:id',
};
```

**The deeper problem:** `BusinessEventListener` raises only seven events, five aimed at
customers. The two staff events (`ItemTransferred`, `LowStock`) pass a `null` recipient id, so
**no notification is currently addressable to a specific staff user** and no `referenceType`
value set is established. This map is therefore provisional until staff-directed events exist.

Resolution rules:
- **Unknown `referenceType` → open the notification detail**, never a crash, never a blank
  route.
- A deep link arriving while unauthenticated is **held**, login proceeds, then the link is
  replayed. Losing the destination after login is the classic deep-link bug.
- A deep link into a **different branch's** record prompts "This is in Pakse. Switch branch?"
  rather than showing a 403 — the notification is legitimate, the context is wrong.
- Permission-denied targets show the notification detail plus an explanation.
- Cold start, background and foreground all route through one `DeepLinkHandler`.

## 4. Push (FCM)

**Status (14 Sep 2026): implemented on both sides.** Backend exposes
`POST /notifications/devices` / `DELETE /notifications/devices/{token}` and sends FCM for
`NotificationChannel.PUSH` with a data payload of `{eventType, referenceType, referenceId,
notificationId}` plus an OS title/body. App side:
`lib/features/notifications/data/push_registration_service.dart` (`pushRegistrationProvider`,
mounted from `app.dart`): sign-in → permission → token → register (platform + app version);
`onTokenRefresh` → re-register; sign-out → `DELETE` (best-effort) + `deleteToken`;
foreground → in-app snackbar with **View** + badge/inbox refresh; background/terminated tap →
`NotificationRouter.pathFor` → `go_router.push` (deferred until the session is authenticated on
a cold start). Unknown reference types (today `Sale`, which has no detail route) open the inbox.

**Firebase is optional.** `main()` wraps `Firebase.initializeApp()`; on failure the app logs once
and runs on the 60 s unread-count poll. The Android `google-services` plugin is applied only when
a config file exists. Not implemented from the original sketch: per-category Android channels and
the settings screen (single default channel; no server-side preference endpoint yet).

**Config the user must supply (not committed):**
- Android: `android/app/src/{dev,staging,prod}/google-services.json` (package ids
  `com.finotechsoftware.jewelleryapp[.dev|.staging]`), or one `android/app/google-services.json`
  containing all three clients.
- iOS: `ios/Runner/GoogleService-Info.plist` per flavour (add to the Runner target; if one file
  per flavour, copy the right one in a build phase keyed on `$(FLAVOR)`), enable the
  **Push Notifications** capability (aps-environment entitlement) and **Background Modes →
  Remote notifications** in Xcode, and upload the APNs auth key (.p8) to the Firebase project.
- Backend: the Firebase service-account credentials for server-side send.

Original design sketch, kept for reference:

```text
PushService (abstract)
  ├─ FcmPushService     firebase_messaging, Android + iOS
  └─ NoOpPushService    ships until backend registration exists

lifecycle:
  login          → request permission (iOS/Android 13+), get token, register
  token refresh  → re-register
  logout         → deregister, then clear   ← must not push to a logged-out device
  foreground     → in-app banner, no OS notification
  background     → OS notification → tap → DeepLinkHandler
  cold start     → initial message read before the router settles
```

Android notification channels per category (approvals, transfers, repairs, alerts) so users can
mute selectively. High-value transaction alerts get their own channel and are not mutable to
silent by default.

**Payload rule:** push payloads carry `{notificationId, referenceType, referenceId, eventType}`
and *no business data* — no amounts, customer names or item values in an OS notification that
renders on a lock screen. The app fetches the content after the tap. This is a privacy
requirement, not a preference.

Notification settings screen: per-category toggles (stored server-side once the endpoint
exists, locally until then), plus a link to OS settings.

## 5. Deliverables

`NotificationCenterScreen`, `NotificationDetailScreen`, `NotificationSettingsScreen`,
`NotificationRepository` (+ local read-state store), `DeepLinkHandler`, `PushService`
abstraction + `NoOpPushService`, `FcmPushService` behind a build flag, unread-count provider,
Android channel setup, iOS permission flow.

Tests: deep-link routing for every `referenceType` including unknown, deferred link after
login, branch-mismatch prompt, logout deregistration, read-state persistence.
