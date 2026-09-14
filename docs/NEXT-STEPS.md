# Where things stand, and what to pick up next

Written 2 September 2026, at the end of a working session. This is the handover
page: read it first when resuming.

Everything below is either **a decision only you can make** or **work that is
ready to start once that decision is made**. Nothing here is a mystery — the
investigation is done and recorded; what remains is choosing.

---

## Current state

```
Flutter app   154 files · 107 tests · analyzer clean · runs on Android device + iOS builds
Backend       130 tests · Flyway at V26
```

All 17 phases are built. All five staff roles have been driven through the app
on a physical device. The scanner, item photographs, storage bins and the
customer catalogue are verified working against the live backend.

**Uncommitted:** backend changes are on disk but not committed (the last commit
you made was "Bug fixes" at 05:49; everything after that is unstaged). The
Flutter app is not a git repository at all.

---

## 1. Decisions needed before more is built

### 1.1 Multi-tenancy — ✅ done 14 September 2026

The company is now the tenant boundary. The principal carries `companyId`
(the `co` JWT claim), product master data, metals, gemstones, customers,
suppliers and users have a `company_id` column (V30), every read is filtered
by the caller's company, and a branch grant cannot cross companies. A super
administrator without a company still sees everything.

**What the app must do:** treat a `401` with *"Sign in again"* like an expired
token (old tokens have no `co` claim), and read `companyId` / `companyName`
from `/auth/me`. Full detail in BACKEND-GAPS "Multi-tenancy — implemented".

The customer identity model (1.2) can now be designed: a customer account
belongs to a company.

### 1.2 Are app customers the same record as CRM customers?

If yes, a walk-in and an app user are one person with shared loyalty and
purchase history — the whole advantage of having the ERP underneath. If no, you
get two customer databases that drift apart.

`customer.customer` has a **nullable** `registered_branch_id` and nothing filters
on it, so today the answer is "neither, quite".

### 1.3 Should sales staff see their branch's daily sales total? — ✅ settled 14 Sep 2026: yes, via the dashboard summary's `sales` section gated on SALE_VIEW

`somchai` currently sees a "Today's sales" tile reading **"Unavailable"** —
SALES_EXECUTIVE holds `SALE_VIEW` but the tile is backed by the sales *report*,
which needs `REPORT_VIEW`. Either grant the permission, hide the tile for that
role, or leave it. It needs a view on what sales staff should see, not a code
change decided in isolation.

---

## 2. Ready to start (1.1 is settled)

### 2.1 Company boundary — ✅ done 14 September 2026
`companyId` is on the principal and on product master data; reads are
filtered by it. See 1.1.

### 2.2 Customer identity
Credentials on customers, registration, login, password reset. 1.1 is done;
depends on 1.2.

### 2.3 Then the storefront
Cart, orders, checkout. The catalogue endpoint already exists and is already
shaped for public use — `GET /api/v1/catalogue/items` resolves names server-side
and carries no cost, supplier or location field by construction, guarded by
`CatalogueResponseShapeTest`. A public variant is a change of authentication,
not a rewrite.

The customer client will be **rebuilt in Flutter**; `pvj-app` is a throwaway
demo and is not wired to this backend.

---

## 3. Known gaps, no decision needed — just work

| item | note |
|---|---|
| **Push notifications** | ✅ Built 14 Sep 2026 (device registration, FCM sender, app registration). Off until a Firebase service account + google-services files are supplied — see BACKLOG.md. |
| **Staff-directed events** | ✅ Built 14 Sep 2026: transfer awaiting/approved/rejected, PO approved/rejected, repair ready (staff), high-value sale, approval info requested/answered, discount requested/decided. |
| **Backend-managed branding** | Item photos are fully backend-driven. Banners, category artwork and a shop logo are not — no such concept exists yet. |
| **Design images** | ✅ Built 14 Sep 2026 (`/designs/{id}/images`, `/products/{id}/images`, primaryImageKey on both). |
| **iOS build flavours** | ✅ done — `dev` / `staging` / `prod` schemes and `Debug-*` / `Release-*` / `Profile-*` configurations in `ios/Runner.xcodeproj`, identity in `ios/Runner/Config/*.xcconfig`. `flutter run --flavor dev` works on both platforms; see README “Building”. |
| **Malformed enum → 500** | Fixed for missing params, unreadable bodies and unknown paths. A malformed *enum* in a nested body may still slip through. |

---

## 4. Things worth remembering

**A permission meant for admin browsing has twice gated a user's own data.**
Once on notifications (`NOTIFICATION_VIEW` hid the inbox from the staff the
broadcasts were written for) and once on branches (`ORGANIZATION_VIEW` made
sign-in impossible for a sales executive). Worth checking for a third case
before adding any new permission gate.

**Reads and writes are guarded differently.** Eleven services call
`requireBranchAccess`; every one is a mutation. If you ever decide reads should
be scoped too, that is the list to work from.

**The app never bundles images.** `pubspec.yaml` declares fonts only. Everything
visual comes from `GET /api/v1/files?key=`, so uploading a photo makes it appear
with no release. Keep it that way.

---

## 5. Restarting the environment

```bash
cd erp-backend && mvn spring-boot:run -Dspring-boot.run.profiles=local
```

```bash
adb reverse tcp:8081 tcp:8081 && flutter run --flavor dev --dart-define=API_BASE_URL=http://localhost:8081
```

`adb reverse` is what lets a physical Android device reach `localhost:8081`;
without it the app cannot see the backend. Debug builds allow cleartext HTTP via
the debug manifest only — release builds stay HTTPS-only.

**Passwords changed during testing:** `khamla` → `Khamla@2026!`,
`somchai` → `Somchai@2026!`, `bounma` → `Bounma@2026!`, `noy` → `Somchai@2026!`
(hash copied to clear its forced-change flag). `admin` is unchanged.
