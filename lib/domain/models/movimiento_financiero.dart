import '../../core/domain/money.dart';
import 'tipo_movimiento.dart';

/// Registro inalterable del libro contable (Ledger) para un préstamo (RF-25).
class MovimientoFinanciero {
  final int? id;
  final int prestamoId;
  final int fecha; // Timestamp de la operación
  final TipoMovimiento tipo;
  final String detalle;
  final Money? debe;
  final Money? haber;
  final Money saldoCapitalResultante;
  final Money saldoInteresResultante;
  final int createdAt;

  const MovimientoFinanciero({
    this.id,
    required this.prestamoId,
    required this.fecha,
    required this.tipo,
    required this.detalle,
    this.debe,
    this.haber,
    required this.saldoCapitalResultante,
    required this.saldoInteresResultante,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'prestamo_id': prestamoId,
      'fecha': fecha,
      'tipo': tipo.name,
      'detalle': detalle,
      'debe_cents': debe?.cents,
      'haber_cents': haber?.cents,
      'saldo_capital_cents': saldoCapitalResultante.cents,
      'saldo_interes_cents': saldoInteresResultante.cents,
      'created_at': createdAt,
    };
  }

  factory MovimientoFinanciero.fromMap(Map<String, dynamic> map) {
    final debeCents = map['debe_cents'] as int?;
    final haberCents = map['haber_cents'] as int?;
    return MovimientoFinanciero(
      id: map['id'] as int?,
      prestamoId: map['prestamo_id'] as int,
      fecha: map['fecha'] as int,
      tipo: TipoMovimiento.values.byName(map['tipo'] as String),
      detalle: map['detalle'] as String,
      debe: debeCents != null ? Money.fromCents(debeCents) : null,
      haber: haberCents != null ? Money.fromCents(haberCents) : null,
      saldoCapitalResultante: Money.fromCents(map['saldo_capital_cents'] as int),
      saldoInteresResultante: Money.fromCents(map['saldo_interes_cents'] as int),
      createdAt: map['created_at'] as int,
    );
  }
}
