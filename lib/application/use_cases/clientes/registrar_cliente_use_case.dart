import '../../../domain/models/cliente.dart';
import '../../../domain/models/contacto.dart';
import '../../../domain/repositories/cliente_repository.dart';

/// Caso de Uso: Registrar nuevo cliente en el sistema (CU-01 / RF-01).
class RegistrarClienteUseCase {
  final IClienteRepository clienteRepository;

  const RegistrarClienteUseCase(this.clienteRepository);

  Future<Cliente> execute({
    required String nombre,
    String? apellido,
    String? alias,
    String? ci,
    required String telefonoPrincipal,
    String? direccion,
    String? genero,
    int? fechaNacimiento,
    List<Contacto> contactosAdicionales = const [],
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
    for (final c in contactosAdicionales) {
      if (c.telefono.trim().length > 20) {
        throw ArgumentError('El teléfono secundario no puede superar los 20 caracteres.');
      }
      if (c.etiqueta != null && c.etiqueta!.trim().length > 30) {
        throw ArgumentError('La etiqueta del contacto no puede superar los 30 caracteres.');
      }
    }

    // Verificar si ya existe un cliente con el mismo teléfono para evitar duplicados
    final existentes = await clienteRepository.buscar(telefonoLimpio);
    for (final c in existentes) {
      if (c.telefonoPrincipal == telefonoLimpio &&
          c.nombre.toLowerCase() == nombreLimpio.toLowerCase()) {
        throw StateError(
          'Ya existe un cliente registrado con el mismo nombre y teléfono ("${c.nombreVisual}").',
        );
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final nuevoCliente = Cliente(
      nombre: nombreLimpio,
      apellido: apellido?.trim().isNotEmpty == true ? apellido!.trim() : null,
      alias: alias?.trim().isNotEmpty == true ? alias!.trim() : null,
      ci: ci?.trim().isNotEmpty == true ? ci!.trim() : null,
      telefonoPrincipal: telefonoLimpio,
      direccion: direccion?.trim().isNotEmpty == true ? direccion!.trim() : null,
      genero: genero?.trim().isNotEmpty == true ? genero!.trim() : null,
      fechaNacimiento: fechaNacimiento,
      contactos: contactosAdicionales,
      createdAt: now,
      updatedAt: now,
    );

    return await clienteRepository.crear(nuevoCliente);
  }
}
