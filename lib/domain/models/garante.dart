/// Vinculación de garantía social entre un deudor y un garante (RF-02).
class Garante {
  final int? id;
  final int deudorId;
  final int garanteClienteId; // ID del cliente que actúa como garante
  final String? relacion; // ej: "Familiar", "Vecino", "Compañero de trabajo"
  final int createdAt;

  const Garante({
    this.id,
    required this.deudorId,
    required this.garanteClienteId,
    this.relacion,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'deudor_id': deudorId,
      'garante_cliente_id': garanteClienteId,
      'relacion': relacion,
      'created_at': createdAt,
    };
  }

  factory Garante.fromMap(Map<String, dynamic> map) {
    return Garante(
      id: map['id'] as int?,
      deudorId: map['deudor_id'] as int,
      garanteClienteId: map['garante_cliente_id'] as int,
      relacion: map['relacion'] as String?,
      createdAt: map['created_at'] as int,
    );
  }
}
