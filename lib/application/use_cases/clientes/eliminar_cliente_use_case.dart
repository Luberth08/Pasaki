import '../../../domain/repositories/cliente_repository.dart';
import '../../../domain/repositories/prestamo_repository.dart';

/// Caso de Uso: Eliminar cliente físicamente solo si no tiene préstamos vinculados (CU-01 / Integridad Contable).
class EliminarClienteUseCase {
  final IClienteRepository clienteRepository;
  final IPrestamoRepository prestamoRepository;

  const EliminarClienteUseCase({
    required this.clienteRepository,
    required this.prestamoRepository,
  });

  Future<void> execute(int clienteId) async {
    // 1. Verificar si tiene préstamos asociados en el historial contable
    final prestamos = await prestamoRepository.obtenerPorCliente(clienteId);
    if (prestamos.isNotEmpty) {
      throw StateError(
        'No es posible eliminar el cliente porque tiene préstamos registrados en su historial.',
      );
    }

    // 2. Borrado físico (los contactos se eliminan en cascada por ON DELETE CASCADE en SQLite)
    await clienteRepository.eliminar(clienteId);
  }
}
