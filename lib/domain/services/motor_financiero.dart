import '../../core/domain/money.dart';
import '../models/distribucion_pago.dart';
import '../models/saldo_cuenta.dart';
import '../models/tasa_interes.dart';
import '../models/tipo_modalidad_interes.dart';

/// Representa un tramo o fracción de capital desembolsado y los días que estuvo activo dentro de un ciclo (RF-13).
class TramoDesembolso {
  final Money monto;
  final int diasActivo;

  const TramoDesembolso({
    required this.monto,
    required this.diasActivo,
  });
}

/// Motor central de cálculo y reglas de negocio financieras para microcréditos.
/// Implementa lógica pura de dominio, sin efectos secundarios ni dependencias externas.
class MotorFinanciero {
  const MotorFinanciero();

  /// Calcula el devengamiento de intereses al cierre de un ciclo o período (RF-12, RF-14).
  ///
  /// - En [TipoModalidadInteres.simple]: El interés se liquida sobre el capital actual
  ///   y se acumula en el saldo de interés pendiente.
  /// - En [TipoModalidadInteres.compuesto]: El interés pendiente previo se capitaliza
  ///   (se suma al capital) y luego se calcula el nuevo interés sobre la base total.
  /// - [tramosProrrateo]: Permite desglosar el capital en múltiples desembolsos con días
  ///   activos independientes para prorratear con exactitud cada tramo (RF-13).
  SaldoCuenta devengarInteresPeriodo({
    required SaldoCuenta saldoActual,
    required TasaInteres tasa,
    required TipoModalidadInteres modalidad,
    int? diasTranscurridos,
    bool prorratear = false,
    List<TramoDesembolso>? tramosProrrateo,
  }) {
    if (saldoActual.saldoCapital.isZero) {
      return saldoActual;
    }

    final baseCalculo = (modalidad == TipoModalidadInteres.simple)
        ? saldoActual.saldoCapital
        : (saldoActual.saldoCapital + saldoActual.saldoInteres);

    Money interesGenerado;

    if (prorratear && tramosProrrateo != null && tramosProrrateo.isNotEmpty) {
      int totalCents = 0;
      for (final tramo in tramosProrrateo) {
        if (tramo.monto.isZero || tramo.monto.isNegative) continue;
        final interesTramoCompleto = tasa.calcularInteresPeriodo(tramo.monto);
        final proporcion = (tramo.diasActivo / tasa.periodo.diasReferencia).clamp(0.0, 1.0);
        totalCents += (interesTramoCompleto.cents * proporcion).round();
      }

      // En modalidad compuesta, el interés pendiente previo capitalizado también devenga interés
      if (modalidad == TipoModalidadInteres.compuesto && saldoActual.saldoInteres.isPositive) {
        final interesSobreInteres = tasa.calcularInteresPeriodo(saldoActual.saldoInteres);
        totalCents += interesSobreInteres.cents;
      }

      interesGenerado = Money.fromCents(totalCents);
    } else if (prorratear && diasTranscurridos != null && diasTranscurridos < tasa.periodo.diasReferencia) {
      final interesPeriodoCompleto = tasa.calcularInteresPeriodo(baseCalculo);
      final proporcion = diasTranscurridos / tasa.periodo.diasReferencia;
      final centsProrrateados = (interesPeriodoCompleto.cents * proporcion).round();
      interesGenerado = Money.fromCents(centsProrrateados);
    } else {
      interesGenerado = tasa.calcularInteresPeriodo(baseCalculo);
    }

    if (modalidad == TipoModalidadInteres.simple) {
      return SaldoCuenta(
        saldoCapital: saldoActual.saldoCapital,
        saldoInteres: saldoActual.saldoInteres + interesGenerado,
      );
    } else {
      return SaldoCuenta(
        saldoCapital: baseCalculo,
        saldoInteres: interesGenerado,
      );
    }
  }

