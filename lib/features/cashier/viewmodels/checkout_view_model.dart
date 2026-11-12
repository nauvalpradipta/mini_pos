import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/checkout.dart';
import '../repositories/transaction_repository.dart';

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel(this._transactionRepository);

  final TransactionRepository _transactionRepository;

  DiscountType _discountType = DiscountType.none;
  int _discountValue = 0;
  int _cashReceived = 0;

  bool _isSubmitting = false;
  String? _errorMessage;
  CheckoutResult? _result;

  // ---------------------------------------------------
  // GETTERS
  // ---------------------------------------------------

  DiscountType get discountType => _discountType;
  int get discountValue => _discountValue;
  int get cashReceived => _cashReceived;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  CheckoutResult? get result => _result;

  bool get hasResult => _result != null;

  // ---------------------------------------------------
  // DISCOUNT
  // ---------------------------------------------------

  void setDiscountType(DiscountType type) {
    if (_discountType == type) return;

    _discountType = type;

    if (type == DiscountType.none) {
      _discountValue = 0;
    }

    _clearError();
    notifyListeners();
  }

  void setDiscountValue(int value) {
    final normalizedValue = value < 0 ? 0 : value;

    if (_discountValue == normalizedValue) return;

    _discountValue = normalizedValue;

    _clearError();
    notifyListeners();
  }

  String? discountValidationMessage(int subtotal) {
    if (subtotal < 0) {
      return 'Subtotal tidak valid.';
    }

    if (_discountValue < 0) {
      return 'Nilai diskon tidak boleh negatif.';
    }

    switch (_discountType) {
      case DiscountType.none:
        if (_discountValue != 0) {
          return 'Nilai diskon harus nol jika tanpa diskon.';
        }
        break;

      case DiscountType.percentage:
        if (_discountValue > 100) {
          return 'Diskon persentase maksimal 100%.';
        }
        break;

      case DiscountType.fixed:
        if (_discountValue > subtotal) {
          return 'Diskon tidak boleh melebihi subtotal.';
        }
        break;
    }

    return null;
  }

  int discountAmountFor(int subtotal) {
    if (discountValidationMessage(subtotal) != null) {
      return 0;
    }

    switch (_discountType) {
      case DiscountType.none:
        return 0;

      case DiscountType.percentage:
        return (subtotal * _discountValue) ~/ 100;

      case DiscountType.fixed:
        return _discountValue;
    }
  }

  // ---------------------------------------------------
  // PAYMENT PREVIEW
  // ---------------------------------------------------

  int totalFor(int subtotal) {
    return subtotal - discountAmountFor(subtotal);
  }

  void setCashReceived(int amount) {
    final normalizedAmount = amount < 0 ? 0 : amount;

    if (_cashReceived == normalizedAmount) return;

    _cashReceived = normalizedAmount;

    _clearError();
    notifyListeners();
  }

  int changeFor(int subtotal) {
    final difference = _cashReceived - totalFor(subtotal);

    return difference > 0 ? difference : 0;
  }

  int shortfallFor(int subtotal) {
    final difference = totalFor(subtotal) - _cashReceived;

    return difference > 0 ? difference : 0;
  }

  bool canSubmit({
    required int subtotal,
    required bool hasItems,
    required bool hasCashier,
  }) {
    return hasItems &&
        hasCashier &&
        !_isSubmitting &&
        discountValidationMessage(subtotal) == null &&
        _cashReceived >= totalFor(subtotal);
  }

  // ---------------------------------------------------
  // SUBMIT CHECKOUT
  // ---------------------------------------------------

  Future<CheckoutResult?> submit({
    required int cashierId,
    required List<CartItem> cartItems,
  }) async {
    if (_isSubmitting) return null;

    if (cartItems.isEmpty) {
      _setError('Keranjang masih kosong.');
      return null;
    }

    if (cashierId <= 0) {
      _setError('Sesi kasir tidak valid. Silakan login kembali.');
      return null;
    }

    final subtotal = cartItems.fold<int>(
      0,
      (total, item) => total + item.lineTotal,
    );

    final discountError = discountValidationMessage(subtotal);

    if (discountError != null) {
      _setError(discountError);
      return null;
    }

    final total = totalFor(subtotal);

    if (_cashReceived < total) {
      _setError(
        'Uang pembayaran kurang. '
        'Kurang Rp${total - _cashReceived}.',
      );
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _transactionRepository.checkout(
        CheckoutRequest(
          cashierId: cashierId,
          cartItems: cartItems,
          discountType: _discountType,
          discountValue: _discountValue,
          cashReceived: _cashReceived,
        ),
      );

      _result = result;

      return result;
    } on CheckoutException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'Transaksi gagal. Silakan coba lagi.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------
  // RESET
  // ---------------------------------------------------

  void reset() {
    if (_isSubmitting) return;

    _discountType = DiscountType.none;
    _discountValue = 0;
    _cashReceived = 0;

    _errorMessage = null;
    _result = null;

    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
