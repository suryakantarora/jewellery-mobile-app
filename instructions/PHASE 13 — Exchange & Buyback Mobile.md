# PHASE 13 — Exchange & Buyback Mobile

Build mobile workflows for exchange and old-gold buyback.

## Exchange

Display:

```text
Customer
 ↓
Old Jewellery
 ↓
Weight
 ↓
Purity
 ↓
Stone Deduction
 ↓
Metal Rate
 ↓
Valuation
 ↓
Approval
```

## Buyback

Capture:

- Item/customer information
- Gross weight
- Stone weight
- Net metal weight
- Purity
- Current rate
- Valuation
- Approval

## Important

The mobile app must never independently calculate or approve financial values if the backend provides the authoritative calculation.

The mobile UI should display backend-calculated results.

Use clear approval states.