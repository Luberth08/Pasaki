import '../../core/domain/money.dart';
import 'saldo_cuenta.dart';

/// Resultado detallado de la imputación o distribución de un pago realizado.
class DistribucionPago {
  final Money montoTotalPagado;
  final Money abonadoAInteres;
  final Money abonadoACapital;
  final SaldoCuenta nuevoSaldo;
  final Money excedente; // Si pagó de más respecto al total adeudado

  const DistribucionPago({
    required this.montoTotalPagado,
    required this.abonadoAInteres,
    required this.abonadoACapital,
    required this.nuevoSaldo,
    this.excedente = Money.zero,
  });

  @override
  String toString() =>
      'DistribucionPago(Total: $montoTotalPagado, A Interés: $abonadoAInteres, A Capital: $abonadoACapital, Excedente: $excedente, NuevoSaldo: $nuevoSaldo)';
}
