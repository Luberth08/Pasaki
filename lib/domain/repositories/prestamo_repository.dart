import '../../core/domain/money.dart';
import '../models/distribucion_pago.dart';
import '../models/movimiento_financiero.dart';
import '../models/prestamo.dart';
import '../models/saldo_cuenta.dart';
import '../models/tasa_interes.dart';

abstract class IPrestamoRepository {
  /// Registra el préstamo y su movimiento inicial de desembolso dentro de una transacción ACID.
  Future<Prestamo> crearConDesembolso(Prestamo prestamo);

  /// Registra un desembolso adicional y actualiza el saldo de capital dentro de una transacción ACID (RF-13).
  Future<void> registrarDesembolsoAdicionalTransaccional({
    required int prestamoId,
    required Money montoAdicional,
    required String detalle,
    required int fecha,
  });

  /// Registra un pago y actualiza los saldos en una única transacción ACID.
  Future<void> registrarPagoTransaccional({
    required int prestamoId,
    required DistribucionPago distribucion,
    required String detalle,
    required int fecha,
  });

  /// Registra el devengamiento periódico de intereses de forma atómica.
  Future<void> registrarDevengamientoTransaccional({
    required int prestamoId,
    required SaldoCuenta nuevoSaldo,
    required String detalle,
    required int fecha,
  });

  /// Registra una reestructuración o capitalización de mora de forma atómica.
  Future<void> registrarReestructuracionTransaccional({
    required int prestamoId,
    required SaldoCuenta nuevoSaldo,
    required TasaInteres nuevaTasa,
    required String motivo,
    required int fecha,
  });

  Future<Prestamo?> obtenerPorId(int id);
  Future<List<Prestamo>> obtenerPorCliente(int clienteId);
  Future<List<Prestamo>> obtenerActivos();
  Future<List<MovimientoFinanciero>> obtenerMovimientos(int prestamoId);
}
