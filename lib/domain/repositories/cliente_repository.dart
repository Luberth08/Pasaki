import '../models/cliente.dart';
import '../models/contacto.dart';

abstract class IClienteRepository {
  Future<Cliente> crear(Cliente cliente);
  Future<void> actualizar(Cliente cliente);
  Future<Cliente?> obtenerPorId(int id);
  Future<List<Cliente>> obtenerTodos();
  Future<List<Cliente>> buscar(String query);
  Future<void> eliminar(int id);

  Future<Contacto> agregarContacto(Contacto contacto);
  Future<void> eliminarContacto(int contactoId);
}
