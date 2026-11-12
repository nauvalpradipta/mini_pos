import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/checkout.dart';
import '../services/stock_validation_service.dart';

class TransactionRepository {
  TransactionRepository(this._database);

  final Database _database;

  Future<CheckoutResult> checkout(CheckoutRequest request) async {
    return _database.transaction((transaction) async {
      // ---------------------------------------------------
      // 1. VALIDASI INPUT DASAR
      // ---------------------------------------------------

      if (request.cashierId <= 0) {
        throw const CheckoutException('ID kasir tidak valid.');
      }

      if (request.cashReceived < 0) {
        throw const CheckoutException(
          'Jumlah uang yang diterima tidak boleh negatif.',
        );
      }

      // ---------------------------------------------------
      // 2. VALIDASI KASIR
      // ---------------------------------------------------

      final cashierRows = await transaction.query(
        'users',
        columns: ['id', 'full_name', 'is_active'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [request.cashierId],
        limit: 1,
      );

      if (cashierRows.isEmpty) {
        throw const CheckoutException(
          'Kasir tidak ditemukan atau sudah dinonaktifkan.',
        );
      }

      final cashierName = cashierRows.first['full_name'] as String;

      // ---------------------------------------------------
      // 3. AMBIL SNAPSHOT INFORMASI TOKO
      // ---------------------------------------------------

      final settingsRows = await transaction.query(
        'app_settings',
        columns: ['store_name', 'address', 'phone'],
        where: 'id = 1',
        limit: 1,
      );

      if (settingsRows.isEmpty) {
        throw const CheckoutException('Pengaturan toko tidak ditemukan.');
      }

      final settings = settingsRows.first;

      final storeName = settings['store_name'] as String;
      final storeAddress = settings['address'] as String;
      final storePhone = settings['phone'] as String;

      // ---------------------------------------------------
      // 4. VALIDASI STOK PRODUK DAN ADD-ON
      // ---------------------------------------------------

      final stockValidator = StockValidationService(transaction);

      final stockResult = await stockValidator.validate(request.cartItems);

      if (!stockResult.isValid) {
        final errorMessage = stockResult.issues
            .map((issue) => issue.message)
            .join('\n');

        throw CheckoutException(errorMessage);
      }

      // ---------------------------------------------------
      // 5. SIAPKAN SNAPSHOT ITEM TRANSAKSI
      // ---------------------------------------------------

      final itemSnapshots = <_SaleItemSnapshot>[];

      var subtotal = 0;

      for (final cartItem in request.cartItems) {
        // Ambil data produk terkini dari database.
        final productRows = await transaction.query(
          'products',
          columns: ['id', 'name', 'selling_price'],
          where: 'id = ?',
          whereArgs: [cartItem.productId],
          limit: 1,
        );

        if (productRows.isEmpty) {
          throw CheckoutException(
            'Produk ${cartItem.productName} tidak ditemukan.',
          );
        }

        final product = productRows.first;

        final productName = product['name'] as String;
        final productPrice = product['selling_price'] as int;

        // Pastikan harga di keranjang masih sesuai database.
        if (cartItem.unitPrice != productPrice) {
          throw CheckoutException(
            'Harga produk $productName berubah. '
            'Perbarui keranjang sebelum checkout.',
          );
        }

        final baseSubtotal = productPrice * cartItem.quantity;

        final addonSnapshots = <_SaleAddonSnapshot>[];

        var addonsSubtotal = 0;

        for (final cartAddon in cartItem.addons) {
          // Ambil data add-on terkini dari database.
          final addonRows = await transaction.query(
            'addons',
            columns: ['id', 'name', 'additional_price'],
            where: 'id = ?',
            whereArgs: [cartAddon.addonId],
            limit: 1,
          );

          if (addonRows.isEmpty) {
            throw CheckoutException(
              'Add-on ${cartAddon.addonName} tidak ditemukan.',
            );
          }

          final addon = addonRows.first;

          final addonName = addon['name'] as String;
          final addonPrice = addon['additional_price'] as int;

          if (cartAddon.additionalPrice != addonPrice) {
            throw CheckoutException(
              'Harga add-on $addonName berubah. '
              'Perbarui keranjang sebelum checkout.',
            );
          }

          final totalQuantity =
              cartAddon.quantityPerProduct * cartItem.quantity;

          final addonSubtotal = addonPrice * totalQuantity;

          addonSnapshots.add(
            _SaleAddonSnapshot(
              addonId: cartAddon.addonId,
              name: addonName,
              unitPrice: addonPrice,
              quantityPerProduct: cartAddon.quantityPerProduct,
              totalQuantity: totalQuantity,
              subtotal: addonSubtotal,
            ),
          );

          addonsSubtotal += addonSubtotal;
        }

        final lineTotal = baseSubtotal + addonsSubtotal;

        itemSnapshots.add(
          _SaleItemSnapshot(
            productId: cartItem.productId,
            productName: productName,
            unitPrice: productPrice,
            quantity: cartItem.quantity,
            baseSubtotal: baseSubtotal,
            addonsSubtotal: addonsSubtotal,
            lineTotal: lineTotal,
            addons: addonSnapshots,
          ),
        );

        subtotal += lineTotal;
      }

      // ---------------------------------------------------
      // 6. HITUNG DISKON DAN TOTAL
      // ---------------------------------------------------

      final discountAmount = _calculateDiscountAmount(
        subtotal: subtotal,
        discountType: request.discountType,
        discountValue: request.discountValue,
      );

      final total = subtotal - discountAmount;

      // ---------------------------------------------------
      // 7. VALIDASI PEMBAYARAN
      // ---------------------------------------------------

      if (request.cashReceived < total) {
        throw CheckoutException(
          'Uang pembayaran kurang. '
          'Total Rp$total, diterima Rp${request.cashReceived}.',
        );
      }

      final changeAmount = request.cashReceived - total;

      // ---------------------------------------------------
      // 8. BUAT NOMOR STRUK DAN WAKTU TRANSAKSI
      // ---------------------------------------------------

      final now = DateTime.now();
      final transactionAt = now.millisecondsSinceEpoch;

      final receiptNumber = _generateReceiptNumber(now);

      // ---------------------------------------------------
      // 9. SIMPAN HEADER TRANSAKSI
      // ---------------------------------------------------

      final saleId = await transaction.insert('sales', {
        'receipt_number': receiptNumber,
        'cashier_id': request.cashierId,
        'cashier_name_snapshot': cashierName,
        'store_name_snapshot': storeName,
        'store_address_snapshot': storeAddress,
        'store_phone_snapshot': storePhone,
        'transaction_at': transactionAt,
        'subtotal': subtotal,
        'discount_type': request.discountType.name,
        'discount_value': request.discountValue,
        'discount_amount': discountAmount,
        'total': total,
        'cash_received': request.cashReceived,
        'change_amount': changeAmount,
        'created_at': transactionAt,
      });

      // ---------------------------------------------------
      // 10. SIMPAN ITEM DAN ADD-ON TRANSAKSI
      // ---------------------------------------------------

      for (final item in itemSnapshots) {
        final saleItemId = await transaction.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name_snapshot': item.productName,
          'unit_price_snapshot': item.unitPrice,
          'quantity': item.quantity,
          'base_subtotal': item.baseSubtotal,
          'addons_subtotal': item.addonsSubtotal,
          'line_total': item.lineTotal,
          'created_at': transactionAt,
        });

        for (final addon in item.addons) {
          await transaction.insert('sale_item_addons', {
            'sale_item_id': saleItemId,
            'addon_id': addon.addonId,
            'addon_name_snapshot': addon.name,
            'unit_price_snapshot': addon.unitPrice,
            'quantity_per_product': addon.quantityPerProduct,
            'total_quantity': addon.totalQuantity,
            'subtotal': addon.subtotal,
          });
        }
      }

      // ---------------------------------------------------
      // 11. AKUMULASI KEBUTUHAN STOK
      // ---------------------------------------------------

      final productRequirements = <int, int>{};
      final addonRequirements = <int, int>{};

      for (final item in request.cartItems) {
        productRequirements.update(
          item.productId,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );

        for (final addon in item.addons) {
          final requiredQuantity = item.quantity * addon.quantityPerProduct;

          addonRequirements.update(
            addon.addonId,
            (quantity) => quantity + requiredQuantity,
            ifAbsent: () => requiredQuantity,
          );
        }
      }

      // ---------------------------------------------------
      // 12. KURANGI STOK PRODUK
      // ---------------------------------------------------

      for (final entry in productRequirements.entries) {
        final affectedRows = await transaction.rawUpdate(
          '''
          UPDATE products
          SET stock_quantity = stock_quantity - ?,
              updated_at = ?
          WHERE id = ?
            AND is_active = 1
            AND stock_quantity >= ?
          ''',
          [entry.value, transactionAt, entry.key, entry.value],
        );

        if (affectedRows != 1) {
          throw CheckoutException(
            'Gagal memperbarui stok produk ID ${entry.key}. '
            'Silakan periksa kembali stok.',
          );
        }
      }

      // ---------------------------------------------------
      // 13. KURANGI STOK ADD-ON
      // ---------------------------------------------------

      for (final entry in addonRequirements.entries) {
        final affectedRows = await transaction.rawUpdate(
          '''
          UPDATE addons
          SET stock_quantity = stock_quantity - ?,
              updated_at = ?
          WHERE id = ?
            AND is_active = 1
            AND stock_quantity >= ?
          ''',
          [entry.value, transactionAt, entry.key, entry.value],
        );

        if (affectedRows != 1) {
          throw CheckoutException(
            'Gagal memperbarui stok add-on ID ${entry.key}. '
            'Silakan periksa kembali stok.',
          );
        }
      }

      // ---------------------------------------------------
      // 14. KEMBALIKAN HASIL CHECKOUT
      // ---------------------------------------------------

      return CheckoutResult(
        saleId: saleId,
        receiptNumber: receiptNumber,
        transactionAt: transactionAt,
        subtotal: subtotal,
        discountType: request.discountType,
        discountValue: request.discountValue,
        discountAmount: discountAmount,
        total: total,
        cashReceived: request.cashReceived,
        changeAmount: changeAmount,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
      );
    });
  }

  int _calculateDiscountAmount({
    required int subtotal,
    required DiscountType discountType,
    required int discountValue,
  }) {
    if (discountValue < 0) {
      throw const CheckoutException('Nilai diskon tidak boleh negatif.');
    }

    switch (discountType) {
      case DiscountType.none:
        if (discountValue != 0) {
          throw const CheckoutException(
            'Nilai diskon harus nol jika tidak menggunakan diskon.',
          );
        }

        return 0;

      case DiscountType.percentage:
        if (discountValue > 100) {
          throw const CheckoutException(
            'Diskon persentase tidak boleh lebih dari 100%.',
          );
        }

        // Pembulatan ke bawah agar hasil tetap berupa Rupiah bulat.
        return (subtotal * discountValue) ~/ 100;

      case DiscountType.fixed:
        if (discountValue > subtotal) {
          throw const CheckoutException(
            'Diskon nominal tidak boleh melebihi subtotal.',
          );
        }

        return discountValue;
    }
  }

  String _generateReceiptNumber(DateTime dateTime) {
    final datePart =
        '${dateTime.year.toString().padLeft(4, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}';

    final timePart =
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}'
        '${dateTime.second.toString().padLeft(2, '0')}';

    final uniquePart = dateTime.microsecondsSinceEpoch.toString();

    final randomPart = Random.secure()
        .nextInt(1000000)
        .toString()
        .padLeft(6, '0');

    return 'POS-$datePart-$timePart-$uniquePart-$randomPart';
  }
}

// Snapshot satu baris produk yang akan disimpan ke sale_items.
class _SaleItemSnapshot {
  const _SaleItemSnapshot({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.baseSubtotal,
    required this.addonsSubtotal,
    required this.lineTotal,
    required this.addons,
  });

  final int productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final int baseSubtotal;
  final int addonsSubtotal;
  final int lineTotal;
  final List<_SaleAddonSnapshot> addons;
}

// Snapshot add-on yang akan disimpan ke sale_item_addons.
class _SaleAddonSnapshot {
  const _SaleAddonSnapshot({
    required this.addonId,
    required this.name,
    required this.unitPrice,
    required this.quantityPerProduct,
    required this.totalQuantity,
    required this.subtotal,
  });

  final int addonId;
  final String name;
  final int unitPrice;
  final int quantityPerProduct;
  final int totalQuantity;
  final int subtotal;
}
