# Phase 11 — Customer & CRM Mobile: Design for Review

## 1. Backend contract (verified)

```text
GET  /api/v1/customers?…                        CUSTOMER_VIEW
GET  /api/v1/customers/by-phone?phone=          CUSTOMER_VIEW
GET  /api/v1/customers/{id}                     CUSTOMER_VIEW  (addresses, documents, prefs)
POST /api/v1/customers                          CUSTOMER_MANAGE
PUT  /api/v1/customers/{id}                     CUSTOMER_MANAGE
POST /api/v1/customers/{id}/addresses           CUSTOMER_MANAGE
POST /api/v1/customers/{id}/documents           CUSTOMER_MANAGE
POST /api/v1/customers/{id}/kyc                 CUSTOMER_KYC_VERIFY
POST /api/v1/customers/{id}/preferences         CUSTOMER_MANAGE
POST /api/v1/customers/{id}/status              CUSTOMER_MANAGE

GET  /api/v1/crm/customers/{customerId}/360     CRM_VIEW   ← one call, whole page
GET  /api/v1/crm/activities  POST /api/v1/crm/activities
GET  /api/v1/crm/follow-ups  /follow-ups/mine   POST /crm/follow-ups
POST /api/v1/crm/follow-ups/{id}/complete|cancel
GET  /api/v1/loyalty/accounts/{customerId}
GET  /api/v1/loyalty/accounts/{customerId}/transactions
POST /api/v1/files                              FILE_UPLOAD (documents)

CustomerStatus = ACTIVE INACTIVE BLACKLISTED
CustomerType   = INDIVIDUAL CORPORATE
KycStatus      = NOT_REQUIRED PENDING VERIFIED REJECTED EXPIRED
ActivityType   = CALL VISIT MESSAGE EMAIL MEETING COMPLAINT FEEDBACK NOTE
FollowUpStatus = OPEN COMPLETED CANCELLED
```

`GET /crm/customers/{id}/360` exists and is documented as *"identity, what they have bought,
their loyalty standing…"* — the Customer 360 screen is one call, not an aggregation. Good.

## 2. Privacy stance

This is the module handling personal data, so the rules are stated before the screens:

- **KYC documents are gated twice** — `CUSTOMER_VIEW` to know a document exists,
  `CUSTOMER_KYC_VERIFY` to open it. Document numbers are masked (`•••• 4821`) with an explicit
  reveal tap that is auditable server-side.
- `screen_guard` (FLAG_SECURE / iOS blur) is applied to the KYC and document screens.
- No customer PII is written to the Phase 17 offline cache. Recently-viewed customers store an
  id and display name only.
- Phone numbers and emails are actionable (tap to call/message) but never bulk-exportable, and
  there is no "share customer" affordance anywhere.
- A `BLACKLISTED` customer shows a prominent banner on every screen they appear on.

## 3. Screens

**Customer search** — phone-first, because that is the real-world identifier. Typing digits
switches to `by-phone`; typing letters uses the name search. Results show name, phone (masked
by default), customer code, loyalty tier and status chips. Recent customers listed when the
query is empty.

**Customer 360**

```text
┌────────────────────────────────────────┐
│ ◐  Somchai Vong          VERIFIED · GOLD│
│    CUS-00412 · +856 20 •••• 4821       │
│    [Call] [Message] [Follow-up]        │
├────────────────────────────────────────┤
│  ₭42.8M lifetime · 12 purchases        │  gated by SALE_VIEW
│  1,240 points · last visit 14 Aug      │
├────────────────────────────────────────┤
│ Profile · Purchases · Repairs ·        │  tab bar
│ Exchanges · Loyalty · Activities       │
├────────────────────────────────────────┤
│ [ tab content ]                        │
├────────────────────────────────────────┤
│ Timeline                               │
│  ● 14 Aug  Purchase  ₭4.2M             │
│  ● 02 Aug  Repair    RP-0184 delivered │
│  ● 28 Jul  Follow-up call              │
│  ● 12 Mar  Registered                  │
└────────────────────────────────────────┘
```

Each tab renders a section of the 360 payload; anything the payload omits (because permission
denied it server-side) renders as a "not available with your access" state rather than an
empty list — a meaningful distinction for staff.

The unified **timeline** merges purchases, repairs, exchanges, activities and follow-ups into
one chronological `AppTimeline`. This is the single most useful screen for a salesperson and
justifies the whole module.

**Wishlist tab:** no backend support (see Phase 10 §5). Shown only if we adopt the quotation
mapping or add the endpoint.

**Customer creation** — 4-step form, resumable:

```text
1  Identity     type (individual/corporate), name, DOB, gender, language
2  Contact      phone (validated, duplicate-checked via by-phone), email, address
3  KYC          document type, number, expiry, photo capture → POST /files
                (only shown with CUSTOMER_KYC_VERIFY; otherwise skipped and
                 the customer is created with KycStatus.PENDING)
4  Preferences  metal, purity, category, size, contact preferences, marketing consent
```

Step 2 runs a duplicate check on the phone number before allowing continue — creating a second
record for an existing customer is the most common and most annoying data-quality failure in
retail CRM. If a match is found, the app offers "Open existing customer" instead.

Marketing consent is an explicit opt-in checkbox with no pre-tick.

**Edit** reuses the same steps individually rather than a separate form.

## 4. Activities & follow-ups

- Log an activity in two taps from the customer header: type chip (`CALL`/`VISIT`/…), note,
  optional outcome. `POST /crm/activities`.
- Create a follow-up with a due date and note; `GET /crm/follow-ups/mine` powers the "My tasks"
  dashboard tile from Phase 3.
- A follow-up card offers Complete / Cancel inline — the whole point is that it takes seconds
  between customers.
- Overdue follow-ups are visually distinct and sorted first.

Campaigns and segments (`/crm/campaigns`, `/crm/segments`) are **out of mobile scope** — they
are an Admin portal concern. Mobile only surfaces campaign membership as a chip on the customer
profile if it comes back in the 360 payload.

## 5. Loyalty

Read-only on mobile by default: balance, tier, transaction history
(`/loyalty/accounts/{customerId}/transactions`). Redemption (`POST /loyalty/redemptions`)
requires `LOYALTY_REDEEM` and belongs to the POS flow, so mobile shows the balance and defers
the transaction. Adjustments (`LOYALTY_ADJUST`) are not exposed on mobile at all — no reason
for a phone to hold that power.

## 6. Deliverables

`CustomerSearchScreen`, `Customer360Screen` + 6 tabs, `CustomerTimeline`,
`CustomerCreateFlow` (4 steps, resumable, duplicate check), `KycSection` (masked, double-gated),
`ActivityLogSheet`, `FollowUpSheet`, `FollowUpListScreen`, `LoyaltySection`,
`CustomerRepository`, `CrmRepository`.

Tests: masking and reveal gating, duplicate phone detection, 360 partial-permission rendering,
follow-up state transitions, no-PII-in-cache assertion.
