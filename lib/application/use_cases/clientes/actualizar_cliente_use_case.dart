import '../../../domain/models/cliente.dart';
import '../../../domain/models/contacto.dart';
import '../../../domain/repositories/cliente_repository.dart';

/// Caso de Uso: Actualizar información personal y contactos de un cliente existente (CU-01 / RF-01).
class ActualizarClienteUseCase {
  final IClienteRepository clienteRepository;

  const ActualizarClienteUseCase(this.clienteRepository);

  Future<Cliente> execute({
    required int id,
    required String nombre,
    String? apellido,
    String? alias,
    String? ci,
    required String telefonoPrincipal,
    String? direccion,
    String? genero,
    int? fechaNacimiento,
    bool esListaNegra = false,
    List<Contacto> contactos = const [],
  }) async {
    final nombreLimpio = nombre.trim();
    final telefonoLimpio = telefonoPrincipal.trim();

    if (nombreLimpio.isEmpty) {
      throw ArgumentError('El nombre del cliente es obligatorio.');
    }
    if (nombreLimpio.length > 50) {
      throw ArgumentError('El nombre no puede superar los 50 caracteres.');
    }
    if (apellido != null && apellido.trim().length > 50) {
      throw ArgumentError('El apellido no puede superar los 50 caracteres.');
    }
    if (alias != null && alias.trim().length > 40) {
      throw ArgumentError('El alias no puede superar los 40 caracteres.');
    }
    if (ci != null && ci.trim().length > 20) {
      throw ArgumentError('La cédula de identidad no puede superar los 20 caracteres.');
    }
    if (telefonoLimpio.isEmpty) {
      throw ArgumentError('El teléfono principal es obligatorio para cobros.');
    }
    if (telefonoLimpio.length > 20) {
      throw ArgumentError('El teléfono principal no puede superar los 20 caracteres.');
    }
    if (direccion != null && direccion.trim().length > 120) {
      throw ArgumentError('La dirección no puede superar los 120 caracteres.');
    }
    for (final c in contactos) {
      if (c.telefono.trim().length > 20) {
        throw ArgumentError('El teléfono secundario no puede superar los 20 caracteres.');
      }
      if (c.etiqueta != null && c.etiqueta!.trim().length > 30) {
        throw ArgumentError('La etiqueta del contacto no puede superar los 30 caracteres.');
      }
    }

    final clienteActual = await clienteRepository.obtenerPorId(id);
    if (clienteActual == null) {
      throw StateError('El cliente con ID $id no existe.');
    }

    // Validar colisión de teléfono principal con otro cliente diferente
    final existentes = await clienteRepository.buscar(telefonoLimpio);
    for (final c in existentes) {
      if (c.id != id &&
          c.telefonoPrincipal == telefonoLimpio &&
          c.nombre.toLowerCase() == nombreLimpio.toLowerCase()) {
        throw StateError(
          'Ya existe otro cliente registrado con el mismo nombre y teléfono ("${c.nombreVisual}").',
        );
      }
    }

    final clienteActualizado = clienteActual.copyWith(
      nombre: nombreLimpio,
      apellido: apellido?.trim().isNotEmpty == true ? apellido!.trim() : null,
      alias: alias?.trim().isNotEmpty == true ? alias!.trim() : null,
      ci: ci?.trim().isNotEmpty == true ? ci!.trim() : null,
      telefonoPrincipal: telefonoLimpio,
      direccion: direccion?.trim().isNotEmpty == true ? direccion!.trim() : null,
      genero: genero?.trim().isNotEmpty == true ? genero!.trim() : null,
      fechaNacimiento: fechaNacimiento,
      esListaNegra: esListaNegra,
      contactos: contactos,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await clienteRepository.actualizar(clienteActualizado);
    return clienteActualizado;
  }
}