  /// Imputa un abono o pago según la regla en cascada estándar (Primero Interés, luego Capital).
  /// Si el pago excede la deuda total, se devuelve el sobrante en [DistribucionPago.excedente].
  DistribucionPago imputarPagoAutomatico({
    required SaldoCuenta saldoActual,
    required Money montoPagado,
  }) {
    if (montoPagado.isNegative) {
      throw ArgumentError('El monto del pago no puede ser negativo.');
    }
    if (montoPagado.isZero) {
      return DistribucionPago(
        montoTotalPagado: Money.zero,
        abonadoAInteres: Money.zero,
        abonadoACapital: Money.zero,
        nuevoSaldo: saldoActual,
      );
    }

    Money restantePorAplicar = montoPagado;
    Money pagoInteres = Money.zero;
    Money pagoCapital = Money.zero;

    // 1. Amortizar Interés Pendiente
    if (saldoActual.saldoInteres.isPositive) {
      if (restantePorAplicar >= saldoActual.saldoInteres) {
        pagoInteres = saldoActual.saldoInteres;
        restantePorAplicar = restantePorAplicar - saldoActual.saldoInteres;
      } else {
        pagoInteres = restantePorAplicar;
        restantePorAplicar = Money.zero;
      }
    }

    // 2. Amortizar Saldo Capital
    if (restantePorAplicar.isPositive && saldoActual.saldoCapital.isPositive) {
      if (restantePorAplicar >= saldoActual.saldoCapital) {
        pagoCapital = saldoActual.saldoCapital;
        restantePorAplicar = restantePorAplicar - saldoActual.saldoCapital;
      } else {
        pagoCapital = restantePorAplicar;
        restantePorAplicar = Money.zero;
      }
    }

    final nuevoSaldo = SaldoCuenta(
      saldoCapital: saldoActual.saldoCapital - pagoCapital,
      saldoInteres: saldoActual.saldoInteres - pagoInteres,
    );

    return DistribucionPago(
      montoTotalPagado: montoPagado,
      abonadoAInteres: pagoInteres,
      abonadoACapital: pagoCapital,
      nuevoSaldo: nuevoSaldo,
      excedente: restantePorAplicar,
    );
  }

  /// Imputa un pago definiendo explícitamente cuánto se destina a capital y cuánto a interés (RF-16).
  /// Permite la flexibilidad del microcrédito informal (ej. abonar directo a capital por acuerdo).
  DistribucionPago imputarPagoManual({
    required SaldoCuenta saldoActual,
    required Money montoACapital,
    required Money montoAInteres,
  }) {
    if (montoACapital.isNegative || montoAInteres.isNegative) {
      throw ArgumentError('Los montos a capital e interés no pueden ser negativos.');
    }

    if (montoAInteres > saldoActual.saldoInteres) {
      throw ArgumentError(
        'El monto a interés ($montoAInteres) no puede superar el saldo pendiente ($saldoActual.saldoInteres).',
      );
    }

    if (montoACapital > saldoActual.saldoCapital) {
      throw ArgumentError(
        'El monto a capital ($montoACapital) no puede superar el capital adeudado ($saldoActual.saldoCapital).',
      );
    }

    final totalPagado = montoACapital + montoAInteres;
    final nuevoSaldo = SaldoCuenta(
      saldoCapital: saldoActual.saldoCapital - montoACapital,
      saldoInteres: saldoActual.saldoInteres - montoAInteres,
    );

    return DistribucionPago(
      montoTotalPagado: totalPagado,
      abonadoAInteres: montoAInteres,
      abonadoACapital: montoACapital,
      nuevoSaldo: nuevoSaldo,
    );
  }

  /// Capitaliza una porción o la totalidad del interés pendiente sumándolo al capital (Caso René / Reestructuración).
  SaldoCuenta capitalizarInteres({
    required SaldoCuenta saldoActual,
    Money? montoACapitalizar,
  }) {
    final monto = montoACapitalizar ?? saldoActual.saldoInteres;

    if (monto.isNegative) {
      throw ArgumentError('El monto a capitalizar no puede ser negativo.');
    }
    if (monto > saldoActual.saldoInteres) {
      throw ArgumentError(
        'No se puede capitalizar más del interés pendiente ($saldoActual.saldoInteres).',
      );
    }

    return SaldoCuenta(
      saldoCapital: saldoActual.saldoCapital + monto,
      saldoInteres: saldoActual.saldoInteres - monto,
    );
  }

  /// Aplica una quita o condonación de intereses (RF-19).
  SaldoCuenta aplicarCondonacionInteres({
    required SaldoCuenta saldoActual,
    required Money montoCondonado,
  }) {
    if (montoCondonado.isNegative) {
      throw ArgumentError('El monto condonado no puede ser negativo.');
    }
    if (montoCondonado > saldoActual.saldoInteres) {
      throw ArgumentError(
        'No se puede condonar más del interés pendiente actual ($saldoActual.saldoInteres).',
      );
    }

    return SaldoCuenta(
      saldoCapital: saldoActual.saldoCapital,
      saldoInteres: saldoActual.saldoInteres - montoCondonado,
    );
  }

  /// Acumula un nuevo desembolso al capital existente del cliente (RF-13).
  SaldoCuenta acumularDesembolso({
    required SaldoCuenta saldoActual,
    required Money nuevoDesembolso,
  }) {
    if (nuevoDesembolso.isNegative || nuevoDesembolso.isZero) {
      throw ArgumentError('El desembolso debe ser un monto positivo.');
    }

    return SaldoCuenta(
      saldoCapital: saldoActual.saldoCapital + nuevoDesembolso,
      saldoInteres: saldoActual.saldoInteres,
    );
  }
}
