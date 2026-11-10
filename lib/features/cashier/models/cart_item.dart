class CartItemAddon {
  CartItemAddon({
    required this.addonId,
    required this.addonName,
    required this.additionalPrice,
    required this.quantityPerProduct,
  }) {
    if (addonId <= 0) {
      throw ArgumentError('ID add-on tidak valid.');
    }

    if (addonName.trim().isEmpty) {
      throw ArgumentError('Nama add-on tidak boleh kosong.');
    }

    if (additionalPrice < 0) {
      throw ArgumentError('Harga add-on tidak boleh negatif.');
    }

    if (quantityPerProduct <= 0) {
      throw ArgumentError('Jumlah add-on harus lebih dari nol.');
    }
  }

  final int addonId;
  final String addonName;
  final int additionalPrice;

  // Jumlah add-on yang digunakan untuk setiap satu produk.
  final int quantityPerProduct;
}

class CartItem {
  CartItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    List<CartItemAddon> addons = const [],
  }) : addons = List.unmodifiable(addons) {
    if (productId <= 0) {
      throw ArgumentError('ID produk tidak valid.');
    }

    if (productName.trim().isEmpty) {
      throw ArgumentError('Nama produk tidak boleh kosong.');
    }

    if (unitPrice < 0) {
      throw ArgumentError('Harga produk tidak boleh negatif.');
    }

    if (quantity <= 0) {
      throw ArgumentError('Jumlah produk harus lebih dari nol.');
    }

    final addonIds = addons.map((addon) => addon.addonId).toSet();

    if (addonIds.length != addons.length) {
      throw ArgumentError('Add-on yang sama tidak boleh dimasukkan dua kali.');
    }
  }

  final int productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final List<CartItemAddon> addons;

  // Total harga produk tanpa add-on.
  int get productSubtotal => unitPrice * quantity;

  // Total harga seluruh add-on untuk satu baris keranjang.
  int get addonsSubtotal {
    return addons.fold(
      0,
      (total, addon) =>
          total + (addon.additionalPrice * addon.quantityPerProduct * quantity),
    );
  }

  // Total harga produk beserta add-on.
  int get lineTotal => productSubtotal + addonsSubtotal;
}
