import '../../../domain/repositories/ficha_cobro_repository.dart';

/// Caso de Uso: Anular una Ficha de Cobro QR pendiente (RF-22).
class AnularFichaCobroUseCase {
  final IFichaCobroRepository fichaCobroRepository;

  const AnularFichaCobroUseCase(this.fichaCobroRepository);

  Future<void> execute(int fichaId) async {
    await fichaCobroRepository.actualizarEstado(fichaId, 'anulada');
  }
}
