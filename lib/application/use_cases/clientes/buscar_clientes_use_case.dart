import '../../../domain/models/cliente.dart';
import '../../../domain/repositories/cliente_repository.dart';

/// Caso de Uso: Búsqueda y filtrado de clientes (CU-01 / RF-27).
class BuscarClientesUseCase {
  final IClienteRepository clienteRepository;

  const BuscarClientesUseCase(this.clienteRepository);

  Future<List<Cliente>> execute([String query = '']) async {
    final termino = query.trim();
    if (termino.isEmpty) {
      return await clienteRepository.obtenerTodos();
    }
    return await clienteRepository.buscar(termino);
  }
}
