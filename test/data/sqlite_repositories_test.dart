import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/core/domain/money.dart';
import 'package:pasaki/data/repositories/sqlite_cliente_repository.dart';
import 'package:pasaki/data/repositories/sqlite_prestamo_repository.dart';
import 'package:pasaki/domain/models/cliente.dart';
import 'package:pasaki/domain/models/contacto.dart';
import 'package:pasaki/domain/models/periodo_tasa.dart';
import 'package:pasaki/domain/models/prestamo.dart';
import 'package:pasaki/domain/models/saldo_cuenta.dart';
import 'package:pasaki/domain/models/tasa_interes.dart';
import 'package:pasaki/domain/models/tipo_modalidad_interes.dart';
import 'package:pasaki/domain/services/motor_financiero.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SqliteClienteRepository clienteRepo;
  late SqlitePrestamoRepository prestamoRepo;
  const motor = MotorFinanciero();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Abrir base de datos en memoria para cada test
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE clientes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL,
              apellido TEXT,
              alias TEXT,
              ci TEXT,
              telefono_principal TEXT NOT NULL,
              direccion TEXT,
              genero TEXT,
              fecha_nacimiento INTEGER,
              ingreso_mensual_cents INTEGER,
              es_lista_negra INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          await database.execute('''
            CREATE TABLE contactos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cliente_id INTEGER NOT NULL,
              telefono TEXT NOT NULL,
              etiqueta TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
            );
          ''');
          await database.execute('''
            CREATE TABLE prestamos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cliente_id INTEGER NOT NULL,
              capital_inicial_cents INTEGER NOT NULL,
              tasa_porcentaje REAL NOT NULL,
              tasa_periodo TEXT NOT NULL,
              modalidad TEXT NOT NULL,
              saldo_capital_cents INTEGER NOT NULL,
              saldo_interes_cents INTEGER NOT NULL,
              estado TEXT NOT NULL DEFAULT 'activo',
              prorratear_interes INTEGER NOT NULL DEFAULT 0,
              fecha_inicio INTEGER NOT NULL,
              fecha_primer_corte INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE RESTRICT
            );
          ''');
          await database.execute('''
            CREATE TABLE movimientos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              prestamo_id INTEGER NOT NULL,
              fecha INTEGER NOT NULL,
              tipo TEXT NOT NULL,
              detalle TEXT NOT NULL,
              debe_cents INTEGER,
              haber_cents INTEGER,
              saldo_capital_cents INTEGER NOT NULL,
              saldo_interes_cents INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              FOREIGN KEY (prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
            );
          ''');
        },
      ),
    );

    clienteRepo = SqliteClienteRepository(db);
    prestamoRepo = SqlitePrestamoRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Persistencia Local SQLite - Integridad ACID', () {
    test('Registrar y buscar cliente con contactos y etiqueta', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cliente = Cliente(
        nombre: 'René',
        apellido: 'Vaca',
        alias: 'El mecánico',
        telefonoPrincipal: '70012345',
        direccion: 'Barrio Los Pozos',
        contactos: [
          Contacto(
            clienteId: 0,
            telefono: '71198765',
            etiqueta: 'Esposa',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final clienteGuardado = await clienteRepo.crear(cliente);
      expect(clienteGuardado.id, isNotNull);

      // Buscar por alias
      final busqueda = await clienteRepo.buscar('mecánico');
      expect(busqueda.length, equals(1));
      expect(busqueda.first.nombreCompleto, equals('René Vaca'));
      expect(busqueda.first.contactos.length, equals(1));
      expect(busqueda.first.contactos.first.etiqueta, equals('Esposa'));
    });

    test('Integridad Referencial: ON DELETE CASCADE en contactos', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cliente = Cliente(
        nombre: 'Pedro',
        telefonoPrincipal: '75555555',
        contactos: [
          Contacto(
            clienteId: 0,
            telefono: '76666666',
            etiqueta: 'Taller',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final guardado = await clienteRepo.crear(cliente);
      final clienteId = guardado.id!;

      // Eliminar cliente
      await clienteRepo.eliminar(clienteId);

      // Los contactos asociados deben eliminarse en cascada automáticamente
      final contactosRestantes = await db.query(
        'contactos',
        where: 'cliente_id = ?',
        whereArgs: [clienteId],
      );
      expect(contactosRestantes, isEmpty);
    });

    test('Flujo Transaccional Completo Caso René en Base de Datos SQLite', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Alta de René
      final rene = await clienteRepo.crear(
        Cliente(
          nombre: 'René',
          alias: 'Taller Central',
          telefonoPrincipal: '70099887',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Creación del Préstamo de 4,000 Bs al 20% mensual
      final prestamoInicial = Prestamo(
        clienteId: rene.id!,
        capitalInicial: Money.fromBs(4000),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        saldoActual: SaldoCuenta(
          saldoCapital: Money.fromBs(4000),
          saldoInteres: Money.zero,
        ),
        fechaInicio: 1717200000000, // 01-jun
        createdAt: now,
        updatedAt: now,
      );

      final prestamo = await prestamoRepo.crearConDesembolso(prestamoInicial);
      final prestamoId = prestamo.id!;

      // Verificar que se haya insertado el movimiento de desembolso inicial
      var movimientos = await prestamoRepo.obtenerMovimientos(prestamoId);
      expect(movimientos.length, equals(1));
      expect(movimientos.first.detalle, contains('Desembolso'));
      expect(movimientos.first.debe, equals(Money.fromBs(4000)));

      // 3. Devengamiento al 01-jul (20% = 800 Bs)
      final saldoTrasDevengamiento = motor.devengarInteresPeriodo(
        saldoActual: prestamo.saldoActual,
        tasa: prestamo.tasa,
        modalidad: prestamo.modalidad,
      );
      await prestamoRepo.registrarDevengamientoTransaccional(
        prestamoId: prestamoId,
        nuevoSaldo: saldoTrasDevengamiento,
        detalle: 'Cierre de Junio (Tasa: 20% mensual)',
        fecha: 1719792000000, // 01-jul
      );

      // 4. Pago parcial de 500 Bs al 05-jul (imputación a interés)
      final distribucionPago = motor.imputarPagoAutomatico(
        saldoActual: saldoTrasDevengamiento,
        montoPagado: Money.fromBs(500),
      );
      await prestamoRepo.registrarPagoTransaccional(
        prestamoId: prestamoId,
        distribucion: distribucionPago,
        detalle: 'Pago parcial de René',
        fecha: 1720137600000, // 05-jul
      );

      // 5. Reestructuración al 15-jul: Capitalización de mora (300 Bs) y tasa al 1%
      final saldoReestructurado = motor.capitalizarInteres(
        saldoActual: distribucionPago.nuevoSaldo,
      );
      const nuevaTasa = TasaInteres(porcentaje: 1.0, periodo: PeriodoTasa.mensual);
      await prestamoRepo.registrarReestructuracionTransaccional(
        prestamoId: prestamoId,
        nuevoSaldo: saldoReestructurado,
        nuevaTasa: nuevaTasa,
        motivo: 'Alivio por situación familiar',
        fecha: 1721001600000, // 15-jul
      );

      // 6. Devengamiento al 01-ago (1% sobre 4,300 = 43 Bs)
      final saldoAgosto = motor.devengarInteresPeriodo(
        saldoActual: saldoReestructurado,
        tasa: nuevaTasa,
        modalidad: TipoModalidadInteres.simple,
      );
      await prestamoRepo.registrarDevengamientoTransaccional(
        prestamoId: prestamoId,
        nuevoSaldo: saldoAgosto,
        detalle: 'Cierre de Julio (Nueva Tasa: 1% mensual)',
        fecha: 1722470400000, // 01-ago
      );

      // 7. Liquidación final al 05-ago: Pago de 4,343 Bs
      final liquidacion = motor.imputarPagoAutomatico(
        saldoActual: saldoAgosto,
        montoPagado: Money.fromBs(4343),
      );
      await prestamoRepo.registrarPagoTransaccional(
        prestamoId: prestamoId,
        distribucion: liquidacion,
        detalle: 'Liquidación total del préstamo',
        fecha: 1722816000000, // 05-ago
      );

      // Comprobación final en la base de datos
      final prestamoFinal = await prestamoRepo.obtenerPorId(prestamoId);
      expect(prestamoFinal!.saldoActual.isLiquidado, isTrue);
      expect(prestamoFinal.estado, equals('liquidado'));

      // Verificar que el historial completo de movimientos tenga exactamente 6 entradas
      final historial = await prestamoRepo.obtenerMovimientos(prestamoId);
      expect(historial.length, equals(6));
    });
  });
}
