import '../../core/domain/money.dart';

/// Mantiene la separación estructural e independiente entre el Saldo de Capital
/// y el Saldo de Interés Pendiente (RF-11).
class SaldoCuenta {
  final Money saldoCapital;
  final Money saldoInteres;

  SaldoCuenta({
    required this.saldoCapital,
    required this.saldoInteres,
  })  : assert(saldoCapital.cents >= 0, 'El saldo de capital no puede ser negativo'),
        assert(saldoInteres.cents >= 0, 'El saldo de interés no puede ser negativo');

  static final SaldoCuenta cero = SaldoCuenta(
    saldoCapital: Money.zero,
    saldoInteres: Money.zero,
  );

  /// Monto total exigible al cliente en este momento.
  Money get totalDeuda => saldoCapital + saldoInteres;

  /// Indica si la deuda fue saldada por completo.
  bool get isLiquidado => saldoCapital.isZero && saldoInteres.isZero;

  SaldoCuenta copyWith({
    Money? saldoCapital,
    Money? saldoInteres,
  }) {
    return SaldoCuenta(
      saldoCapital: saldoCapital ?? this.saldoCapital,
      saldoInteres: saldoInteres ?? this.saldoInteres,
    );
  }

  @override
  String toString() =>
      'SaldoCuenta(Capital: $saldoCapital, Interés: $saldoInteres, Total: $totalDeuda)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaldoCuenta &&
          runtimeType == other.runtimeType &&
          saldoCapital == other.saldoCapital &&
          saldoInteres == other.saldoInteres;

  @override
  int get hashCode => Object.hash(saldoCapital, saldoInteres);
}
