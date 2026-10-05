/// Representa una cantidad monetaria exacta expresada en centavos enteros.
/// Evita problemas de precisión de punto flotante en cálculos financieros (Money Pattern).
class Money implements Comparable<Money> {
  final int cents;

  const Money.fromCents(this.cents);

  /// Construye a partir de bolivianos (ej: 4000.50 -> 400050 centavos).
  factory Money.fromBs(num bolivianos) {
    return Money.fromCents((bolivianos * 100).round());
  }

  static const Money zero = Money.fromCents(0);

  double toBs() => cents / 100.0;

  bool get isZero => cents == 0;
  bool get isPositive => cents > 0;
  bool get isNegative => cents < 0;

  Money operator +(Money other) => Money.fromCents(cents + other.cents);

  Money operator -(Money other) => Money.fromCents(cents - other.cents);

  Money operator *(num factor) => Money.fromCents((cents * factor).round());

  /// Aplica un porcentaje con redondeo al centavo más cercano.
  /// Ej: 4000 Bs * 20% -> 800 Bs.
  Money applyPercentage(double percentage) {
    return Money.fromCents(((cents * percentage) / 100.0).round());
  }

  bool operator <(Money other) => cents < other.cents;
  bool operator <=(Money other) => cents <= other.cents;
  bool operator >(Money other) => cents > other.cents;
  bool operator >=(Money other) => cents >= other.cents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money && runtimeType == other.runtimeType && cents == other.cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  /// Retorna formato legible en Bolivianos, ej: "Bs 4,000.00"
  String formatBs() {
    final isNeg = cents < 0;
    final absCents = cents.abs();
    final integerPart = absCents ~/ 100;
    final decimalPart = absCents % 100;

    final integerFormatted = _formatWithThousandSeparators(integerPart);
    final decimalFormatted = decimalPart.toString().padLeft(2, '0');

    final sign = isNeg ? '-' : '';
    return '$sign Bs $integerFormatted.$decimalFormatted';
  }

  static String _formatWithThousandSeparators(int number) {
    final str = number.toString();
    final result = StringBuffer();
    final length = str.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
    }
    return result.toString();
  }

  @override
  String toString() => formatBs();
}
