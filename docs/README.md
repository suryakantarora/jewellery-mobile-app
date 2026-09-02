# Jewellery ERP Mobile — Design Documents

Design for all 17 phases, written against the **actual Spring Boot backend** in
`../../erp-backend` rather than only the phase specs. Where the two disagree, the backend wins
and the difference is called out.

Nothing here is implemented yet. Review, then development starts at Phase 1.

## Read in this order

1. **[BACKEND-GAPS.md](BACKEND-GAPS.md)** — start here. Every gap between what the phases ask
   for and what the backend provides, plus the decisions I need from you. 30 items.
2. **[PHASE-1-DESIGN.md](PHASE-1-DESIGN.md)** — Foundation: stack, structure, theme, router,
   networking, component library
3. **[PHASE-2-DESIGN.md](PHASE-2-DESIGN.md)** — Authentication, tokens, branch context,
   permissions
4. **[PHASE-3-DESIGN.md](PHASE-3-DESIGN.md)** — Role-aware dashboard
5. **[PHASE-4-DESIGN.md](PHASE-4-DESIGN.md)** — Search & Digital Passport *(the app's centre)*
6. **[PHASE-5-DESIGN.md](PHASE-5-DESIGN.md)** — Inventory & stock count
7. **[PHASE-6-DESIGN.md](PHASE-6-DESIGN.md)** — Barcode / QR / RFID scanning
8. **[PHASE-7-DESIGN.md](PHASE-7-DESIGN.md)** — Stock transfer
9. **[PHASE-8-DESIGN.md](PHASE-8-DESIGN.md)** — Warehouse & vault
10. **[PHASE-9-DESIGN.md](PHASE-9-DESIGN.md)** — Procurement & goods receiving
11. **[PHASE-10-DESIGN.md](PHASE-10-DESIGN.md)** — Sales assistance
12. **[PHASE-11-DESIGN.md](PHASE-11-DESIGN.md)** — Customer & CRM
13. **[PHASE-12-DESIGN.md](PHASE-12-DESIGN.md)** — Repairs
14. **[PHASE-13-DESIGN.md](PHASE-13-DESIGN.md)** — Exchange & buyback
15. **[PHASE-14-DESIGN.md](PHASE-14-DESIGN.md)** — Approval centre
16. **[PHASE-15-DESIGN.md](PHASE-15-DESIGN.md)** — Notifications & push
17. **[PHASE-16-DESIGN.md](PHASE-16-DESIGN.md)** — Reports
18. **[PHASE-17-DESIGN.md](PHASE-17-DESIGN.md)** — Offline awareness & production hardening

## MVP path

Per `instructions.txt`, the first testable build is Phases 1–8. Phases 9–17 follow.

```text
1 Foundation → 2 Auth → 3 Dashboard → 4 Passport → 5 Inventory
  → 6 Scanner → 7 Transfer → 8 Warehouse    ◀── first usable version
  → 9 Procurement → 10 Sales → 11 CRM → 12 Repairs → 13 Exchange
  → 14 Approvals → 15 Notifications → 16 Reports → 17 Hardening
```

## Principles applied throughout

- **The backend is the authority.** The app hides and disables; it never enforces. A 403 is
  rendered as a clear state, never a crash.
- **No client-side financial arithmetic.** Prices, valuations and metal values are displayed as
  the server returns them. Phase 13 enforces this with a test.
- **`allowedTransitions` drives actions.** Items, repairs and movements all return their legal
  next states; action buttons are `allowedTransitions ∩ permissions`. No guessed state machines.
- **Permissions, not roles.** Roles are backend-configurable, so no role string appears in the
  mobile codebase — every tile, tab and action declares the permission it needs.
- **Nothing critical is queued offline.** Read-only caching only; the sole local-accumulation
  patterns (stock count, receiving reconciliation, goods-receipt draft) submit atomically and
  change no server state until they do.
- **Branch context invalidates everything.** Switching branch clears every feature provider, so
  one branch's stock can never appear under another's header.
- **Enterprise, not consumer.** Dense, fast, legible in a vault and next to a customer.

## Open decisions

Summarised in [BACKEND-GAPS.md](BACKEND-GAPS.md) §24–30. The five that block Phase 1:
Riverpod confirmation, package id, institution-name source, localisation scope, currency.
