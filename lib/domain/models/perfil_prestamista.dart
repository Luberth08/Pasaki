/// Modelo de Dominio para el Perfil del Prestamista / Titular de la cuenta.
/// Centraliza la información bancaria y el código QR de cobro.
class PerfilPrestamista {
  final int id;
  final String nombreTitular;
  final String? banco;
  final String? numeroCuenta;
  final String? qrImageBase64;
  final int updatedAt;

  const PerfilPrestamista({
    this.id = 1,
    required this.nombreTitular,
    this.banco,
    this.numeroCuenta,
    this.qrImageBase64,
    required this.updatedAt,
  });

  bool get tieneQr => qrImageBase64 != null && qrImageBase64!.trim().isNotEmpty;

  PerfilPrestamista copyWith({
    int? id,
    String? nombreTitular,
    String? banco,
    String? numeroCuenta,
    String? qrImageBase64,
    int? updatedAt,
  }) {
    return PerfilPrestamista(
      id: id ?? this.id,
      nombreTitular: nombreTitular ?? this.nombreTitular,
      banco: banco ?? this.banco,
      numeroCuenta: numeroCuenta ?? this.numeroCuenta,
      qrImageBase64: qrImageBase64 ?? this.qrImageBase64,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre_titular': nombreTitular,
      'banco': banco,
      'numero_cuenta': numeroCuenta,
      'qr_image_base64': qrImageBase64,
      'updated_at': updatedAt,
    };
  }

  factory PerfilPrestamista.fromMap(Map<String, dynamic> map) {
    return PerfilPrestamista(
      id: map['id'] as int? ?? 1,
      nombreTitular: map['nombre_titular'] as String? ?? '',
      banco: map['banco'] as String?,
      numeroCuenta: map['numero_cuenta'] as String?,
      qrImageBase64: map['qr_image_base64'] as String?,
      updatedAt: map['updated_at'] as int? ?? 0,
    );
  }
}
