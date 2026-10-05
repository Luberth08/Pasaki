import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/domain/models/periodo_tasa.dart';
import 'package:pasaki/domain/services/calculador_fechas_corte.dart';

void main() {
  group('CalculadorFechasCorte - Dominio de Fechas y Cronogramas', () {
    test('Diario: suma 1 día calendario', () {
      final desembolso = DateTime(2026, 3, 10);
      final primerCorte = CalculadorFechasCorte.calcularPrimerCorte(
        fechaDesembolso: desembolso,
        periodo: PeriodoTasa.diario,
      );
      expect(primerCorte, DateTime(2026, 3, 11));
    });

    test('Semanal: proyecta al día de la semana elegido', () {
      // 2026-03-09 es Lunes (weekday = 1)
      final lunes = DateTime(2026, 3, 9);

      // Si elige Miércoles (weekday = 3)
      final corteMiercoles = CalculadorFechasCorte.calcularPrimerCorte(
        fechaDesembolso: lunes,
        periodo: PeriodoTasa.semanal,
        diaSemanaDeseado: DateTime.wednesday,
      );
      expect(corteMiercoles, DateTime(2026, 3, 11)); // 2 días después

      // Si elige Lunes (mismo día de la semana) -> 7 días después
      final corteLunes = CalculadorFechasCorte.calcularPrimerCorte(
        fechaDesembolso: lunes,
        periodo: PeriodoTasa.semanal,
        diaSemanaDeseado: DateTime.monday,
      );
      expect(corteLunes, DateTime(2026, 3, 16));
    });

    test('Quincenal: esquema clásico 15 y fin de mes', () {
      // Desembolso antes del 15 -> primer corte el 15
      final d1 = DateTime(2026, 3, 5);
      final c1 = CalculadorFechasCorte.calcularPrimerCorte(
        fechaDesembolso: d1,
        periodo: PeriodoTasa.quincenal,
      );
      expect(c1, DateTime(2026, 3, 15));

      // Siguiente corte después del 15 -> fin de mes (31 de marzo)
      final c2 = CalculadorFechasCorte.calcularSiguienteCorte(
        cortePrevio: c1,
        periodo: PeriodoTasa.quincenal,
      );
      expect(c2, DateTime(2026, 3, 31));

      // Siguiente después de fin de mes -> 15 de abril
      final c3 = CalculadorFechasCorte.calcularSiguienteCorte(
        cortePrevio: c2,
        periodo: PeriodoTasa.quincenal,
      );
      expect(c3, DateTime(2026, 4, 15));

      // Desembolso después del 15 (ej: 20 de febrero 2026, año no bisiesto)
      final dFeb = DateTime(2026, 2, 20);
      final cFeb = CalculadorFechasCorte.calcularPrimerCorte(
        fechaDesembolso: dFeb,
        periodo: PeriodoTasa.quincenal,
      );
      expect(cFeb, DateTime(2026, 2, 28)); // Fin de mes de febrero
    });

    test('Mensual: caso 31 de Enero ajusta a 28 de Febrero y vuelve a 31 de Marzo', () {
      final desembolso = DateTime(2026, 1, 31);
      final proyeccion = CalculadorFechasCorte.proyectarCortes(
        fechaDesembolso: desembolso,
        periodo: PeriodoTasa.mensual,
        diaMesDeseado: 31,
        cantidad: 3,
      );

      expect(proyeccion.length, 3);
      // 1° corte: 28 de Febrero (2026 no es bisiesto)
      expect(proyeccion[0], DateTime(2026, 2, 28));
      // 2° corte: 31 de Marzo (recupera el 31)
      expect(proyeccion[1], DateTime(2026, 3, 31));
      // 3° corte: 30 de Abril (ajusta a 30)
      expect(proyeccion[2], DateTime(2026, 4, 30));
    });

    test('Mensual: día pactado mayor que fecha actual cae en el mismo mes', () {
      // Desembolso 5 de Marzo, pactan cobrar los días 20
      final desembolso = DateTime(2026, 3, 5);
      final primerCorte = CalculadorFechasCorte.calcularPrimerCorte(
        fechaDesembolso: desembolso,
        periodo: PeriodoTasa.mensual,
        diaMesDeseado: 20,
      );
      expect(primerCorte, DateTime(2026, 3, 20)); // Mismo mes
    });
  });
}
