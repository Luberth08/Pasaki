import 'package:sqflite/sqflite.dart';
import '../../core/domain/money.dart';
import '../../domain/models/distribucion_pago.dart';
import '../../domain/models/movimiento_financiero.dart';
import '../../domain/models/prestamo.dart';
import '../../domain/models/saldo_cuenta.dart';
import '../../domain/models/tasa_interes.dart';
import '../../domain/models/tipo_movimiento.dart';
import '../../domain/repositories/prestamo_repository.dart';

class SqlitePrestamoRepository implements IPrestamoRepository {
  final Database db;

  const SqlitePrestamoRepository(this.db);

  @override
  Future<Prestamo> crearConDesembolso(Prestamo prestamo) async {
    return await db.transaction((txn) async {
      // 1. Insertar el préstamo
      final prestamoId = await txn.insert('prestamos', prestamo.toMap());

      // 2. Registrar el movimiento inalterable de desembolso inicial
      final movimientoInicial = MovimientoFinanciero(
        prestamoId: prestamoId,
        fecha: prestamo.fechaInicio,
        tipo: TipoMovimiento.desembolso,
        detalle: 'Desembolso de capital inicial',
        debe: prestamo.capitalInicial,
        haber: null,
        saldoCapitalResultante: prestamo.capitalInicial,
        saldoInteresResultante: prestamo.saldoActual.saldoInteres,
        createdAt: prestamo.createdAt,
      );

      await txn.insert('movimientos', movimientoInicial.toMap());

      return prestamo.copyWith(id: prestamoId);
    });
  }

  @override
  Future<void> registrarDesembolsoAdicionalTransaccional({
    required int prestamoId,
    required Money montoAdicional,
    required String detalle,
    required int fecha,
  }) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'prestamos',
        where: 'id = ?',
        whereArgs: [prestamoId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('El préstamo con ID $prestamoId no existe.');
      }
      final prestamo = Prestamo.fromMap(rows.first);
      final nuevoCapital = prestamo.saldoActual.saldoCapital + montoAdicional;

      // 1. Registrar movimiento inalterable de desembolso en el libro mayor
      final movimiento = MovimientoFinanciero(
        prestamoId: prestamoId,
        fecha: fecha,
        tipo: TipoMovimiento.desembolso,
        detalle: detalle,
        debe: montoAdicional,
        haber: null,
        saldoCapitalResultante: nuevoCapital,
        saldoInteresResultante: prestamo.saldoActual.saldoInteres,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await txn.insert('movimientos', movimiento.toMap());

      // 2. Actualizar el saldo de capital del préstamo
      await txn.update(
        'prestamos',
        {
          'saldo_capital_cents': nuevoCapital.cents,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [prestamoId],
      );
    });
  }

  @override
  Future<void> registrarPagoTransaccional({
    required int prestamoId,
    required DistribucionPago distribucion,
    required String detalle,
    required int fecha,
  }) async {
    await db.transaction((txn) async {
      // 1. Insertar movimiento de pago en el libro
      final movimiento = MovimientoFinanciero(
        prestamoId: prestamoId,
        fecha: fecha,
        tipo: TipoMovimiento.pago,
        detalle: detalle,
        debe: null,
        haber: distribucion.montoTotalPagado,
        saldoCapitalResultante: distribucion.nuevoSaldo.saldoCapital,
        saldoInteresResultante: distribucion.nuevoSaldo.saldoInteres,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await txn.insert('movimientos', movimiento.toMap());

      // 2. Actualizar saldos y estado en la tabla de préstamos
      final nuevoEstado = distribucion.nuevoSaldo.isLiquidado ? 'liquidado' : 'activo';

      await txn.update(
        'prestamos',
        {
          'saldo_capital_cents': distribucion.nuevoSaldo.saldoCapital.cents,
          'saldo_interes_cents': distribucion.nuevoSaldo.saldoInteres.cents,
          'estado': nuevoEstado,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [prestamoId],
      );
    });
  }

  @override
  Future<void> registrarDevengamientoTransaccional({
    required int prestamoId,
    required SaldoCuenta nuevoSaldo,
    required String detalle,
    required int fecha,
  }) async {
    await db.transaction((txn) async {
      final movimiento = MovimientoFinanciero(
        prestamoId: prestamoId,
        fecha: fecha,
        tipo: TipoMovimiento.interesGenerado,
        detalle: detalle,
        debe: null,
        haber: null,
        saldoCapitalResultante: nuevoSaldo.saldoCapital,
        saldoInteresResultante: nuevoSaldo.saldoInteres,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await txn.insert('movimientos', movimiento.toMap());

      await txn.update(
        'prestamos',
        {
          'saldo_capital_cents': nuevoSaldo.saldoCapital.cents,
          'saldo_interes_cents': nuevoSaldo.saldoInteres.cents,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [prestamoId],
      );
    });
  }

  @override
  Future<void> registrarReestructuracionTransaccional({
    required int prestamoId,
    required SaldoCuenta nuevoSaldo,
    required TasaInteres nuevaTasa,
    required String motivo,
    required int fecha,
  }) async {
    await db.transaction((txn) async {
      final movimiento = MovimientoFinanciero(
        prestamoId: prestamoId,
        fecha: fecha,
        tipo: TipoMovimiento.reestructuracion,
        detalle: 'Reestructuración: $motivo',
        debe: null,
        haber: null,
        saldoCapitalResultante: nuevoSaldo.saldoCapital,
        saldoInteresResultante: nuevoSaldo.saldoInteres,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await txn.insert('movimientos', movimiento.toMap());

      await txn.update(
        'prestamos',
        {
          'saldo_capital_cents': nuevoSaldo.saldoCapital.cents,
          'saldo_interes_cents': nuevoSaldo.saldoInteres.cents,
          'tasa_porcentaje': nuevaTasa.porcentaje,
          'tasa_periodo': nuevaTasa.periodo.name,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [prestamoId],
      );
    });
  }

  @override
  Future<Prestamo?> obtenerPorId(int id) async {
    final results = await db.query(
      'prestamos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;

    final movimientos = await obtenerMovimientos(id);
    return Prestamo.fromMap(results.first, movimientos: movimientos);
  }

  @override
  Future<List<Prestamo>> obtenerPorCliente(int clienteId) async {
    final results = await db.query(
      'prestamos',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'fecha_inicio DESC',
    );
    return results.map((r) => Prestamo.fromMap(r)).toList();
  }

  @override
  Future<List<Prestamo>> obtenerActivos() async {
    final results = await db.query(
      'prestamos',
      where: 'estado = ?',
      whereArgs: ['activo'],
      orderBy: 'fecha_inicio DESC',
    );
    return results.map((r) => Prestamo.fromMap(r)).toList();
  }

  @override
  Future<List<MovimientoFinanciero>> obtenerMovimientos(int prestamoId) async {
    final results = await db.query(
      'movimientos',
      where: 'prestamo_id = ?',
      whereArgs: [prestamoId],
      orderBy: 'fecha ASC, id ASC',
    );
    return results.map((m) => MovimientoFinanciero.fromMap(m)).toList();
  }
}
