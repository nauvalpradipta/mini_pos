/// Centralized SQLite table names and schema definitions.
class DatabaseTables {
  DatabaseTables._();

  // Table names
  static const String users = 'users';
  static const String categories = 'categories';
  static const String products = 'products';
  static const String addons = 'addons';
  static const String productAddons = 'product_addons';
  static const String sales = 'sales';
  static const String saleItems = 'sale_items';
  static const String saleItemAddons = 'sale_item_addons';
  static const String appSettings = 'app_settings';

  /// SQL statements executed when creating a new database.
  static const List<String> createStatements = [
    // 1. Users
    '''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      full_name TEXT NOT NULL,
      username TEXT NOT NULL COLLATE NOCASE UNIQUE,
      password_hash TEXT NOT NULL,
      password_salt TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1
        CHECK (is_active IN (0, 1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',

    // 2. Categories
    '''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 1
        CHECK (is_active IN (0, 1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',

    // 3. Add-ons
    '''
    CREATE TABLE addons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      additional_price INTEGER NOT NULL
        CHECK (additional_price >= 0),
      stock_quantity INTEGER NOT NULL DEFAULT 0
        CHECK (stock_quantity >= 0),
      is_active INTEGER NOT NULL DEFAULT 1
        CHECK (is_active IN (0, 1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',

    // 4. Products
    '''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      selling_price INTEGER NOT NULL
        CHECK (selling_price >= 0),
      stock_quantity INTEGER NOT NULL DEFAULT 0
        CHECK (stock_quantity >= 0),
      image_path TEXT,
      is_active INTEGER NOT NULL DEFAULT 1
        CHECK (is_active IN (0, 1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,

      FOREIGN KEY (category_id)
        REFERENCES categories(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    )
    ''',

    // 5. Product and add-on mapping
    '''
    CREATE TABLE product_addons (
      product_id INTEGER NOT NULL,
      addon_id INTEGER NOT NULL,
      created_at INTEGER NOT NULL,

      PRIMARY KEY (product_id, addon_id),

      FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

      FOREIGN KEY (addon_id)
        REFERENCES addons(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
    )
    ''',

    // 6. Sales transaction header
    '''
    CREATE TABLE sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receipt_number TEXT NOT NULL UNIQUE,

      cashier_id INTEGER NOT NULL,
      cashier_name_snapshot TEXT NOT NULL,

      store_name_snapshot TEXT NOT NULL,
      store_address_snapshot TEXT NOT NULL DEFAULT '',
      store_phone_snapshot TEXT NOT NULL DEFAULT '',

      transaction_at INTEGER NOT NULL,

      subtotal INTEGER NOT NULL
        CHECK (subtotal >= 0),

      discount_type TEXT NOT NULL
        CHECK (
          discount_type IN ('none', 'percentage', 'fixed')
        ),

      discount_value INTEGER NOT NULL DEFAULT 0
        CHECK (discount_value >= 0),

      discount_amount INTEGER NOT NULL DEFAULT 0
        CHECK (
          discount_amount >= 0
          AND discount_amount <= subtotal
        ),

      total INTEGER NOT NULL
        CHECK (
          total >= 0
          AND total = subtotal - discount_amount
        ),

      cash_received INTEGER NOT NULL
        CHECK (cash_received >= total),

      change_amount INTEGER NOT NULL
        CHECK (
          change_amount >= 0
          AND change_amount = cash_received - total
        ),

      created_at INTEGER NOT NULL,

      CHECK (
        (
          discount_type = 'percentage'
          AND discount_value <= 100
        )
        OR discount_type = 'fixed'
        OR (
          discount_type = 'none'
          AND discount_value = 0
        )
      ),

      FOREIGN KEY (cashier_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    )
    ''',

    // 7. Sale items with historical snapshots
    '''
    CREATE TABLE sale_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      product_id INTEGER,

      product_name_snapshot TEXT NOT NULL,
      unit_price_snapshot INTEGER NOT NULL
        CHECK (unit_price_snapshot >= 0),

      quantity INTEGER NOT NULL
        CHECK (quantity > 0),

      base_subtotal INTEGER NOT NULL
        CHECK (
          base_subtotal =
          unit_price_snapshot * quantity
        ),

      addons_subtotal INTEGER NOT NULL DEFAULT 0
        CHECK (addons_subtotal >= 0),

      line_total INTEGER NOT NULL
        CHECK (
          line_total =
          base_subtotal + addons_subtotal
        ),

      created_at INTEGER NOT NULL,

      FOREIGN KEY (sale_id)
        REFERENCES sales(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

      FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
    )
    ''',

    // 8. Sale item add-on snapshots
    '''
    CREATE TABLE sale_item_addons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_item_id INTEGER NOT NULL,
      addon_id INTEGER,

      addon_name_snapshot TEXT NOT NULL,
      unit_price_snapshot INTEGER NOT NULL
        CHECK (unit_price_snapshot >= 0),

      quantity_per_product INTEGER NOT NULL
        CHECK (quantity_per_product > 0),

      total_quantity INTEGER NOT NULL
        CHECK (total_quantity > 0),

      subtotal INTEGER NOT NULL
        CHECK (
          subtotal = unit_price_snapshot * total_quantity
        ),

      FOREIGN KEY (sale_item_id)
        REFERENCES sale_items(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

      FOREIGN KEY (addon_id)
        REFERENCES addons(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
    )
    ''',

    // 9. Store settings
    '''
    CREATE TABLE app_settings (
      id INTEGER PRIMARY KEY CHECK (id = 1),

      store_name TEXT NOT NULL,
      address TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      receipt_footer TEXT NOT NULL DEFAULT '',

      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
  ];

  /// Database indexes for frequently queried columns.
  static const List<String> indexStatements = [
    '''
    CREATE INDEX idx_products_category
    ON products(category_id)
    ''',

    '''
    CREATE INDEX idx_products_active
    ON products(is_active)
    ''',

    '''
    CREATE INDEX idx_products_name
    ON products(name COLLATE NOCASE)
    ''',

    '''
    CREATE INDEX idx_product_addons_addon
    ON product_addons(addon_id)
    ''',

    '''
    CREATE INDEX idx_sales_transaction_date
    ON sales(transaction_at)
    ''',

    '''
    CREATE INDEX idx_sales_cashier
    ON sales(cashier_id)
    ''',

    '''
    CREATE INDEX idx_sale_items_sale
    ON sale_items(sale_id)
    ''',

    '''
    CREATE INDEX idx_sale_item_addons_item
    ON sale_item_addons(sale_item_id)
    ''',
  ];
}
