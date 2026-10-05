/// Representa una garantía física o prendaria asociada a un préstamo (RF-03).
class GarantiaPrendaria {
  final int? id;
  final int prestamoId;
  final String descripcion; // ej: "Tarjeta de débito Banco Unión", "Garrafa de gas"
  final String estado; // 'pendiente', 'devuelta'
  final int createdAt;
  final int updatedAt;

  const GarantiaPrendaria({
    this.id,
    required this.prestamoId,
    required this.descripcion,
    this.estado = 'pendiente',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDevuelta => estado == 'devuelta';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'prestamo_id': prestamoId,
      'descripcion': descripcion,
      'estado': estado,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory GarantiaPrendaria.fromMap(Map<String, dynamic> map) {
    return GarantiaPrendaria(
      id: map['id'] as int?,
      prestamoId: map['prestamo_id'] as int,
      descripcion: map['descripcion'] as String,
      estado: map['estado'] as String? ?? 'pendiente',
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
