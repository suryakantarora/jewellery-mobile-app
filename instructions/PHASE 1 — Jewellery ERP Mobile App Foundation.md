# PHASE 1 — Jewellery ERP Mobile App Foundation

Build Phase 1 of a production-ready Flutter mobile application for a multi-tenant, multi-branch Jewellery ERP platform.

## Business Context

The backend is already completed using Spring Boot.

The system is institutional/tenant based and supports multiple branches.

The mobile application is an employee/staff application, not a replacement for the Admin ERP.

The same backend APIs will be consumed by:

- Admin ERP Portal
- Mobile Application
- Future POS
- Future Customer Application

## Technology

Use:

- Flutter
- Dart
- Material 3
- Riverpod or BLoC for state management
- Dio for REST API communication
- GoRouter for navigation
- Secure storage for authentication tokens
- JSON serialization
- Camera/scanner integration points

Choose one state-management approach and use it consistently throughout the application.

## Application Design

Create a premium jewellery-business application.

The UI should feel:

- Premium
- Professional
- Modern
- Clean
- Fast
- Enterprise-oriented

Do not make it look like a consumer jewellery shopping app.

Use:

- Light theme
- Dark theme
- Responsive layouts
- Cards
- Bottom sheets
- Modern lists
- Timeline components
- Status chips
- Skeleton loaders
- Empty states
- Error states

## Project Structure

Use a scalable structure:

```text
lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── network/
│   ├── storage/
│   ├── security/
│   ├── router/
│   ├── theme/
│   ├── errors/
│   └── utils/
│
├── shared/
│   ├── widgets/
│   ├── models/
│   ├── extensions/
│   └── helpers/
│
├── features/
│   ├── authentication/
│   ├── dashboard/
│   ├── inventory/
│   ├── jewellery/
│   ├── scanner/
│   ├── transfers/
│   ├── warehouse/
│   ├── procurement/
│   ├── sales/
│   ├── customers/
│   ├── repairs/
│   ├── exchange/
│   ├── approvals/
│   ├── notifications/
│   └── reports/
│
└── main.dart
```

## Reusable Components

Create reusable components for:

- App header
- Bottom navigation
- Cards
- Status badges
- Search
- Filter
- Pagination where appropriate
- Empty state
- Error state
- Loading state
- Confirmation dialog
- Bottom sheet
- Form fields
- Image viewer
- Timeline
- Permission-based widgets

## Navigation

Prepare routes for:

```text
Login
Dashboard
Inventory
Scan
Transfers
Warehouse
Procurement
Customers
Repairs
Approvals
Notifications
Profile
Settings
```

These can initially be placeholders.

## Important

Do not implement business functionality yet.

Build a clean foundation that can support the complete Jewellery ERP mobile application.