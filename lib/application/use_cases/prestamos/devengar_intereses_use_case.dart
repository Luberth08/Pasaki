import '../../../domain/models/saldo_cuenta.dart';
import '../../../domain/repositories/prestamo_repository.dart';
import '../../../domain/services/motor_financiero.dart';

/// Caso de Uso: Devengar intereses periódicos en un préstamo activo (RF-12, RF-14).
class DevengarInteresesUseCase {
  final IPrestamoRepository prestamoRepository;
  final MotorFinanciero motorFinanciero;

  const DevengarInteresesUseCase({
    required this.prestamoRepository,
    this.motorFinanciero = const MotorFinanciero(),
  });

  Future<SaldoCuenta> execute({
    required int prestamoId,
    int? diasTranscurridos,
    String? detalle,
    int? fecha,
    List<TramoDesembolso>? tramosProrrateo,
  }) async {
    final prestamo = await prestamoRepository.obtenerPorId(prestamoId);
    if (prestamo == null) {
      throw StateError('El préstamo con ID $prestamoId no existe.');
    }
    if (!prestamo.isActivo) {
      throw StateError('No se pueden devengar intereses en un préstamo ${prestamo.estado}.');
    }

    final nuevoSaldo = motorFinanciero.devengarInteresPeriodo(
      saldoActual: prestamo.saldoActual,
      tasa: prestamo.tasa,
      modalidad: prestamo.modalidad,
      diasTranscurridos: diasTranscurridos,
      prorratear: prestamo.prorratearInteres,
      tramosProrrateo: tramosProrrateo,
    );

    final fechaOperacion = fecha ?? DateTime.now().millisecondsSinceEpoch;
    final glosa = detalle ??
        'Cierre de período (${prestamo.tasa.porcentaje}% ${prestamo.tasa.periodo.etiqueta.toLowerCase()})';

    await prestamoRepository.registrarDevengamientoTransaccional(
      prestamoId: prestamoId,
      nuevoSaldo: nuevoSaldo,
      detalle: glosa,
      fecha: fechaOperacion,
    );

    return nuevoSaldo;
  }
}
