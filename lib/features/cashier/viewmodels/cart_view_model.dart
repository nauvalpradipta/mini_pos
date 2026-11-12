import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../products/models/addon.dart';
import '../../products/models/product.dart';
import '../models/cart_item.dart';

class CartStockException implements Exception {
  const CartStockException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CartViewModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  final Map<int, int> _productStockById = {};
  final Map<int, int> _addonStockById = {};

  // ---------------------------------------------------
  // GETTERS
  // ---------------------------------------------------

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  // Jumlah seluruh unit produk dalam keranjang.
  int get itemCount => _items.fold(0, (total, item) => total + item.quantity);

  // Jumlah jenis/baris produk dalam keranjang.
  int get uniqueItemCount => _items.length;

  // Total harga produk tanpa add-on.
  int get productSubtotal =>
      _items.fold(0, (total, item) => total + item.productSubtotal);

  // Total harga semua add-on.
  int get addonsSubtotal =>
      _items.fold(0, (total, item) => total + item.addonsSubtotal);

  // Total keseluruhan sebelum diskon.
  int get subtotal => _items.fold(0, (total, item) => total + item.lineTotal);

  // ---------------------------------------------------
  // ADD PRODUCT
  // ---------------------------------------------------

  void addProduct(
    Product product, {
    List<Addon> selectedAddons = const [],
    Map<int, int> addonQuantities = const {},
  }) {
    if (product.id == null || product.id! <= 0) {
      throw ArgumentError('ID produk tidak valid.');
    }

    if (!product.isActive) {
      throw ArgumentError('Produk sudah dinonaktifkan.');
    }

    final selectedAddonIds = selectedAddons.map((addon) => addon.id).toSet();

    if (selectedAddonIds.contains(null)) {
      throw ArgumentError('ID add-on tidak valid.');
    }

    if (selectedAddonIds.length != selectedAddons.length) {
      throw ArgumentError('Add-on yang sama tidak boleh dipilih dua kali.');
    }

    if (addonQuantities.keys.any((id) => !selectedAddonIds.contains(id))) {
      throw ArgumentError('Jumlah add-on tidak sesuai pilihan.');
    }

    final cartAddons = selectedAddons.map((addon) {
      if (!addon.isActive) {
        throw ArgumentError('Add-on ${addon.name} sudah dinonaktifkan.');
      }

      return CartItemAddon(
        addonId: addon.id!,
        addonName: addon.name,
        additionalPrice: addon.additionalPrice,
        quantityPerProduct: addonQuantities[addon.id!] ?? 1,
      );
    }).toList();

    final candidate = CartItem(
      productId: product.id!,
      productName: product.name,
      unitPrice: product.sellingPrice,
      quantity: 1,
      addons: cartAddons,
    );

    final existingIndex = _findMatchingItem(candidate);
    final nextItems = List<CartItem>.of(_items);

    if (existingIndex >= 0) {
      nextItems[existingIndex] = _copyWithQuantity(
        nextItems[existingIndex],
        nextItems[existingIndex].quantity + 1,
      );
    } else {
      nextItems.add(candidate);
    }

    final productStocks = {..._productStockById, product.id!: product.stock};

    final addonStocks = {
      ..._addonStockById,
      for (final addon in selectedAddons) addon.id!: addon.stock,
    };

    // Validate the entire prospective cart before changing its contents.
    _validateStock(
      nextItems,
      productStocks: productStocks,
      addonStocks: addonStocks,
    );

    _productStockById.addAll(productStocks);
    _addonStockById.addAll(addonStocks);

    if (existingIndex >= 0) {
      _items[existingIndex] = nextItems[existingIndex];
    } else {
      _items.add(candidate);
    }

    notifyListeners();
  }

  // ---------------------------------------------------
  // QUANTITY MANAGEMENT
  // ---------------------------------------------------

  void increaseQuantity(CartItem item) {
    final index = _findMatchingItem(item);

    _ensureItemExists(index);

    final updatedItem = _copyWithQuantity(
      _items[index],
      _items[index].quantity + 1,
    );

    final nextItems = List<CartItem>.of(_items);
    nextItems[index] = updatedItem;

    _validateStock(nextItems);

    _items[index] = updatedItem;

    notifyListeners();
  }

