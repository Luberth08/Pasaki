import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/application/use_cases/cobro/anular_ficha_cobro_use_case.dart';
import 'package:pasaki/application/use_cases/cobro/confirmar_ficha_cobro_use_case.dart';
import 'package:pasaki/application/use_cases/cobro/generar_ficha_cobro_use_case.dart';
import 'package:pasaki/application/use_cases/pagos/registrar_pago_use_case.dart';
import 'package:pasaki/core/domain/money.dart';
import 'package:pasaki/data/datasources/app_database.dart';
import 'package:pasaki/data/repositories/sqlite_cliente_repository.dart';
import 'package:pasaki/data/repositories/sqlite_ficha_cobro_repository.dart';
import 'package:pasaki/data/repositories/sqlite_prestamo_repository.dart';
import 'package:pasaki/domain/models/cliente.dart';
import 'package:pasaki/domain/models/periodo_tasa.dart';
import 'package:pasaki/domain/models/prestamo.dart';
import 'package:pasaki/domain/models/saldo_cuenta.dart';
import 'package:pasaki/domain/models/tasa_interes.dart';
import 'package:pasaki/domain/models/tipo_modalidad_interes.dart';
import 'package:pasaki/domain/models/tipo_movimiento.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SqliteClienteRepository clienteRepo;
  late SqlitePrestamoRepository prestamoRepo;
  late SqliteFichaCobroRepository fichaRepo;
  late RegistrarPagoUseCase registrarPagoUseCase;
  late GenerarFichaCobroUseCase generarFichaCobroUseCase;
  late ConfirmarFichaCobroUseCase confirmarFichaCobroUseCase;
  late AnularFichaCobroUseCase anularFichaCobroUseCase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
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
          await database.execute('''
            CREATE TABLE fichas_cobro (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              prestamo_id INTEGER NOT NULL,
              cliente_nombre TEXT NOT NULL,
              cliente_telefono TEXT NOT NULL,
              monto_capital_cents INTEGER NOT NULL,
              monto_interes_cents INTEGER NOT NULL,
              monto_total_cents INTEGER NOT NULL,
              estado TEXT NOT NULL DEFAULT 'pendiente',
              mensaje_whatsapp TEXT NOT NULL,
              qr_data TEXT,
              fecha_emision INTEGER NOT NULL,
              fecha_cobro INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              FOREIGN KEY (prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
            );
          ''');
          await database.execute('''
            CREATE TABLE perfil_prestamista (
              id INTEGER PRIMARY KEY,
              nombre_titular TEXT NOT NULL,
              banco TEXT,
              numero_cuenta TEXT,
              qr_image_base64 TEXT,
              updated_at INTEGER NOT NULL
            );
          ''');
        },
      ),
    );

    AppDatabase.setCustomInstance(db);
    clienteRepo = SqliteClienteRepository(db);
    prestamoRepo = SqlitePrestamoRepository(db);
    fichaRepo = SqliteFichaCobroRepository(db);
    registrarPagoUseCase = RegistrarPagoUseCase(prestamoRepository: prestamoRepo);
    generarFichaCobroUseCase = GenerarFichaCobroUseCase(
      prestamoRepository: prestamoRepo,
      clienteRepository: clienteRepo,
      fichaCobroRepository: fichaRepo,
    );
    confirmarFichaCobroUseCase = ConfirmarFichaCobroUseCase(
      fichaCobroRepository: fichaRepo,
      registrarPagoUseCase: registrarPagoUseCase,
    );
    anularFichaCobroUseCase = AnularFichaCobroUseCase(fichaRepo);
  });

  tearDown(() async {
    await db.close();
  });

  test('Ciclo Completo: Generar Ficha QR, guardar como pendiente y confirmar cobro en el libro', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'René', telefonoPrincipal: '70011223', createdAt: 0, updatedAt: 0),
    );

    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(4000), saldoInteres: Money.fromBs(800)),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        fechaInicio: DateTime(2026, 6, 1).millisecondsSinceEpoch,
        createdAt: DateTime(2026, 6, 1).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 6, 1).millisecondsSinceEpoch,
      ),
    );

    // 1. Prestamista genera y guarda Ficha de Cobro de 500 Bs (300 a interés, 200 a capital)
    final ficha = await generarFichaCobroUseCase.execute(
      prestamoId: prestamo.id!,
      montoInteres: Money.fromBs(300),
      montoCapital: Money.fromBs(200),
      guardarEnHistorial: true,
    );

    expect(ficha.id, isNotNull);
    expect(ficha.isPendiente, isTrue);
    expect(ficha.totalAPagar, Money.fromBs(500));
    expect(ficha.mensajeWhatsApp, contains('*TOTAL A TRANSFERIR:* Bs 500.00'));

    // Verificar en BD que está pendiente
    final pendientes = await fichaRepo.obtenerPendientesPorPrestamo(prestamo.id!);
    expect(pendientes.length, 1);
    expect(pendientes.first.id, ficha.id);

    // 2. René transfiere la plata y el prestamista confirma la ficha
    await confirmarFichaCobroUseCase.execute(fichaId: ficha.id!);

    // Verificar ficha actualizada a 'cobrada'
    final fichaActualizada = await fichaRepo.obtenerPorId(ficha.id!);
    expect(fichaActualizada!.isCobrada, isTrue);
    expect(fichaActualizada.fechaCobro, isNotNull);

    // Verificar impacto atómico en el libro contable de movimientos
    final movimientos = await prestamoRepo.obtenerMovimientos(prestamo.id!);
    expect(movimientos.length, 2); // Desembolso inicial + Cobro Ficha
    final ultimoMovimiento = movimientos.last;
    expect(ultimoMovimiento.tipo, TipoMovimiento.pago);
    expect(ultimoMovimiento.haber, Money.fromBs(500));
    expect(ultimoMovimiento.saldoInteresResultante, Money.fromBs(500)); // 800 - 300
    expect(ultimoMovimiento.saldoCapitalResultante, Money.fromBs(3800)); // 4000 - 200

    // Verificar saldo del préstamo en tabla 'prestamos'
    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    expect(prestamoActualizado!.saldoActual.saldoInteres, Money.fromBs(500));
    expect(prestamoActualizado.saldoActual.saldoCapital, Money.fromBs(3800));
    expect(prestamoActualizado.saldoActual.totalDeuda, Money.fromBs(4300));
  });

  test('Anular Ficha de Cobro pendiente no altera el libro contable', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'René', telefonoPrincipal: '70011223', createdAt: 0, updatedAt: 0),
    );

    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(4000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        fechaInicio: DateTime(2026, 6, 1).millisecondsSinceEpoch,
        createdAt: DateTime(2026, 6, 1).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 6, 1).millisecondsSinceEpoch,
      ),
    );

    final ficha = await generarFichaCobroUseCase.execute(
      prestamoId: prestamo.id!,
      montoInteres: Money.zero,
      montoCapital: Money.fromBs(500),
      guardarEnHistorial: true,
    );

    expect(ficha.isPendiente, isTrue);

    // Anular
    await anularFichaCobroUseCase.execute(ficha.id!);

    final fichaActualizada = await fichaRepo.obtenerPorId(ficha.id!);
    expect(fichaActualizada!.isAnulada, isTrue);

    // Los movimientos solo tienen el desembolso inicial
    final movimientos = await prestamoRepo.obtenerMovimientos(prestamo.id!);
    expect(movimientos.length, 1);
  });
}
