# Backlog — gap closure session (started 13 September 2026)

Handover page for resuming this work. Read with NEXT-STEPS.md and BACKEND-GAPS.md.
Scope of the session: close every item in BACKEND-GAPS.md and NEXT-STEPS.md §3, and
build the app side for each. Customer identity / storefront (NEXT-STEPS §2.2, §2.3) are
a separate product and are NOT in scope.

Legend: [x] done and verified · [~] code written, not yet compiled/tested · [ ] not started

## Environment
- Backend needs `docker compose up -d postgres redis minio` in erp-backend before tests
  (the health test returns 503 when redis is down — that was the only baseline failure).
- Backend baseline before this session: 130 tests green.
- App baseline before this session: 107 tests; now 128 green, `flutter analyze` clean.
- Backend has uncommitted work from 2 Sep (catalogue module, OrganizationService.myBranches)
  plus everything below. Nothing has been committed this session — commit is the user's call.

## Backend (erp-backend) — batch 1, written by parallel agents, NOT YET COMPILED
Migrations added: V27 (inventory search + design images), V28 (staff notifications, devices,
events), V29 (approvals, discount requests, wishlist, idempotency). No V30 needed.

- [~] Item display names on JewelleryItemResponse (productName, productCode, designName,
      metalName, purityCode, currentLocationName, currentBranchName, binCode, supplierName)
- [~] GET /inventory/items?minPrice=&maxPrice=
- [~] POST /inventory/items/by-tags {tags[]} → {resolved[{tag,item}], unresolved[]}
- [~] GET /inventory/availability?productId= → {productId, productName, branches[{branchId,branchName,available,total}]}
- [~] Design images GET/POST/DELETE /designs/{id}/images; product images /products/{id}/images;
      primaryImageKey on DesignResponse and ProductResponse
- [~] Staff-directed events: TRANSFER_AWAITING_APPROVAL, TRANSFER_APPROVED/REJECTED,
      PURCHASE_ORDER_APPROVED/REJECTED, REPAIR_READY_STAFF, HIGH_VALUE_SALE (+ IN_APP/PUSH templates)
- [~] identity UserDirectory port (users by permission in branches; username → id)
- [~] POST /notifications/devices {token, platform, appVersion} (201), DELETE /notifications/devices/{token} (204)
- [~] FcmNotificationSender (firebase-admin 9.4.3), enabled by jewellery.notification.push.enabled
      + push.credentials-file (env FCM_ENABLED, FCM_CREDENTIALS_FILE). Data keys: eventType,
      referenceType, referenceId, notificationId. Inbox now IN_APP only.
- [~] Unified approvals: GET /approvals/pending?branchId=&type=, GET /approvals/pending/count,
      POST /approvals/{type}/{id}/decision {decision: APPROVE|REJECT|REQUEST_INFO, reason}
      (X-Idempotency-Key), GET /approvals/{type}/{id}/information, POST .../information/{requestId}/answer
      Types: TRANSFER, PURCHASE_ORDER, REQUISITION, EXCHANGE, STOCK_COUNT, GOODS_RECEIPT, DISCOUNT
- [~] Discount requests: /sales/discount-requests (POST, GET, GET/{id}, /approve, /reject, /cancel);
      CreateSaleRequest.discountRequestId honoured in SaleService.create; expiry scheduler
- [~] X-Idempotency-Key on POST /exchanges and POST /repairs
- [~] Wishlist: /customers/{customerId}/wishlist GET/POST/DELETE/{entryId}
- [~] GET /dashboard/summary?branchId=&refresh= (permission-filtered sections: sales, inventory,
      inventoryValue, transfers, approvals, repairs, procurement, notifications, metalRates); 30 s cache.
      Sales section gated on SALE_VIEW — this settles NEXT-STEPS §1.3 (sales staff see their branch total).
- [~] GET /app/version?platform=ANDROID|IOS&current= (public) → {platform, minSupported, latest,
      storeUrl, message, forceUpdate, updateAvailable}; config jewellery.app.versions.{android,ios}.*
- [~] X-Branch-Id header → BranchContext / SecurityUtils.currentBranchId(); foreign branch → 403
- [~] Enum query-param mismatch → 400 with "Must be one of: …"
- [ ] COMPILE + run full suite; fix fallout. Known compile errors at time of writing:
      - DashboardService.countOf overloads clash on erasure (rename one)
      - ApprovalResponses / ApprovalService "cannot find symbol" (likely a missing import or
        a response record referenced under the wrong name — check lines ~46-60 and ~172-261)
      - possibly the `(:minPrice is null or …)` BigDecimal idiom → use cast(:minPrice as big_decimal)