  void decreaseQuantity(CartItem item) {
    final index = _findMatchingItem(item);

    _ensureItemExists(index);

    final currentItem = _items[index];

    if (currentItem.quantity <= 1) {
      _items.removeAt(index);
    } else {
      _items[index] = _copyWithQuantity(currentItem, currentItem.quantity - 1);
    }

    notifyListeners();
  }

  void setQuantity(CartItem item, int quantity) {
    if (quantity <= 0) {
      throw ArgumentError('Jumlah produk harus lebih dari nol.');
    }

    final index = _findMatchingItem(item);

    _ensureItemExists(index);

    final updatedItem = _copyWithQuantity(_items[index], quantity);

    final nextItems = List<CartItem>.of(_items);
    nextItems[index] = updatedItem;

    _validateStock(nextItems);

    _items[index] = updatedItem;

    notifyListeners();
  }

  // ---------------------------------------------------
  // REMOVE AND CLEAR
  // ---------------------------------------------------

  void removeItem(CartItem item) {
    final index = _findMatchingItem(item);

    _ensureItemExists(index);

    _items.removeAt(index);

    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;

    _items.clear();

    notifyListeners();
  }

  // ---------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------

  int _findMatchingItem(CartItem target) {
    return _items.indexWhere(
      (existing) => _hasSameConfiguration(existing, target),
    );
  }

  bool _hasSameConfiguration(CartItem first, CartItem second) {
    if (first.productId != second.productId ||
        first.productName != second.productName ||
        first.unitPrice != second.unitPrice ||
        first.addons.length != second.addons.length) {
      return false;
    }

    final firstAddons = {
      for (final addon in first.addons) addon.addonId: addon,
    };

    for (final addon in second.addons) {
      final existing = firstAddons[addon.addonId];

      if (existing == null ||
          existing.addonName != addon.addonName ||
          existing.additionalPrice != addon.additionalPrice ||
          existing.quantityPerProduct != addon.quantityPerProduct) {
        return false;
      }
    }

    return true;
  }

  CartItem _copyWithQuantity(CartItem item, int quantity) {
    return CartItem(
      productId: item.productId,
      productName: item.productName,
      unitPrice: item.unitPrice,
      quantity: quantity,
      addons: item.addons,
    );
  }

  void _validateStock(
    List<CartItem> items, {
    Map<int, int>? productStocks,
    Map<int, int>? addonStocks,
  }) {
    final availableProducts = productStocks ?? _productStockById;
    final availableAddons = addonStocks ?? _addonStockById;

    final productRequirements = <int, int>{};
    final productNames = <int, String>{};

    final addonRequirements = <int, int>{};
    final addonNames = <int, String>{};

    // Accumulate stock requirements across every cart configuration.
    for (final item in items) {
      productRequirements.update(
        item.productId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );

      productNames[item.productId] = item.productName;

      for (final addon in item.addons) {
        final requiredQuantity = item.quantity * addon.quantityPerProduct;

        addonRequirements.update(
          addon.addonId,
          (quantity) => quantity + requiredQuantity,
          ifAbsent: () => requiredQuantity,
        );

        addonNames[addon.addonId] = addon.addonName;
      }
    }

    // Validate accumulated product stock.
    for (final entry in productRequirements.entries) {
      final available = availableProducts[entry.key];

      if (available == null) {
        throw StateError(
          'Informasi stok produk ${productNames[entry.key]} tidak tersedia.',
        );
      }

      if (entry.value > available) {
        throw CartStockException(
          'Stok ${productNames[entry.key]} tidak mencukupi. '
          'Diminta ${entry.value}, tersedia $available.',
        );
      }
    }

    // Validate accumulated add-on stock across all products.
    for (final entry in addonRequirements.entries) {
      final available = availableAddons[entry.key];

      if (available == null) {
        throw StateError(
          'Informasi stok add-on ${addonNames[entry.key]} tidak tersedia.',
        );
      }

      if (entry.value > available) {
        throw CartStockException(
          'Stok ${addonNames[entry.key]} tidak mencukupi. '
          'Diminta ${entry.value}, tersedia $available.',
        );
      }
    }
  }

  void _ensureItemExists(int index) {
    if (index < 0) {
      throw StateError('Produk tidak ditemukan dalam keranjang.');
    }
  }
}
