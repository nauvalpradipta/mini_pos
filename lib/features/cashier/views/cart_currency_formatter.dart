String formatCartCurrency(int amount) {
  final isNegative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    buffer.write(digits[index]);

    final remaining = digits.length - index - 1;

    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
  }

  return '${isNegative ? '-Rp' : 'Rp'}$buffer';
}
