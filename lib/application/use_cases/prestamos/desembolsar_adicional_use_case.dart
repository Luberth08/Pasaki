import '../../../core/domain/money.dart';
import '../../../domain/repositories/prestamo_repository.dart';

/// Caso de Uso: Registrar un desembolso adicional a un préstamo activo (RF-13).
/// Suma el nuevo capital a la deuda consolidada del cliente y asienta el movimiento en el libro mayor.
class DesembolsarAdicionalUseCase {
  final IPrestamoRepository prestamoRepository;

  const DesembolsarAdicionalUseCase(this.prestamoRepository);

  Future<void> execute({
    required int prestamoId,
    required Money monto,
    DateTime? fecha,
    String? nota,
  }) async {
    if (monto.isNegative || monto.isZero) {
      throw ArgumentError('El monto a desembolsar debe ser mayor a 0 Bs.');
    }

    final prestamo = await prestamoRepository.obtenerPorId(prestamoId);
    if (prestamo == null) {
      throw StateError('El préstamo con ID $prestamoId no existe.');
    }

    if (!prestamo.isActivo) {
      throw StateError('No se pueden realizar desembolsos en un préstamo ${prestamo.estado}.');
    }

    final fechaOperacion = (fecha ?? DateTime.now()).millisecondsSinceEpoch;
    final detalle = (nota != null && nota.trim().isNotEmpty)
        ? nota.trim()
        : 'Desembolso adicional de capital';

    await prestamoRepository.registrarDesembolsoAdicionalTransaccional(
      prestamoId: prestamoId,
      montoAdicional: monto,
      detalle: detalle,
      fecha: fechaOperacion,
    );
  }
}
