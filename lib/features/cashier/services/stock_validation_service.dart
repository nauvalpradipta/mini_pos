import 'package:sqflite/sqflite.dart';

import '../models/cart_item.dart';

enum StockIssueType {
  emptyCart,
  unavailableProduct,
  insufficientProductStock,
  unavailableAddon,
  insufficientAddonStock,
  addonNotAssignedToProduct,
}

class StockValidationIssue {
  const StockValidationIssue({
    required this.type,
    required this.itemId,
    required this.itemName,
    required this.requestedQuantity,
    required this.availableQuantity,
    required this.message,
  });

  final StockIssueType type;
  final int? itemId;
  final String itemName;
  final int requestedQuantity;
  final int availableQuantity;
  final String message;
}

class StockValidationResult {
  StockValidationResult(List<StockValidationIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<StockValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

class StockValidationService {
  const StockValidationService(this._database);

  // DatabaseExecutor dapat berupa Database maupun Transaction.
  final DatabaseExecutor _database;

  Future<StockValidationResult> validate(List<CartItem> cartItems) async {
    final issues = <StockValidationIssue>[];

    if (cartItems.isEmpty) {
      return StockValidationResult([
        const StockValidationIssue(
          type: StockIssueType.emptyCart,
          itemId: null,
          itemName: 'Keranjang',
          requestedQuantity: 0,
          availableQuantity: 0,
          message: 'Keranjang masih kosong.',
        ),
      ]);
    }

    // Menampung total kebutuhan stok setiap produk.
    final productRequirements = <int, int>{};
    final productNames = <int, String>{};

    // Menampung total kebutuhan stok setiap add-on.
    final addonRequirements = <int, int>{};
    final addonNames = <int, String>{};

    // Menampung hubungan produk dan add-on yang dipilih.
    final productAddonPairs = <int, Set<int>>{};
    final productNamesForRelations = <int, String>{};

    for (final item in cartItems) {
      // Akumulasi kebutuhan produk.
      productRequirements.update(
        item.productId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );

      productNames[item.productId] = item.productName;

      productNamesForRelations[item.productId] = item.productName;

      for (final addon in item.addons) {
        // Total konsumsi add-on =
        // jumlah produk × jumlah add-on per produk.
        final requiredAddonQuantity = item.quantity * addon.quantityPerProduct;

        addonRequirements.update(
          addon.addonId,
          (quantity) => quantity + requiredAddonQuantity,
          ifAbsent: () => requiredAddonQuantity,
        );

        addonNames[addon.addonId] = addon.addonName;

        productAddonPairs
            .putIfAbsent(item.productId, () => <int>{})
            .add(addon.addonId);
      }
    }

    // ---------------------------------------------------
    // 1. VALIDASI STOK PRODUK
    // ---------------------------------------------------

    for (final entry in productRequirements.entries) {
      final productId = entry.key;
      final requestedQuantity = entry.value;

      final results = await _database.query(
        'products',
        columns: ['stock_quantity', 'is_active'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );

      if (results.isEmpty || results.first['is_active'] != 1) {
        issues.add(
          StockValidationIssue(
            type: StockIssueType.unavailableProduct,
            itemId: productId,
            itemName: productNames[productId]!,
            requestedQuantity: requestedQuantity,
            availableQuantity: 0,
            message:
                'Produk ${productNames[productId]} tidak ditemukan atau tidak aktif.',
          ),
        );

        continue;
      }

      final availableQuantity = results.first['stock_quantity'] as int;

      if (availableQuantity < requestedQuantity) {
        issues.add(
          StockValidationIssue(
            type: StockIssueType.insufficientProductStock,
            itemId: productId,
            itemName: productNames[productId]!,
            requestedQuantity: requestedQuantity,
            availableQuantity: availableQuantity,
            message:
                'Stok ${productNames[productId]} tidak mencukupi. '
                'Diminta $requestedQuantity, tersedia $availableQuantity.',
          ),
        );
      }
    }

    // ---------------------------------------------------
    // 2. VALIDASI STOK ADD-ON
    // ---------------------------------------------------

    for (final entry in addonRequirements.entries) {
      final addonId = entry.key;
      final requestedQuantity = entry.value;

      final results = await _database.query(
        'addons',
        columns: ['stock_quantity', 'is_active'],
        where: 'id = ?',
        whereArgs: [addonId],
        limit: 1,
      );

      if (results.isEmpty || results.first['is_active'] != 1) {
        issues.add(
          StockValidationIssue(
            type: StockIssueType.unavailableAddon,
            itemId: addonId,
            itemName: addonNames[addonId]!,
            requestedQuantity: requestedQuantity,
            availableQuantity: 0,
            message:
                'Add-on ${addonNames[addonId]} tidak ditemukan atau tidak aktif.',
          ),
        );

        continue;
      }

      final availableQuantity = results.first['stock_quantity'] as int;

      if (availableQuantity < requestedQuantity) {
        issues.add(
          StockValidationIssue(
            type: StockIssueType.insufficientAddonStock,
            itemId: addonId,
            itemName: addonNames[addonId]!,
            requestedQuantity: requestedQuantity,
            availableQuantity: availableQuantity,
            message:
                'Stok ${addonNames[addonId]} tidak mencukupi. '
                'Diminta $requestedQuantity, tersedia $availableQuantity.',
          ),
        );
      }
    }

    // ---------------------------------------------------
    // 3. VALIDASI RELASI PRODUK DAN ADD-ON
    // ---------------------------------------------------

    for (final entry in productAddonPairs.entries) {
      final productId = entry.key;
      final addonIds = entry.value;

      for (final addonId in addonIds) {
        final relations = await _database.query(
          'product_addons',
          columns: ['product_id'],
          where: 'product_id = ? AND addon_id = ?',
          whereArgs: [productId, addonId],
          limit: 1,
        );

        if (relations.isEmpty) {
          issues.add(
            StockValidationIssue(
              type: StockIssueType.addonNotAssignedToProduct,
              itemId: addonId,
              itemName: addonNames[addonId]!,
              requestedQuantity: 0,
              availableQuantity: 0,
              message:
                  'Add-on ${addonNames[addonId]} tidak tersedia '
                  'untuk produk ${productNamesForRelations[productId]}.',
            ),
          );
        }
      }
    }

    return StockValidationResult(issues);
  }
}
