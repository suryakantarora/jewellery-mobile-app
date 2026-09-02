# PHASE 2 — Mobile Authentication & Access Control

Continue from Phase 1.

Connect the Flutter application to the existing Spring Boot authentication APIs.

## Authentication

Implement:

- Login
- JWT authentication
- Refresh token
- Secure token storage
- Logout
- Token expiry
- Automatic refresh
- Unauthorized handling

Never store passwords locally.

## User Context

After login retrieve:

```text
User
Tenant / Institution
Role
Permissions
Branches
Default Branch
Accessible Locations
```

Example:

```text
Institution
    ↓
ABC Jewellery
    ↓
User
    ↓
Branch Access
    ├── Vientiane
    └── Pakse
```

## Branch Selector

If the user has access to multiple branches, allow branch selection.

Every API request requiring branch context must use the selected branch according to the backend API contract.

## Permission System

Prepare permission checks:

```text
INVENTORY_VIEW
INVENTORY_TRANSFER
INVENTORY_RECEIVE

CUSTOMER_VIEW
CUSTOMER_CREATE

REPAIR_VIEW
REPAIR_UPDATE

BUYBACK_CREATE
BUYBACK_APPROVE

SALE_VIEW
SALE_CREATE
```

The backend remains the final authority.

The mobile UI should only hide/disable functionality the user does not have permission to use.

## Security

Implement:

- Secure storage
- Session management
- Logout on authentication failure
- App lock preparation
- Biometric authentication integration point

Do not bypass backend authorization.