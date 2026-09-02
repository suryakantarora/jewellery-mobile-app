# PHASE 10 — Mobile Sales Assistance

Build mobile sales-assistance functionality.

## Features

- Search jewellery
- Scan jewellery
- View price
- Check availability
- Check other branches
- Customer selection
- Customer creation
- Wishlist
- Share product details where permitted

## Customer Request

Salesperson can:

```text
Customer
 ↓
Search Jewellery
 ↓
View Digital Passport
 ↓
View Price
 ↓
Check Availability
 ↓
Reserve / Continue to POS
```

## Cross-branch availability

Display:

```text
Vientiane      Available
Pakse          Available
Luang Prabang  0
```

Do not expose branches or prices the employee does not have permission to view.

Actual payment and final sale should remain controlled by the POS/backend workflow.