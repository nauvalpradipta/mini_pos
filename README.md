# Mini POS

A standalone, offline-first Point of Sale (POS) application built with Flutter and SQLite. Designed for Food & Beverage and retail businesses, the application provides cashier operations, product and inventory management, checkout processing, and sales reporting without requiring an internet connection.

## Features

### 1. Authentication & Local Session

- Cashier registration and offline login.
- Local session persistence using SharedPreferences.
- Session restoration when the application is restarted.
- Account status validation and logout.

### 2. Master Data Management

**Categories**

- Create, edit, and deactivate product categories.
- Filter products by category.

**Products**

- Create, edit, search, and deactivate products.
- Manage product names, categories, selling prices, and stock quantities.
- Select product photos using the device camera or gallery.
- Persist selected photos in the application's documents directory.

**Add-ons / Toppings**

- Create and manage add-ons.
- Configure additional prices and independent stock quantities.
- Assign add-ons to individual products.

### 3. Cashier & Sales Transactions

- Search products and filter by category.
- Add products and configure add-ons in the shopping cart.
- Adjust item quantities and remove cart items.
- Calculate product and add-on subtotals.
- Apply percentage or fixed-amount discounts.
- Validate discount limits and prevent negative transaction totals.
- Enter cash received and calculate change automatically.
- Use quick-payment amount suggestions.
- Validate product and add-on stock before checkout.
- Save transactions using atomic SQLite transactions.
- Display a digital receipt after successful checkout.

The digital receipt includes store information, cashier details, transaction time, product and add-on details, subtotal, discount, total, payment, and change.

### 4. Sales Dashboard & Reports

- View total revenue and successful transaction count.
- View discount totals and average transaction value.
- Browse transaction history.
- Search transactions by receipt number or cashier.
- Filter transactions by date range.
- Inspect historical transaction details.

### 5. Store Settings

- Configure store name, address, and phone number.
- Configure receipt footer text.
- Display current cashier account information.
- Manage the active cashier session.

## Technical Stack

| Area              | Technology                  |
| ----------------- | --------------------------- |
| Framework         | Flutter                     |
| Language          | Dart                        |
| Architecture      | Feature-oriented MVVM       |
| State Management  | Provider (ChangeNotifier)   |
| Local Database    | SQLite using sqflite        |
| Session Storage   | SharedPreferences           |
| Image Selection   | image_picker                |
| Image Persistence | path_provider               |
| Password Security | cryptography                |
| Testing           | Flutter Test and SQLite FFI |

## Architecture

The application uses a feature-oriented structure with separation of presentation, business logic, and data access.

- **Views:** Build the user interface and handle user interactions.
- **ViewModels:** Manage application state and coordinate business operations.
- **Repositories:** Handle data access and SQLite operations.
- **Models:** Represent application entities and transaction data.
- **Services:** Encapsulate supporting operations such as authentication, password hashing, image persistence, and stock validation.

Provider is used to expose and manage ChangeNotifier-based ViewModels across the application.

### Project Structure

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
    │   ├── models/
    │   ├── repositories/
    │   ├── services/
    │   ├── viewmodels/
    │   └── views/
    ├── cashier/
    │   ├── models/
    │   ├── repositories/
    │   ├── services/
    │   ├── viewmodels/
    │   └── views/
    ├── products/
    │   ├── models/
    │   ├── repositories/
    │   ├── services/
    │   ├── viewmodels/
    │   └── views/
    ├── sales/
    │   ├── models/
    │   ├── repositories/
    │   ├── viewmodels/
    │   └── views/
    └── settings/
        ├── models/
        ├── repositories/
        ├── viewmodels/
        └── views/

test/
└── features/
```

## Database Structure

The application uses a relational SQLite database with the following tables:

| Table              | Purpose                                                        |
| ------------------ | -------------------------------------------------------------- |
| `users`            | Cashier accounts and authentication data                       |
| `categories`       | Product categories                                             |
| `products`         | Product details, prices, stock, and image paths                |
| `addons`           | Add-on names, additional prices, and separate stock            |
| `product_addons`   | Many-to-many relationship between products and add-ons         |
| `sales`            | Transaction headers, payment data, and cashier/store snapshots |
| `sale_items`       | Historical product name, price, and quantity snapshots         |
| `sale_item_addons` | Historical add-on name, price, and quantity snapshots          |
| `app_settings`     | Store configuration                                            |

The database schema is initialized locally when the application is first launched. Foreign key constraints and indexes are used to maintain relational integrity and support frequently queried data.

## Important Business Logic

### Shared Stock Validation

Stock requirements are accumulated across all cart entries before checkout.

For example, if a product has 2 units available:

- 1 unit without an add-on consumes 1 product unit.
- 1 unit with an add-on consumes another product unit.
- A third unit is rejected when stock is insufficient.

The same accumulated validation applies to add-on stock.

### Atomic Checkout

Checkout operations run inside an SQLite transaction. The transaction includes:

- Cashier and store information validation.
- Product and add-on stock validation.
- Transaction header and detail insertion.
- Historical snapshot creation.
- Product and add-on stock deduction.

If an operation fails, the transaction is rolled back to prevent partial transaction records or inconsistent stock quantities.

### Historical Transaction Immutability

Transaction records retain snapshots of product names, prices, add-on details, cashier names, and store information.

Changes to master data do not overwrite historical transaction details. Product and add-on references can become null without losing their historical snapshot values.

### Discount Calculation Protection

The application validates discount inputs and prevents:

- Negative discount values.
- Percentage discounts above 100%.
- Fixed discounts exceeding the subtotal.
- Negative transaction totals.
- Payments below the transaction total.

### Offline Photo Persistence

Photos captured using the camera or selected from the gallery are copied into the application's documents directory under `product_images`.

The database stores the saved local image path instead of relying on temporary picker cache files.

## Getting Started

### Prerequisites

- Flutter SDK installed and configured.
- Dart SDK compatible with the Flutter project.
- Android development environment.

### Installation

Clone the repository:

```bash
git clone https://github.com/nauvalpradipta/mini_pos.git
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

Register a cashier account through the application to start using the POS.

## Running Tests

Run static analysis:

```bash
flutter analyze
```

Run the complete test suite:

```bash
flutter test --concurrency=1 --reporter expanded
```

The test suite covers repositories, business logic, ViewModels, widgets, and application integration using SQLite FFI for database testing.

## Building the Android Release APK

Build the release APK:

```bash
flutter build apk --release
```

The generated APK can be found at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Bonus Features & Scope

Implemented:

- Responsive cashier interface for different screen sizes.
- Quick-payment amount suggestions.
- Stock availability validation.
- Sales date filtering and transaction search.
- Digital receipt preview.
- Persistent local product photos.

Not implemented:

- Direct Bluetooth thermal printer integration using ESC/POS.
- Cloud synchronization or remote backup.

## Known Limitations

- The receipt footer can be configured and saved in store settings, but is not yet displayed in the digital receipt.
- The application currently stores data locally on the device. There is no automatic synchronization between multiple cashier devices.

## Submission

Developed as part of the Mobile Developer technical challenge for PT Daya Rekadigital Indonesia.
