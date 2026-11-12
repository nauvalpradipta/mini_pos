# Mini POS

A local, offline-capable Point of Sale (POS) application built with Flutter and SQLite. The application provides essential cashier operations, product and inventory management, transaction processing, sales reporting, and store settings.

## Features

### 1. Authentication

- Cashier registration and login.
- Session persistence.
- Logout functionality.
- Active account validation.

### 2. Product Management

- Create, view, update, and deactivate products.
- Manage product categories.
- Search and filter products.
- Manage product add-ons.
- Assign add-ons to products.

### 3. Cashier and Checkout

- Browse and search available products.
- Select product add-ons and quantities.
- Add, update, and remove cart items.
- Calculate subtotals and transaction totals.
- Apply fixed or percentage discounts.
- Calculate cash payments and change.
- Validate product and add-on stock before checkout.
- Process transactions atomically using SQLite transactions.
- Preserve transaction details through historical data snapshots.

### 4. Sales and Reports

- View sales summaries.
- View transaction history.
- Search transactions.
- Filter transactions by date.
- View transaction details, including product and add-on snapshots.

### 5. Store Settings

- Update store name.
- Update store address and phone number.
- Configure receipt footer text.
- Display cashier account information.

## Tech Stack

- **Framework:** Flutter
- **Language:** Dart
- **Local Database:** SQLite
- **State Management:** Provider
- **Session Storage:** SharedPreferences
- **Testing:** Flutter Test and SQLite FFI

## Project Structure

```text
lib/
├── app/
│   ├── auth/
│   ├── navigation/
│   └── theme/
├── core/
│   ├── database/
│   └── widgets/
└── features/
    ├── auth/
    ├── cashier/
    ├── products/
    ├── sales/
    └── settings/

test/
├── features/
└── widget_test.dart
```

The application follows a feature-oriented structure with separated models, repositories, view models, and views.

## Getting Started

### Prerequisites

- Flutter SDK installed and configured.
- Dart SDK compatible with the Flutter installation.
- Android development environment or another supported Flutter target platform.

### Installation

Clone the repository:

```bash
git clone &lt;repository-url&gt;
cd mini_pos
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

Register a cashier account through the application or log in using an existing account.

## Running Tests

Analyze the project:

```bash
flutter analyze
```

Run the complete test suite:

```bash
flutter test --concurrency=1 --reporter expanded
```

**Latest verified test result:** 345 tests passed.

## Building the Android APK

Build a release APK:

```bash
flutter build apk --release
```

The generated APK is located at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Data Storage

The application uses a local SQLite database for operational data and SharedPreferences for session persistence.

Core cashier operations are designed to work without an internet connection. Data is stored locally on the device.

## Known Limitations

- The receipt footer can be configured and persisted through store settings, but it has not yet been integrated into the generated transaction receipt or transaction snapshot.
- Cloud-based data synchronization is not implemented.

## Notes

This project was developed as part of a technical test submission for a Flutter-based Point of Sale application.