- [ ] Known limitation to fix: ApprovalService lists pending TRANSFERs via
      InventoryMovementRepository.search capped at 200 before branch scoping — add a proper
      "pending by branches" query to InventoryMovementRepository.
- [ ] Update BACKEND-GAPS.md status markers once tests pass.

## Backend — batch 2 (not started)
- [ ] Multi-tenancy company boundary (NEXT-STEPS §1.1, §2.1; BACKEND-GAPS 37–40). Direction
      confirmed by instructions.txt ("Tenant Context" sits above Branch Context). Plan:
      company_id on identity.app_user (derive from primary branch for existing rows), companyId
      on AuthenticatedUser + JWT claim, company_id on product.product / metal / product_category /
      jewellery_design / customer.customer (backfill to the single existing company), reads filtered
      by company in every search/list query, super admin unchanged, `/auth/me` returns company.
      Migration V30. Integration test: user of company A cannot read company B stock/customers.
- [ ] Malformed enum in a nested body (NEXT-STEPS §3) — verify the existing handler already covers
      nested paths; add a test.

## App (jwellery-mobile-app) — batch 1 DONE (analyze clean, 128 tests)
- [x] iOS flavours dev/staging/prod (xcconfigs, schemes, pbxproj, Podfile); README "Building" section.
      Run `cd ios && pod install` once before an iOS flavour build.
- [x] Forced-update gate (lib/core/settings/app_version_service.dart, update_gate.dart; url_launcher added)
- [x] Reserve / Transfer / Start-repair actions wired as sheets from the passport screen
- [x] OfflineGuard wired into mutating repos (jewellery, transfers, procurement, repairs, exchange, warehouse)
- [x] Unread badge from /mine/unread-count with 60 s foreground poll
- [ ] OfflineGuard for customers and sales repositories (skipped by the agent — 3-line change each)

## App — batch 2 (not started; depends on backend batch 1 compiling)
- [ ] Dashboard: replace the seven-call fan-out with GET /dashboard/summary; keep per-section
      hiding when a section is absent; remove the "Unavailable" tile path; delete unused cache TTL consts
- [ ] Items: read the new *Name fields from JewelleryItemResponse; make the reference-data cache a
      fallback only; add minPrice/maxPrice to ItemSearchFilters + filter sheet
- [ ] Scanner bulk mode: resolve scanned tags via POST /inventory/items/by-tags, show
      resolved/unresolved, hand resolved items to transfer-receive and stock-count
- [ ] Sales assistance screen (/more/sales is still PhasePlaceholderScreen): availability via
      GET /inventory/availability, wishlist add/list/remove on the customer screen and item passport,
      reservation entry point, discount request creation (DISCOUNT_REQUEST)
- [ ] Approval centre: switch to GET /approvals/pending + decision endpoint; add "Request
      information" action + information thread on the detail; add DISCOUNT type (approve/reject);
      dashboard badge from /approvals/pending/count or the summary section
- [ ] Notifications: firebase_messaging + firebase_core, register token on sign-in
      (POST /notifications/devices), unregister on sign-out, handle foreground/background taps via
      the data payload (eventType, referenceType, referenceId, notificationId) → NotificationRouter;
      add routing for referenceType "Sale" and "PurchaseOrder"; needs google-services.json /
      GoogleService-Info.plist per flavour (user must supply the Firebase project)
- [ ] Design/product images: show primaryImageKey for designs/products in catalogue & reference
      pickers; item image gallery + upload (POST /files then POST /inventory/items/{id}/images)
- [ ] Send X-Branch-Id (interceptor already does) — nothing to do once backend lands; verify 403 handling
- [ ] Tenant context (after backend batch 2): show company on the branch bar, read companyId from /auth/me
- [ ] Update docs: BACKEND-GAPS.md, NEXT-STEPS.md, PHASE-15 push notes, this file

## Decisions taken in this session (user asked to proceed and cover all gaps)
- NEXT-STEPS §1.3: sales staff see their branch's daily total through the dashboard summary,
  gated on SALE_VIEW; the REPORT_VIEW report stays as is.
- Wishlist is a real table (customer.customer_wishlist), not a quotation.
- "Request information" is a real record that does not change the underlying status.
- Push is fully plumbed server-side but off by default until a Firebase service-account file is configured.
