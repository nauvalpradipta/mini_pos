import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../products/models/addon.dart';
import '../../products/models/product.dart';
import '../models/cart_item.dart';

class CartViewModel extends ChangeNotifier {
  final List<CartItem> _items = [];

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

    if (existingIndex >= 0) {
      final existing = _items[existingIndex];

      _items[existingIndex] = _copyWithQuantity(
        existing,
        existing.quantity + 1,
      );
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

    final currentItem = _items[index];

    _items[index] = _copyWithQuantity(currentItem, currentItem.quantity + 1);

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

    _items[index] = _copyWithQuantity(_items[index], quantity);

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

  void _ensureItemExists(int index) {
    if (index < 0) {
      throw StateError('Produk tidak ditemukan dalam keranjang.');
    }
  }
}
