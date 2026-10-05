import '../../core/domain/money.dart';
import 'garantia_prendaria.dart';
import 'movimiento_financiero.dart';
import 'periodo_tasa.dart';
import 'saldo_cuenta.dart';
import 'tasa_interes.dart';
import 'tipo_modalidad_interes.dart';

/// Entidad central de un préstamo otorgado a un cliente.
class Prestamo {
  final int? id;
  final int clienteId;
  final Money capitalInicial;
  final TasaInteres tasa;
  final TipoModalidadInteres modalidad;
  final SaldoCuenta saldoActual;
  final String estado; // 'activo', 'liquidado', 'congelado'
  final bool prorratearInteres;
  final int fechaInicio;
  final int? fechaPrimerCorte;
  final List<MovimientoFinanciero> movimientos;
  final List<GarantiaPrendaria> garantias;
  final int createdAt;
  final int updatedAt;

  const Prestamo({
    this.id,
    required this.clienteId,
    required this.capitalInicial,
    required this.tasa,
    required this.modalidad,
    required this.saldoActual,
    this.estado = 'activo',
    this.prorratearInteres = false,
    required this.fechaInicio,
    this.fechaPrimerCorte,
    this.movimientos = const [],
    this.garantias = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActivo => estado == 'activo';
  bool get isLiquidado => estado == 'liquidado' || saldoActual.isLiquidado;
  bool get isCongelado => estado == 'congelado';

  Prestamo copyWith({
    int? id,
    int? clienteId,
    Money? capitalInicial,
    TasaInteres? tasa,
    TipoModalidadInteres? modalidad,
    SaldoCuenta? saldoActual,
    String? estado,
    bool? prorratearInteres,
    int? fechaInicio,
    int? fechaPrimerCorte,
    List<MovimientoFinanciero>? movimientos,
    List<GarantiaPrendaria>? garantias,
    int? createdAt,
    int? updatedAt,
  }) {
    return Prestamo(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      capitalInicial: capitalInicial ?? this.capitalInicial,
      tasa: tasa ?? this.tasa,
      modalidad: modalidad ?? this.modalidad,
      saldoActual: saldoActual ?? this.saldoActual,
      estado: estado ?? this.estado,
      prorratearInteres: prorratearInteres ?? this.prorratearInteres,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaPrimerCorte: fechaPrimerCorte ?? this.fechaPrimerCorte,
      movimientos: movimientos ?? this.movimientos,
      garantias: garantias ?? this.garantias,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'capital_inicial_cents': capitalInicial.cents,
      'tasa_porcentaje': tasa.porcentaje,
      'tasa_periodo': tasa.periodo.name,
      'modalidad': modalidad.name,
      'saldo_capital_cents': saldoActual.saldoCapital.cents,
      'saldo_interes_cents': saldoActual.saldoInteres.cents,
      'estado': estado,
      'prorratear_interes': prorratearInteres ? 1 : 0,
      'fecha_inicio': fechaInicio,
      if (fechaPrimerCorte != null) 'fecha_primer_corte': fechaPrimerCorte,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Prestamo.fromMap(
    Map<String, dynamic> map, {
    List<MovimientoFinanciero> movimientos = const [],
    List<GarantiaPrendaria> garantias = const [],
  }) {
    return Prestamo(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int,
      capitalInicial: Money.fromCents(map['capital_inicial_cents'] as int),
      tasa: TasaInteres(
        porcentaje: (map['tasa_porcentaje'] as num).toDouble(),
        periodo: PeriodoTasa.values.byName(map['tasa_periodo'] as String),
      ),
      modalidad: TipoModalidadInteres.values.byName(map['modalidad'] as String),
      saldoActual: SaldoCuenta(
        saldoCapital: Money.fromCents(map['saldo_capital_cents'] as int),
        saldoInteres: Money.fromCents(map['saldo_interes_cents'] as int),
      ),
      estado: map['estado'] as String,
      prorratearInteres: (map['prorratear_interes'] as int? ?? 0) == 1,
      fechaInicio: map['fecha_inicio'] as int,
      fechaPrimerCorte: map['fecha_primer_corte'] as int?,
      movimientos: movimientos,
      garantias: garantias,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
