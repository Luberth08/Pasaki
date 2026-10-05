import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/core/domain/money.dart';
import 'package:pasaki/domain/models/periodo_tasa.dart';
import 'package:pasaki/domain/models/saldo_cuenta.dart';
import 'package:pasaki/domain/models/tasa_interes.dart';
import 'package:pasaki/domain/models/tipo_modalidad_interes.dart';
import 'package:pasaki/domain/services/motor_financiero.dart';

void main() {
  const motor = MotorFinanciero();

  group('MotorFinanciero - Devengamiento y Reglas de Negocio', () {
    test('Calcula interés simple correctamente (4,000 Bs al 20% = 800 Bs)', () {
      final saldoInicial = SaldoCuenta(
        saldoCapital: Money.fromBs(4000),
        saldoInteres: Money.zero,
      );

      final nuevoSaldo = motor.devengarInteresPeriodo(
        saldoActual: saldoInicial,
        tasa: TasaInteres.estandarDefecto, // 20% mensual
        modalidad: TipoModalidadInteres.simple,
      );

      expect(nuevoSaldo.saldoCapital, equals(Money.fromBs(4000)));
      expect(nuevoSaldo.saldoInteres, equals(Money.fromBs(800)));
      expect(nuevoSaldo.totalDeuda, equals(Money.fromBs(4800)));
    });

    test('Caso de Estudio René: Ciclo de vida completo con reestructuración y capitalización', () {
      // 1. Desembolso inicial (01-jun)
      var saldo = SaldoCuenta(
        saldoCapital: Money.fromBs(4000),
        saldoInteres: Money.zero,
      );

      // 2. Cierre de Junio (01-jul): Devengamiento 20%
      saldo = motor.devengarInteresPeriodo(
        saldoActual: saldo,
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
      );
      expect(saldo.saldoCapital, equals(Money.fromBs(4000)));
      expect(saldo.saldoInteres, equals(Money.fromBs(800)));

      // 3. Pago parcial de René (05-jul): 500 Bs a interés
      final pagoParcial = motor.imputarPagoAutomatico(
        saldoActual: saldo,
        montoPagado: Money.fromBs(500),
      );
      expect(pagoParcial.abonadoAInteres, equals(Money.fromBs(500)));
      expect(pagoParcial.abonadoACapital, equals(Money.zero));
      saldo = pagoParcial.nuevoSaldo;
      expect(saldo.saldoCapital, equals(Money.fromBs(4000)));
      expect(saldo.saldoInteres, equals(Money.fromBs(300)));

      // 4. Reestructuración (15-jul): Capitalización de los 300 Bs de mora
      saldo = motor.capitalizarInteres(saldoActual: saldo);
      expect(saldo.saldoCapital, equals(Money.fromBs(4300)));
      expect(saldo.saldoInteres, equals(Money.zero));

      // 5. Cierre de Julio (01-ago): Nueva tasa preferencial del 1% mensual (12% anual)
      const tasaPreferencial = TasaInteres(porcentaje: 1.0, periodo: PeriodoTasa.mensual);
      saldo = motor.devengarInteresPeriodo(
        saldoActual: saldo,
        tasa: tasaPreferencial,
        modalidad: TipoModalidadInteres.simple,
      );
      expect(saldo.saldoCapital, equals(Money.fromBs(4300)));
      expect(saldo.saldoInteres, equals(Money.fromBs(43)));
      expect(saldo.totalDeuda, equals(Money.fromBs(4343)));

      // 6. Liquidación total (05-ago): Pago de 4,343 Bs
      final liquidacion = motor.imputarPagoAutomatico(
        saldoActual: saldo,
        montoPagado: Money.fromBs(4343),
      );
      expect(liquidacion.abonadoAInteres, equals(Money.fromBs(43)));
      expect(liquidacion.abonadoACapital, equals(Money.fromBs(4300)));
      expect(liquidacion.nuevoSaldo.isLiquidado, isTrue);
    });

    test('Comparación: Caso René bajo Interés Simple estricto (sin capitalizar)', () {
      // Saldo luego del abono de 500: Capital 4000, Interés 300
      var saldo = SaldoCuenta(
        saldoCapital: Money.fromBs(4000),
        saldoInteres: Money.fromBs(300),
      );

      // Cierre de Julio con tasa 1% mensual sin capitalizar
      saldo = motor.devengarInteresPeriodo(
        saldoActual: saldo,
        tasa: const TasaInteres(porcentaje: 1.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
      );

      // Interés generado = 4000 * 1% = 40 Bs. Interés pendiente total = 300 + 40 = 340 Bs.
      expect(saldo.saldoCapital, equals(Money.fromBs(4000)));
      expect(saldo.saldoInteres, equals(Money.fromBs(340)));
      expect(saldo.totalDeuda, equals(Money.fromBs(4340)));
    });

    test('Imputación manual flexible: Permite abonar directo a capital (RF-16)', () {
      final saldo = SaldoCuenta(
        saldoCapital: Money.fromBs(4000),
        saldoInteres: Money.fromBs(800),
      );

      // El prestamista acuerda recibir 1000 Bs directo al capital
      final resultado = motor.imputarPagoManual(
        saldoActual: saldo,
        montoACapital: Money.fromBs(1000),
        montoAInteres: Money.zero,
      );

      expect(resultado.abonadoACapital, equals(Money.fromBs(1000)));
      expect(resultado.abonadoAInteres, equals(Money.zero));
      expect(resultado.nuevoSaldo.saldoCapital, equals(Money.fromBs(3000)));
      expect(resultado.nuevoSaldo.saldoInteres, equals(Money.fromBs(800)));
      expect(resultado.nuevoSaldo.totalDeuda, equals(Money.fromBs(3800)));
    });

    test('Condonación de interés (RF-19)', () {
      final saldo = SaldoCuenta(
        saldoCapital: Money.fromBs(4000),
        saldoInteres: Money.fromBs(800),
      );

      // Se condonan 300 Bs de interés
      final saldoCondonado = motor.aplicarCondonacionInteres(
        saldoActual: saldo,
        montoCondonado: Money.fromBs(300),
      );

      expect(saldoCondonado.saldoCapital, equals(Money.fromBs(4000)));
      expect(saldoCondonado.saldoInteres, equals(Money.fromBs(500)));
    });

    test('Acumulación de desembolsos en un mismo período (RF-13)', () {
      final saldo = SaldoCuenta(
        saldoCapital: Money.fromBs(4000),
        saldoInteres: Money.fromBs(500),
      );

      // Se le desembolsan 2,500 Bs adicionales
      final saldoConsolidado = motor.acumularDesembolso(
        saldoActual: saldo,
        nuevoDesembolso: Money.fromBs(2500),
      );

      expect(saldoConsolidado.saldoCapital, equals(Money.fromBs(6500)));
      expect(saldoConsolidado.saldoInteres, equals(Money.fromBs(500)));
    });

    test('Sobrepago devuelve excedente y liquida la cuenta', () {
      final saldo = SaldoCuenta(
        saldoCapital: Money.fromBs(1000),
        saldoInteres: Money.fromBs(200),
      );

      // Paga 1,500 Bs (debe 1,200)
      final resultado = motor.imputarPagoAutomatico(
        saldoActual: saldo,
        montoPagado: Money.fromBs(1500),
      );

      expect(resultado.abonadoAInteres, equals(Money.fromBs(200)));
      expect(resultado.abonadoACapital, equals(Money.fromBs(1000)));
      expect(resultado.excedente, equals(Money.fromBs(300)));
      expect(resultado.nuevoSaldo.isLiquidado, isTrue);
    });
  });
}
