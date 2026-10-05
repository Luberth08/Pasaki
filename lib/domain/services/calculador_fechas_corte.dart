import 'dart:math';
import '../models/periodo_tasa.dart';

/// Servicio de dominio para el cálculo de fechas de corte y devengamiento de préstamos.
/// Resuelve de forma determinista la convención de días fijos, quincenas y fin de mes.
class CalculadorFechasCorte {
  const CalculadorFechasCorte._();

  /// Retorna la cantidad de días en un mes específico (considera años bisiestos).
  static int diasEnMes(int anio, int mes) {
    return DateTime(anio, mes + 1, 0).day;
  }

  /// Calcula la fecha en la que debe realizarse el PRIMER corte/cobro del préstamo.
  ///
  /// - [fechaDesembolso]: Fecha en que se entrega el dinero.
  /// - [periodo]: Frecuencia de la tasa (diario, semanal, quincenal, mensual, anual).
  /// - [diaSemanaDeseado]: Para semanal (1 = Lunes, ..., 7 = Domingo). Por defecto el de la fecha de desembolso.
  /// - [diaMesDeseado]: Para mensual (1 al 31). Por defecto el día de la fecha de desembolso.
  static DateTime calcularPrimerCorte({
    required DateTime fechaDesembolso,
    required PeriodoTasa periodo,
    int? diaSemanaDeseado,
    int? diaMesDeseado,
    int? mesAnualDeseado,
  }) {
    final base = DateTime(
      fechaDesembolso.year,
      fechaDesembolso.month,
      fechaDesembolso.day,
    );

    switch (periodo) {
      case PeriodoTasa.diario:
        return base.add(const Duration(days: 1));

      case PeriodoTasa.semanal:
        final diaTarget = diaSemanaDeseado ?? base.weekday;
        int diasHasta = (diaTarget - base.weekday) % 7;
        if (diasHasta <= 0) diasHasta += 7;
        return base.add(Duration(days: diasHasta));

      case PeriodoTasa.quincenal:
        // Esquema clásico fijo: Días 15 y Fin de Mes
        if (base.day < 15) {
          return DateTime(base.year, base.month, 15);
        } else {
          final ultimoDiaMes = diasEnMes(base.year, base.month);
          if (base.day < ultimoDiaMes) {
            return DateTime(base.year, base.month, ultimoDiaMes);
          } else {
            // Desembolsó el último día del mes -> primer corte el 15 del mes siguiente
            int nextMonth = base.month + 1;
            int nextYear = base.year;
            if (nextMonth > 12) {
              nextMonth = 1;
              nextYear++;
            }
            return DateTime(nextYear, nextMonth, 15);
          }
        }

      case PeriodoTasa.mensual:
        final diaTarget = diaMesDeseado ?? base.day;
        if (diaTarget > base.day) {
          // El corte cae en el mes en curso
          final maxDiasMesActual = diasEnMes(base.year, base.month);
          final diaAjustado = min(diaTarget, maxDiasMesActual);
          return DateTime(base.year, base.month, diaAjustado);
        } else {
          // El corte cae en el mes siguiente
          int nextMonth = base.month + 1;
          int nextYear = base.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          final maxDiasMesSig = diasEnMes(nextYear, nextMonth);
          final diaAjustado = min(diaTarget, maxDiasMesSig);
          return DateTime(nextYear, nextMonth, diaAjustado);
        }

      case PeriodoTasa.anual:
        final mesTarget = mesAnualDeseado ?? base.month;
        final diaTarget = diaMesDeseado ?? base.day;
        final maxDiasEsteAnio = diasEnMes(base.year, mesTarget);
        final fechaEsteAnio = DateTime(base.year, mesTarget, min(diaTarget, maxDiasEsteAnio));

        if (fechaEsteAnio.isAfter(base)) {
          return fechaEsteAnio;
        } else {
          final nextYear = base.year + 1;
          final maxDiasNextYear = diasEnMes(nextYear, mesTarget);
          return DateTime(nextYear, mesTarget, min(diaTarget, maxDiasNextYear));
        }
    }
  }

  /// Calcula la fecha del SIGUIENTE corte a partir de una fecha de corte previa.
  /// [diaMesReferencia]: Preserva el día original pactado para meses de distinta duración (ej. 31 de Enero -> 28 Febrero -> 31 Marzo).
  static DateTime calcularSiguienteCorte({
    required DateTime cortePrevio,
    required PeriodoTasa periodo,
    int? diaMesReferencia,
  }) {
    final base = DateTime(cortePrevio.year, cortePrevio.month, cortePrevio.day);

    switch (periodo) {
      case PeriodoTasa.diario:
        return base.add(const Duration(days: 1));

      case PeriodoTasa.semanal:
        return base.add(const Duration(days: 7));

      case PeriodoTasa.quincenal:
        // Si el corte previo fue el día 15 -> el siguiente es fin de mes
        if (base.day == 15) {
          final finMes = diasEnMes(base.year, base.month);
          return DateTime(base.year, base.month, finMes);
        } else {
          // Si fue fin de mes -> el siguiente es el 15 del mes siguiente
          int nextMonth = base.month + 1;
          int nextYear = base.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          return DateTime(nextYear, nextMonth, 15);
        }

      case PeriodoTasa.mensual:
        int nextMonth = base.month + 1;
        int nextYear = base.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        final diaDeseado = diaMesReferencia ?? base.day;
        final maxDias = diasEnMes(nextYear, nextMonth);
        final diaAjustado = min(diaDeseado, maxDias);
        return DateTime(nextYear, nextMonth, diaAjustado);

      case PeriodoTasa.anual:
        final nextYear = base.year + 1;
        final maxDias = diasEnMes(nextYear, base.month);
        final diaDeseado = diaMesReferencia ?? base.day;
        final diaAjustado = min(diaDeseado, maxDias);
        return DateTime(nextYear, base.month, diaAjustado);
    }
  }

  /// Proyecta las siguientes N fechas de corte a partir de una fecha de desembolso.
  static List<DateTime> proyectarCortes({
    required DateTime fechaDesembolso,
    required PeriodoTasa periodo,
    int? diaSemanaDeseado,
    int? diaMesDeseado,
    int? mesAnualDeseado,
    int cantidad = 3,
  }) {
    if (cantidad <= 0) return [];

    final list = <DateTime>[];
    final primer = calcularPrimerCorte(
      fechaDesembolso: fechaDesembolso,
      periodo: periodo,
      diaSemanaDeseado: diaSemanaDeseado,
      diaMesDeseado: diaMesDeseado,
      mesAnualDeseado: mesAnualDeseado,
    );
    list.add(primer);

    final diaReferencia = diaMesDeseado ?? primer.day;
    DateTime cursor = primer;

    for (int i = 1; i < cantidad; i++) {
      cursor = calcularSiguienteCorte(
        cortePrevio: cursor,
        periodo: periodo,
        diaMesReferencia: diaReferencia,
      );
      list.add(cursor);
    }

    return list;
  }
}
