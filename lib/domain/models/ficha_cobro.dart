import '../../core/domain/money.dart';
import 'tasa_interes.dart';
import 'tipo_modalidad_interes.dart';

/// Entidad que representa una Ficha de Cobro / Solicitud QR generada.
/// Modela la intención de cobro antes de que sea confirmada y asentada en el libro mayor.
class FichaCobro {
  final int? id;
  final int prestamoId;
  final String clienteNombre;
  final String clienteTelefono;
  final Money montoCapital;
  final Money montoInteres;
  final Money totalAPagar;
  final String estado; // 'pendiente', 'cobrada', 'anulada'
  final TasaInteres? tasa;
  final TipoModalidadInteres? modalidad;
  final bool tieneMora;
  final String? qrData;
  final String mensajeWhatsApp;
  final int fechaEmision;
  final int? fechaCobro;
  final int createdAt;
  final int updatedAt;

  const FichaCobro({
    this.id,
    required this.prestamoId,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.montoCapital,
    required this.montoInteres,
    required this.totalAPagar,
    this.estado = 'pendiente',
    this.tasa,
    this.modalidad,
    this.tieneMora = false,
    this.qrData,
    required this.mensajeWhatsApp,
    required this.fechaEmision,
    this.fechaCobro,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPendiente => estado == 'pendiente';
  bool get isCobrada => estado == 'cobrada';
  bool get isAnulada => estado == 'anulada';

  Money get saldoCapital => montoCapital;
  Money get saldoInteres => montoInteres;

  FichaCobro copyWith({
    int? id,
    int? prestamoId,
    String? clienteNombre,
    String? clienteTelefono,
    Money? montoCapital,
    Money? montoInteres,
    Money? totalAPagar,
    String? estado,
    TasaInteres? tasa,
    TipoModalidadInteres? modalidad,
    bool? tieneMora,
    String? qrData,
    String? mensajeWhatsApp,
    int? fechaEmision,
    int? fechaCobro,
    int? createdAt,
    int? updatedAt,
  }) {
    return FichaCobro(
      id: id ?? this.id,
      prestamoId: prestamoId ?? this.prestamoId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      montoCapital: montoCapital ?? this.montoCapital,
      montoInteres: montoInteres ?? this.montoInteres,
      totalAPagar: totalAPagar ?? this.totalAPagar,
      estado: estado ?? this.estado,
      tasa: tasa ?? this.tasa,
      modalidad: modalidad ?? this.modalidad,
      tieneMora: tieneMora ?? this.tieneMora,
      qrData: qrData ?? this.qrData,
      mensajeWhatsApp: mensajeWhatsApp ?? this.mensajeWhatsApp,
      fechaEmision: fechaEmision ?? this.fechaEmision,
      fechaCobro: fechaCobro ?? this.fechaCobro,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'prestamo_id': prestamoId,
      'cliente_nombre': clienteNombre,
      'cliente_telefono': clienteTelefono,
      'monto_capital_cents': montoCapital.cents,
      'monto_interes_cents': montoInteres.cents,
      'monto_total_cents': totalAPagar.cents,
      'estado': estado,
      'mensaje_whatsapp': mensajeWhatsApp,
      if (qrData != null) 'qr_data': qrData,
      'fecha_emision': fechaEmision,
      if (fechaCobro != null) 'fecha_cobro': fechaCobro,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory FichaCobro.fromMap(
    Map<String, dynamic> map, {
    TasaInteres? tasa,
    TipoModalidadInteres? modalidad,
    String? qrData,
  }) {
    final montoCap = Money.fromCents(map['monto_capital_cents'] as int);
    final montoInt = Money.fromCents(map['monto_interes_cents'] as int);
    final montoTot = Money.fromCents(map['monto_total_cents'] as int);

    return FichaCobro(
      id: map['id'] as int?,
      prestamoId: map['prestamo_id'] as int,
      clienteNombre: map['cliente_nombre'] as String,
      clienteTelefono: map['cliente_telefono'] as String,
      montoCapital: montoCap,
      montoInteres: montoInt,
      totalAPagar: montoTot,
      estado: map['estado'] as String,
      tasa: tasa,
      modalidad: modalidad,
      tieneMora: montoInt.isPositive,
      qrData: (map['qr_data'] as String?) ?? qrData,
      mensajeWhatsApp: map['mensaje_whatsapp'] as String,
      fechaEmision: map['fecha_emision'] as int,
      fechaCobro: map['fecha_cobro'] as int?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  @override
  String toString() =>
      'FichaCobro(ID: $id, Total: ${totalAPagar.formatBs()}, Estado: $estado)';
}
