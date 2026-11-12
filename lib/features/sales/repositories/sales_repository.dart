import 'package:sqflite/sqflite.dart';

import '../models/sale.dart';

class SalesRepository {
  SalesRepository(this._database);

  final Database _database;

  // ---------------------------------------------------
  // TRANSACTION HISTORY
  // ---------------------------------------------------

  Future<List<SaleTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit <= 0) {
      throw ArgumentError('Limit harus lebih dari nol.');
    }

    if (offset < 0) {
      throw ArgumentError('Offset tidak boleh negatif.');
    }

    final conditions = <String>[];
    final arguments = <Object?>[];

    _appendDateFilters(
      conditions,
      arguments,
      startDate: startDate,
      endDate: endDate,
    );

    final query = searchQuery?.trim();

    if (query != null && query.isNotEmpty) {
      conditions.add(
        '(receipt_number LIKE ? COLLATE NOCASE '
        'OR cashier_name_snapshot LIKE ? COLLATE NOCASE)',
      );

      arguments
        ..add('%$query%')
        ..add('%$query%');
    }

    final results = await _database.query(
      'sales',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'transaction_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return results.map(SaleTransaction.fromMap).toList();
  }

  // ---------------------------------------------------
  // SALES SUMMARY
  // ---------------------------------------------------

  Future<SalesSummary> getSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final conditions = <String>[];
    final arguments = <Object?>[];

    _appendDateFilters(
      conditions,
      arguments,
      startDate: startDate,
      endDate: endDate,
    );

    final results = await _database.rawQuery('''
      SELECT
        COUNT(*) AS transaction_count,
        COALESCE(SUM(total), 0) AS revenue,
        COALESCE(SUM(discount_amount), 0) AS total_discount,
        COALESCE(AVG(total), 0) AS average_transaction
      FROM sales
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ''', arguments);

    final row = results.first;

    return SalesSummary(
      transactionCount: (row['transaction_count'] as num).toInt(),
      revenue: (row['revenue'] as num).toInt(),
      totalDiscount: (row['total_discount'] as num).toInt(),
      averageTransaction: (row['average_transaction'] as num).toInt(),
    );
  }

  // ---------------------------------------------------
  // TRANSACTION DETAIL
  // ---------------------------------------------------

  Future<SaleDetail?> getDetail(int saleId) async {
    if (saleId <= 0) {
      throw ArgumentError('ID transaksi tidak valid.');
    }

    final saleRows = await _database.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );

    if (saleRows.isEmpty) {
      return null;
    }

    final transaction = SaleTransaction.fromMap(saleRows.first);

    final itemRows = await _database.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );

    final items = <SaleItem>[];

    for (final itemRow in itemRows) {
      final saleItemId = itemRow['id'] as int;

      final addonRows = await _database.query(
        'sale_item_addons',
        where: 'sale_item_id = ?',
        whereArgs: [saleItemId],
        orderBy: 'id ASC',
      );

      final addons = addonRows.map(SaleItemAddon.fromMap).toList();

      items.add(
        SaleItem(
          id: saleItemId,
          productId: itemRow['product_id'] as int?,
          productName: itemRow['product_name_snapshot'] as String,
          unitPrice: itemRow['unit_price_snapshot'] as int,
          quantity: itemRow['quantity'] as int,
          baseSubtotal: itemRow['base_subtotal'] as int,
          addonsSubtotal: itemRow['addons_subtotal'] as int,
          lineTotal: itemRow['line_total'] as int,
          addons: addons,
        ),
      );
    }

    return SaleDetail(transaction: transaction, items: items);
  }

  // ---------------------------------------------------
  // DATE FILTER HELPERS
  // ---------------------------------------------------

  void _appendDateFilters(
    List<String> conditions,
    List<Object?> arguments, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (startDate != null && endDate != null) {
      final normalizedStart = _startOfDay(startDate);
      final normalizedEnd = _startOfDay(endDate);

      if (normalizedEnd.isBefore(normalizedStart)) {
        throw ArgumentError('Tanggal akhir tidak boleh sebelum tanggal awal.');
      }
    }

    if (startDate != null) {
      final startTimestamp = _startOfDay(startDate).millisecondsSinceEpoch;

      conditions.add('transaction_at >= ?');
      arguments.add(startTimestamp);
    }

    if (endDate != null) {
      // Tanggal akhir bersifat inklusif.
      // Batas query menggunakan awal hari berikutnya (eksklusif).
      final endExclusive = DateTime(
        endDate.year,
        endDate.month,
        endDate.day + 1,
      ).millisecondsSinceEpoch;

      conditions.add('transaction_at < ?');
      arguments.add(endExclusive);
    }
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
