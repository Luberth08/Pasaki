import '../../../core/domain/money.dart';
import '../../../domain/models/periodo_tasa.dart';
import '../../../domain/models/tipo_movimiento.dart';
import '../../../domain/repositories/prestamo_repository.dart';
import '../../../domain/services/calculador_fechas_corte.dart';
import '../../../domain/services/motor_financiero.dart';
import 'devengar_intereses_use_case.dart';

/// Caso de Uso: Verifica préstamos activos y aplica devengamientos devengados pendientes (Lazy Catch-Up).
/// Garantiza que el paso del tiempo genere los intereses automáticamente sin necesidad de daemons.
class VerificarYDevengarAutomaticoUseCase {
  final IPrestamoRepository prestamoRepository;
  final DevengarInteresesUseCase devengarInteresesUseCase;

  const VerificarYDevengarAutomaticoUseCase({
    required this.prestamoRepository,
    required this.devengarInteresesUseCase,
  });

  /// Ejecuta la verificación temporal. Retorna la cantidad de períodos devengados automáticamente.
  Future<int> execute({DateTime? fechaReferencia}) async {
    final now = fechaReferencia ?? DateTime.now();
    final prestamos = await prestamoRepository.obtenerActivos();
    int periodosDevengados = 0;

    for (final prestamo in prestamos) {
      if (!prestamo.isActivo || prestamo.saldoActual.saldoCapital.isZero) {
        continue;
      }

      final movimientos = await prestamoRepository.obtenerMovimientos(prestamo.id!);

      // Buscar la última fecha de devengamiento (o la fecha de inicio del préstamo)
      final movimientosDevengamiento = movimientos
          .where((m) => m.tipo == TipoMovimiento.interesGenerado)
          .toList();

      int ultimaFechaMs;
      final bool esPrimerDevengamiento = movimientosDevengamiento.isEmpty;
      if (!esPrimerDevengamiento) {
        movimientosDevengamiento.sort((a, b) => b.fecha.compareTo(a.fecha));
        ultimaFechaMs = movimientosDevengamiento.first.fecha;
      } else {
        ultimaFechaMs = prestamo.fechaInicio;
      }

      DateTime cursorFecha = DateTime.fromMillisecondsSinceEpoch(ultimaFechaMs);
      DateTime proximoCierre;

      if (esPrimerDevengamiento && prestamo.fechaPrimerCorte != null) {
        proximoCierre = DateTime.fromMillisecondsSinceEpoch(prestamo.fechaPrimerCorte!);
      } else if (prestamo.fechaPrimerCorte != null) {
        final diaRef = DateTime.fromMillisecondsSinceEpoch(prestamo.fechaPrimerCorte!).day;
        proximoCierre = CalculadorFechasCorte.calcularSiguienteCorte(
          cortePrevio: cursorFecha,
          periodo: prestamo.tasa.periodo,
          diaMesReferencia: diaRef,
        );
      } else {
        proximoCierre = calcularProximaFecha(cursorFecha, prestamo.tasa.periodo);
      }

      while (!proximoCierre.isAfter(now)) {
        final cursorDia = DateTime(cursorFecha.year, cursorFecha.month, cursorFecha.day);
        final proximoCierreDia = DateTime(proximoCierre.year, proximoCierre.month, proximoCierre.day);
        final diasTranscurridos = proximoCierreDia.difference(cursorDia).inDays;

        // Identificar si hubo desembolsos adicionales en este período
        final movimientosDesembolso = movimientos
            .where((m) => m.tipo == TipoMovimiento.desembolso)
            .toList()
          ..sort((a, b) => a.id != null && b.id != null ? a.id!.compareTo(b.id!) : a.fecha.compareTo(b.fecha));

        final primerDesembolsoId = movimientosDesembolso.isNotEmpty ? movimientosDesembolso.first.id : null;

        final desembolsosEnPeriodo = movimientos.where((m) {
          if (m.tipo != TipoMovimiento.desembolso) return false;
          if (m.id == primerDesembolsoId) return false; // Excluir desembolso inicial de creación
          final fechaM = DateTime.fromMillisecondsSinceEpoch(m.fecha);
          final fechaMDia = DateTime(fechaM.year, fechaM.month, fechaM.day);
          return !fechaMDia.isBefore(cursorDia) && !fechaMDia.isAfter(proximoCierreDia);
        }).toList();

        List<TramoDesembolso>? tramos;
        if (prestamo.prorratearInteres && desembolsosEnPeriodo.isNotEmpty) {
          tramos = [];
          int sumaDesembolsosNuevosCents = 0;
          for (final d in desembolsosEnPeriodo) {
            final montoD = d.debe ?? Money.zero;
            sumaDesembolsosNuevosCents += montoD.cents;
            final fechaD = DateTime.fromMillisecondsSinceEpoch(d.fecha);
            final fechaDDia = DateTime(fechaD.year, fechaD.month, fechaD.day);
            final diasActivo = proximoCierreDia.difference(fechaDDia).inDays.clamp(1, prestamo.tasa.periodo.diasReferencia);
            tramos.add(TramoDesembolso(monto: montoD, diasActivo: diasActivo));
          }

          final capitalActual = prestamo.saldoActual.saldoCapital;
          final capitalBaseCents = capitalActual.cents - sumaDesembolsosNuevosCents;
          if (capitalBaseCents > 0) {
            final diasBase = diasTranscurridos.clamp(1, prestamo.tasa.periodo.diasReferencia);
            tramos.insert(0, TramoDesembolso(
              monto: Money.fromCents(capitalBaseCents),
              diasActivo: diasBase,
            ));
          }
        }

        final bool esProrrateado = prestamo.prorratearInteres &&
            ((tramos != null && tramos.isNotEmpty) ||
                diasTranscurridos < prestamo.tasa.periodo.diasReferencia);

        final glosa = (tramos != null && tramos.isNotEmpty)
            ? 'Devengamiento con prorrateo de desembolsos adicionales'
            : (esProrrateado
                ? 'Devengamiento prorrateado ($diasTranscurridos días de ${prestamo.tasa.periodo.diasReferencia})'
                : 'Devengamiento automático (${prestamo.tasa.periodo.etiqueta.toLowerCase()})');

        await devengarInteresesUseCase.execute(
          prestamoId: prestamo.id!,
          diasTranscurridos: diasTranscurridos,
          fecha: proximoCierre.millisecondsSinceEpoch,
          detalle: glosa,
          tramosProrrateo: tramos,
        );

        periodosDevengados++;
        cursorFecha = proximoCierre;

        if (prestamo.fechaPrimerCorte != null) {
          final diaRef = DateTime.fromMillisecondsSinceEpoch(prestamo.fechaPrimerCorte!).day;
          proximoCierre = CalculadorFechasCorte.calcularSiguienteCorte(
            cortePrevio: cursorFecha,
            periodo: prestamo.tasa.periodo,
            diaMesReferencia: diaRef,
          );
        } else {
          proximoCierre = calcularProximaFecha(cursorFecha, prestamo.tasa.periodo);
        }
      }
    }

    return periodosDevengados;
  }

  /// Calcula la fecha en la que vence el próximo ciclo de interés.
  /// Para tasas mensuales, si el préstamo inició a mitad de mes, el primer corte se hace el 1 del mes siguiente.
  static DateTime calcularProximaFecha(DateTime desde, PeriodoTasa periodo) {
    switch (periodo) {
      case PeriodoTasa.diario:
        return desde.add(const Duration(days: 1));
      case PeriodoTasa.semanal:
        return desde.add(const Duration(days: 7));
      case PeriodoTasa.quincenal:
        return desde.add(const Duration(days: 15));
      case PeriodoTasa.mensual:
        int newYear = desde.year;
        int newMonth = desde.month + 1;
        if (newMonth > 12) {
          newYear++;
          newMonth = 1;
        }
        // Corte siempre al 1 de cada mes para ciclos mensuales estándar
        final day = 1;
        return DateTime(newYear, newMonth, day, desde.hour, desde.minute, desde.second);
      case PeriodoTasa.anual:
        return DateTime(desde.year + 1, desde.month, desde.day, desde.hour, desde.minute, desde.second);
    }
  }
}
