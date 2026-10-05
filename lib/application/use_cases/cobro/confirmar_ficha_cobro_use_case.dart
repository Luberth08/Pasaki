import '../../../core/domain/money.dart';
import '../../../domain/repositories/ficha_cobro_repository.dart';
import '../pagos/registrar_pago_use_case.dart';

/// Caso de Uso: Confirmar el pago de una Ficha de Cobro QR y asentarla en el libro contable de forma atómica.
class ConfirmarFichaCobroUseCase {
  final IFichaCobroRepository fichaCobroRepository;
  final RegistrarPagoUseCase registrarPagoUseCase;

  const ConfirmarFichaCobroUseCase({
    required this.fichaCobroRepository,
    required this.registrarPagoUseCase,
  });

  Future<void> execute({
    required int fichaId,
    Money? montoRealCapital,
    Money? montoRealInteres,
  }) async {
    final ficha = await fichaCobroRepository.obtenerPorId(fichaId);
    if (ficha == null) {
      throw StateError('La ficha de cobro con ID $fichaId no existe.');
    }
    if (!ficha.isPendiente) {
      throw StateError('La ficha ya fue ${ficha.estado}.');
    }

    final cap = montoRealCapital ?? ficha.montoCapital;
    final inte = montoRealInteres ?? ficha.montoInteres;
    final total = cap + inte;

    if (!total.isPositive) {
      throw ArgumentError('El monto a asentar debe ser mayor a cero.');
    }

    await registrarPagoUseCase.execute(
      prestamoId: ficha.prestamoId,
      montoPagado: total,
      montoACapital: cap,
      montoAInteres: inte,
      detalle: 'Cobro QR confirmado (Ficha #${ficha.id})',
    );

    await fichaCobroRepository.actualizarEstado(
      fichaId,
      'cobrada',
      fechaCobro: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
