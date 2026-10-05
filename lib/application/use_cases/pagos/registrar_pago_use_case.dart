import '../../../core/domain/money.dart';
import '../../../domain/models/distribucion_pago.dart';
import '../../../domain/repositories/prestamo_repository.dart';
import '../../../domain/services/motor_financiero.dart';

/// Caso de Uso: Registrar pago y aplicar imputación automática o manual (CU-06 / RF-11, RF-16).
class RegistrarPagoUseCase {
  final IPrestamoRepository prestamoRepository;
  final MotorFinanciero motorFinanciero;

  const RegistrarPagoUseCase({
    required this.prestamoRepository,
    this.motorFinanciero = const MotorFinanciero(),
  });

  Future<DistribucionPago> execute({
    required int prestamoId,
    required Money montoPagado,
    Money? montoACapital,
    Money? montoAInteres,
    String? detalle,
    int? fecha,
  }) async {
    if (!montoPagado.isPositive) {
      throw ArgumentError('El monto pagado debe ser mayor a cero.');
    }

    final prestamo = await prestamoRepository.obtenerPorId(prestamoId);
    if (prestamo == null) {
      throw StateError('El préstamo con ID $prestamoId no existe.');
    }
    if (prestamo.saldoActual.isLiquidado) {
      throw StateError('El préstamo ya se encuentra completamente liquidado.');
    }

    DistribucionPago distribucion;

    // Si se especificó distribución manual (RF-16)
    if (montoACapital != null && montoAInteres != null) {
      if (montoACapital + montoAInteres != montoPagado) {
        throw ArgumentError(
          'La suma de monto a capital ($montoACapital) y monto a interés ($montoAInteres) debe igualar el total ($montoPagado).',
        );
      }
      distribucion = motorFinanciero.imputarPagoManual(
        saldoActual: prestamo.saldoActual,
        montoACapital: montoACapital,
        montoAInteres: montoAInteres,
      );
    } else {
      // Cascada estándar automática
      distribucion = motorFinanciero.imputarPagoAutomatico(
        saldoActual: prestamo.saldoActual,
        montoPagado: montoPagado,
      );
    }

    final fechaOperacion = fecha ?? DateTime.now().millisecondsSinceEpoch;
    final glosa = detalle ??
        'Pago recibido (Interés: ${distribucion.abonadoAInteres.formatBs()}, Capital: ${distribucion.abonadoACapital.formatBs()})';

    await prestamoRepository.registrarPagoTransaccional(
      prestamoId: prestamoId,
      distribucion: distribucion,
      detalle: glosa,
      fecha: fechaOperacion,
    );

    return distribucion;
  }
}
