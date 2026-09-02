# PHASE 5 — Mobile Inventory

Build the mobile inventory module.

## Inventory screens

Create:

- Inventory list
- Inventory by branch
- Inventory by location
- Inventory by category
- Inventory by metal
- Inventory aging

## Item cards

Show:

```text
Image
Item ID
Product
Metal
Purity
Weight
Price
Location
Status
```

## Filters

Support:

```text
Branch
Location
Category
Metal
Purity
Status
```

## Item actions

Depending on permission:

- View
- Transfer
- Reserve
- Receive
- Repair
- Return

## Stock Count

Create a mobile-first physical stock counting workflow.

```text
Select Location
      ↓
Expected Items
      ↓
Scan Items
      ↓
Matched
Missing
Unexpected
      ↓
Submit Count
```

Make this optimized for warehouse/showroom staff.