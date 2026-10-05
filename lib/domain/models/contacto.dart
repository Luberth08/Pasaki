/// Representa un número de contacto secundario asociado a un cliente.
class Contacto {
  final int? id;
  final int clienteId;
  final String telefono;
  final String? etiqueta; // ej: "Esposa", "Hermano", "Taller", "Referencia"
  final int createdAt;
  final int updatedAt;

  const Contacto({
    this.id,
    required this.clienteId,
    required this.telefono,
    this.etiqueta,
    required this.createdAt,
    required this.updatedAt,
  });

  Contacto copyWith({
    int? id,
    int? clienteId,
    String? telefono,
    String? etiqueta,
    int? createdAt,
    int? updatedAt,
  }) {
    return Contacto(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      telefono: telefono ?? this.telefono,
      etiqueta: etiqueta ?? this.etiqueta,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'telefono': telefono,
      'etiqueta': etiqueta,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Contacto.fromMap(Map<String, dynamic> map) {
    return Contacto(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int,
      telefono: map['telefono'] as String,
      etiqueta: map['etiqueta'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  @override
  String toString() => 'Contacto(id: $id, tel: $telefono, etiqueta: $etiqueta)';
}
