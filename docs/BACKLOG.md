# Jewellery ERP — Status & Backlog

Handover page. Last updated 14 September 2026. Read this first when resuming;
NEXT-STEPS.md and BACKEND-GAPS.md carry the detail behind each item.

Repos: `erp-backend` (Spring Boot, git, all work UNCOMMITTED) and
`jwellery-mobile-app` (Flutter, not a git repo).

Verified state: backend 187 integration tests green · app 182 tests green,
`flutter analyze` clean · migrations V1–V30.

---

## 1. COMPLETED

### Mobile app — all 17 phases (before this session)
Foundation, Auth, Dashboard, Passport, Inventory, Scanner, Transfer, Warehouse,
Procurement, Sales, CRM, Repairs, Exchange, Approvals, Notifications, Reports,
Hardening — all built and driven on a physical device.

### Backend gap closure (13–14 Sep 2026)
| # | Item | Endpoint / change |
|---|---|---|
| 1 | Dashboard summary | `GET /dashboard/summary?branchId=&refresh=` — sections omitted when not permitted; sales on SALE_VIEW |
| 2 | Staff-directed notifications | TRANSFER_AWAITING_APPROVAL / APPROVED / REJECTED, PURCHASE_ORDER_APPROVED / REJECTED, REPAIR_READY_STAFF, HIGH_VALUE_SALE, APPROVAL_INFO_*, DISCOUNT_* |
| 2 | Device registration + push | `POST/DELETE /notifications/devices`; FCM sender (firebase-admin) behind `jewellery.notification.push.enabled` |
| 3 | Item display names | productName, productCode, designName, metalName, purityCode, currentLocationName, currentBranchName, binCode, supplierName on item responses |
| 4 | Design / product images | `/designs/{id}/images`, `/products/{id}/images`, `PUT …/images/{imageId}` (set primary); `primaryImageKey` on both |
| 4 | Catalogue artwork fallback | `productId`, `designId`, `fallbackImageKey` on catalogue items |
| 5 | Unified approvals | `GET /approvals/pending`, `/pending/count`, `POST /approvals/{type}/{id}/decision` (APPROVE/REJECT/REQUEST_INFO), information thread endpoints |
| 5 | Discount workflow | `/sales/discount-requests` (create/list/approve/reject/cancel), `discountRequestId` on `POST /sales`, expiry job |
| 6 | Branch header | `X-Branch-Id` validated by filter; `SecurityUtils.currentBranchId()` |
| 7 | Idempotency | `X-Idempotency-Key` on exchanges, repairs, approval decisions |
| 8 | Bulk tag lookup | `POST /inventory/items/by-tags` |
| 9 | Cross-branch availability | `GET /inventory/availability?productId=` |
| 11 | Price filter | `minPrice` / `maxPrice` on item search |
| 12 | Wishlist | `/customers/{id}/wishlist` |
| 13 | Request information | part of unified approvals |
| 14 | App version | `GET /app/version?platform=&current=` (public) |
| 35 | Enum errors | query-param and nested-body enum mistakes → 400 with accepted values |
| 37–40 | Multi-tenancy | `company_id` on users, product, category, design, metal, gemstone, customer, supplier; JWT `co` claim; reads scoped by company; `companyId`/`companyName` on UserResponse |
| §1.3 | Sales staff daily total | settled: shown via dashboard summary on SALE_VIEW |

### App gap closure (13–14 Sep 2026)
- Dashboard on the single summary call; new tiles (approvals, repairs, procurement, metal rates)
- Item names from the server; reference cache is now a fallback; price range filter
- Bulk scan resolves tags server-side; receive and stock-count reconcile by item
- Approval centre on the unified endpoint; request-information and discount types
- Sales assistance screen (`/more/sales`): lookup, price, availability, wishlist, discount request
- Wishlist section on customer 360
- Push: firebase_core/messaging, device registration on sign-in, deregister on sign-out, deep-link on tap; Firebase optional at runtime
- Item photo gallery with upload / set primary / delete on the passport screen
- Forced-update gate + real version in Settings
- Reserve / Transfer / Start-repair actions wired
- OfflineGuard on every mutating repository
- Unread badge from `/mine/unread-count`, 60 s foreground poll
- iOS build flavours dev / staging / prod (README "Building" section)
- Tenant context: company name from the user shown on the branch bar

---

## 2. NEXT — pick up here

### Must do before anyone else builds on this
1. **Commit the backend.** Everything since 2 Sep is unstaged in `erp-backend` (73 files + migrations V27–V30). Suggested: one commit per area or a single "Close backend gaps and add company tenancy".
2. **Put the app under git** (`jwellery-mobile-app` is not a repo) and commit.
3. **Apply migrations to the dev DB:** `cd erp-backend && docker compose up -d postgres redis minio && mvn spring-boot:run -Dspring-boot.run.profiles=local` (Flyway runs V27–V30 on start). Existing users must sign in again (tokens without the `co` claim are rejected for non-super-admins).
4. **Smoke-test on a device** against the migrated backend: dashboard, item list names, bulk scan, approvals, sales assistance, wishlist, photo upload, forced-update banner. Backend tests are green but no end-to-end device run has happened since these changes.

### Configuration you must supply (push notifications)
- Backend: Firebase service-account JSON → `FCM_CREDENTIALS_FILE`, and `FCM_ENABLED=true`
- Android: `android/app/src/{dev,staging,prod}/google-services.json`
- iOS: `GoogleService-Info.plist` per flavour, Push Notifications capability in Xcode, APNs key uploaded to Firebase; run `cd ios && pod install` once
- App versions: `APP_ANDROID_MIN_SUPPORTED` / `APP_ANDROID_LATEST` / `APP_ANDROID_STORE_URL` (and `APP_IOS_*`) to drive the update gate

### Remaining engineering follow-ups
- Backend: `company_id` on pricing rules, tax rates, discount policies, loyalty programmes, metal rates (still branch/global scoped)
- Backend: constrain admin `GET /notifications?recipientId=` server-side (noted in BACKEND-GAPS §2)
- App: no sale detail route, so HIGH_VALUE_SALE pushes open the inbox; add a sale detail screen if wanted
- App: per-category Android notification channels / notification settings screen (needs a preference endpoint)
- App: certificate pinning field exists but is unimplemented; release signing on Android still uses debug keys
- Refresh docs/PHASE-*-DESIGN.md "Deliverables" sections to reference the new endpoints (BACKEND-GAPS and NEXT-STEPS are already updated)

### Product decisions still open (NEXT-STEPS §1.2, §2.2, §2.3 — out of scope of this session)
- Are app customers the same record as CRM customers?
- Customer identity (registration, login, password reset) and the customer storefront (cart, orders, checkout) — a separate Flutter client, now unblocked by tenancy.

---

## 3. How to run
```bash
# backend
cd erp-backend && docker compose up -d postgres redis minio
mvn spring-boot:run -Dspring-boot.run.profiles=local
mvn test                     # ~10 min, needs the containers

# app
cd jwellery-mobile-app
adb reverse tcp:8081 tcp:8081
flutter run --flavor dev --dart-define=API_BASE_URL=http://localhost:8081
flutter analyze && flutter test
```
Test users and passwords: see NEXT-STEPS.md §5.
