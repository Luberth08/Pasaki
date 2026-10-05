import '../../core/domain/money.dart';
import 'periodo_tasa.dart';

/// Representa la tasa de interés pactada para una periodicidad dada.
class TasaInteres {
  final double porcentaje; // ej: 20.0 para 20%
  final PeriodoTasa periodo;

  const TasaInteres({
    required this.porcentaje,
    this.periodo = PeriodoTasa.mensual,
  }) : assert(porcentaje >= 0, 'La tasa de interés no puede ser negativa');

  /// Tasa estándar predeterminada en el microcrédito cruceño: 20% mensual.
  static const TasaInteres estandarDefecto = TasaInteres(
    porcentaje: 20.0,
    periodo: PeriodoTasa.mensual,
  );

  /// Retorna el porcentaje equivalente en base mensual.
  double get porcentajeMensualEquivalente {
    switch (periodo) {
      case PeriodoTasa.diario:
        return porcentaje * 30.0;
      case PeriodoTasa.semanal:
        return porcentaje * 4.0;
      case PeriodoTasa.quincenal:
        return porcentaje * 2.0;
      case PeriodoTasa.mensual:
        return porcentaje;
      case PeriodoTasa.anual:
        return porcentaje / 12.0;
    }
  }

  /// Calcula el interés generado por un capital dado en un período.
  Money calcularInteresPeriodo(Money capitalBase) {
    return capitalBase.applyPercentage(porcentaje);
  }

  @override
  String toString() => '$porcentaje% ${periodo.etiqueta.toLowerCase()}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TasaInteres &&
          runtimeType == other.runtimeType &&
          porcentaje == other.porcentaje &&
          periodo == other.periodo;

  @override
  int get hashCode => Object.hash(porcentaje, periodo);
}
