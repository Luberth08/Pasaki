import '../../core/domain/money.dart';
import 'contacto.dart';

/// Entidad central del deudor o cliente en el dominio.
class Cliente {
  final int? id;
  final String nombre; // Obligatorio
  final String? apellido;
  final String? alias; // Apodo o referencia cotidiana ("Don René el mecánico")
  final String? ci; // Cédula de identidad (opcional)
  final String telefonoPrincipal; // Obligatorio (WhatsApp / Contacto principal)
  final String? direccion;
  final String? genero;
  final int? fechaNacimiento;
  final Money? ingresoMensual;
  final bool esListaNegra; // Bloqueo preventivo (RF-04)
  final List<Contacto> contactos;
  final int createdAt;
  final int updatedAt;

  const Cliente({
    this.id,
    required this.nombre,
    this.apellido,
    this.alias,
    this.ci,
    required this.telefonoPrincipal,
    this.direccion,
    this.genero,
    this.fechaNacimiento,
    this.ingresoMensual,
    this.esListaNegra = false,
    this.contactos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  String get nombreCompleto =>
      apellido != null && apellido!.isNotEmpty ? '$nombre $apellido' : nombre;

  /// Nombre preferido para mostrar en fichas y listas
  String get nombreVisual =>
      alias != null && alias!.isNotEmpty ? '$nombreCompleto ("$alias")' : nombreCompleto;

  Cliente copyWith({
    int? id,
    String? nombre,
    String? apellido,
    String? alias,
    String? ci,
    String? telefonoPrincipal,
    String? direccion,
    String? genero,
    int? fechaNacimiento,
    Money? ingresoMensual,
    bool? esListaNegra,
    List<Contacto>? contactos,
    int? createdAt,
    int? updatedAt,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      alias: alias ?? this.alias,
      ci: ci ?? this.ci,
      telefonoPrincipal: telefonoPrincipal ?? this.telefonoPrincipal,
      direccion: direccion ?? this.direccion,
      genero: genero ?? this.genero,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      ingresoMensual: ingresoMensual ?? this.ingresoMensual,
      esListaNegra: esListaNegra ?? this.esListaNegra,
      contactos: contactos ?? this.contactos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'alias': alias,
      'ci': ci,
      'telefono_principal': telefonoPrincipal,
      'direccion': direccion,
      'genero': genero,
      'fecha_nacimiento': fechaNacimiento,
      'ingreso_mensual_cents': ingresoMensual?.cents,
      'es_lista_negra': esListaNegra ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map, {List<Contacto> contactos = const []}) {
    final ingresoCents = map['ingreso_mensual_cents'] as int?;
    return Cliente(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      apellido: map['apellido'] as String?,
      alias: map['alias'] as String?,
      ci: map['ci'] as String?,
      telefonoPrincipal: map['telefono_principal'] as String,
      direccion: map['direccion'] as String?,
      genero: map['genero'] as String?,
      fechaNacimiento: map['fecha_nacimiento'] as int?,
      ingresoMensual: ingresoCents != null ? Money.fromCents(ingresoCents) : null,
      esListaNegra: (map['es_lista_negra'] as int? ?? 0) == 1,
      contactos: contactos,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  @override
  String toString() => 'Cliente(id: $id, nombre: $nombreVisual, tel: $telefonoPrincipal)';
}
