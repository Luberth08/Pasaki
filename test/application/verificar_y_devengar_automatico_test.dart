import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/application/use_cases/prestamos/devengar_intereses_use_case.dart';
import 'package:pasaki/application/use_cases/prestamos/verificar_y_devengar_automatico_use_case.dart';
import 'package:pasaki/core/domain/money.dart';
import 'package:pasaki/data/datasources/app_database.dart';
import 'package:pasaki/data/repositories/sqlite_cliente_repository.dart';
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
  late DevengarInteresesUseCase devengarInteresesUseCase;
  late VerificarYDevengarAutomaticoUseCase automaticoUseCase;

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

    AppDatabase.setCustomInstance(db);
    clienteRepo = SqliteClienteRepository(db);
    prestamoRepo = SqlitePrestamoRepository(db);
    devengarInteresesUseCase = DevengarInteresesUseCase(prestamoRepository: prestamoRepo);
    automaticoUseCase = VerificarYDevengarAutomaticoUseCase(
      prestamoRepository: prestamoRepo,
      devengarInteresesUseCase: devengarInteresesUseCase,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Devengamiento automático no genera interés si el período no ha vencido', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'René', telefonoPrincipal: '70011223', createdAt: 0, updatedAt: 0),
    );

    final fechaInicio = DateTime(2026, 6, 1);
    await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(4000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    final hoy = DateTime(2026, 6, 15);
    final devengados = await automaticoUseCase.execute(fechaReferencia: hoy);

    expect(devengados, 0);

    final prestamos = await prestamoRepo.obtenerActivos();
    expect(prestamos.first.saldoActual.saldoInteres, Money.zero);
  });

  test('Devengamiento automático genera 1 período cuando se cumple exactamente 1 mes', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'René', telefonoPrincipal: '70011223', createdAt: 0, updatedAt: 0),
    );

    final fechaInicio = DateTime(2026, 6, 1);
    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(4000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    final hoy = DateTime(2026, 7, 1);
    final devengados = await automaticoUseCase.execute(fechaReferencia: hoy);

    expect(devengados, 1);

    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    expect(prestamoActualizado!.saldoActual.saldoInteres, Money.fromBs(800));
    expect(prestamoActualizado.saldoActual.saldoCapital, Money.fromBs(4000));

    final movimientos = await prestamoRepo.obtenerMovimientos(prestamo.id!);
    expect(movimientos.length, 2);
    expect(movimientos.last.tipo, TipoMovimiento.interesGenerado);
  });

  test('Devengamiento automático aplica catch-up si pasaron 2 meses sin abrir la app', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'René', telefonoPrincipal: '70011223', createdAt: 0, updatedAt: 0),
    );

    final fechaInicio = DateTime(2026, 6, 1);
    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(4000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    final hoy = DateTime(2026, 8, 2);
    final devengados = await automaticoUseCase.execute(fechaReferencia: hoy);

    expect(devengados, 2);

    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    expect(prestamoActualizado!.saldoActual.saldoInteres, Money.fromBs(1600));
    expect(prestamoActualizado.saldoActual.saldoCapital, Money.fromBs(4000));
    expect(prestamoActualizado.saldoActual.totalDeuda, Money.fromBs(5600));

    final devengadosSegundaVez = await automaticoUseCase.execute(fechaReferencia: hoy);
    expect(devengadosSegundaVez, 0);
  });

  test('Prorratear activo: inicio a mitad de mes cobra días exactos (16 días de 30)', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'René', telefonoPrincipal: '70011223', createdAt: 0, updatedAt: 0),
    );

    // Préstamo creado el 15 de junio con prorratear = true
    final fechaInicio = DateTime(2026, 6, 15);
    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(4000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        prorratearInteres: true,
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    // Al 1 de julio pasaron 16 días (15 de junio al 1 de julio)
    final hoy = DateTime(2026, 7, 1);
    final devengados = await automaticoUseCase.execute(fechaReferencia: hoy);

    expect(devengados, 1);

    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    // 800 Bs * (16 / 30) = 426.67 Bs -> redondeado 426.67 Bs (42667 cents)
    expect(prestamoActualizado!.saldoActual.saldoInteres.cents, 42667);
  });

  test('Prorratear desactivado: inicio a mitad de mes cobra cuota completa de 800 Bs', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'René', telefonoPrincipal: '70011223', createdAt: 0, updatedAt: 0),
    );

    // Préstamo creado el 15 de junio con prorratear = false (por defecto)
    final fechaInicio = DateTime(2026, 6, 15);
    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(4000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        prorratearInteres: false,
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    // Al 1 de julio pasaron 16 días
    final hoy = DateTime(2026, 7, 1);
    final devengados = await automaticoUseCase.execute(fechaReferencia: hoy);

    expect(devengados, 1);

    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    // Cuota completa sin prorratear = 800 Bs
    expect(prestamoActualizado!.saldoActual.saldoInteres, Money.fromBs(800));
  });

  test('FechaPrimerCorte personalizada: devenga en la fecha elegida y ajusta prorrateo', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'René', telefonoPrincipal: '70011223', createdAt: 0, updatedAt: 0),
    );

    // Préstamo creado el 15 de junio, pactan primer corte el 25 de junio (10 días)
    final fechaInicio = DateTime(2026, 6, 15);
    final primerCorte = DateTime(2026, 6, 25);
    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(4000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        prorratearInteres: true,
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        fechaPrimerCorte: primerCorte.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    // Al 25 de junio devenga exactamente en su fecha de primer corte
    final hoy = DateTime(2026, 6, 25);
    final devengados = await automaticoUseCase.execute(fechaReferencia: hoy);

    expect(devengados, 1);

    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    // 800 Bs * (10 días / 30 días) = 266.67 Bs -> 26667 cents
    expect(prestamoActualizado!.saldoActual.saldoInteres.cents, 26667);
  });

  test('Modalidad Compuesta con 3 meses de inactividad: capitaliza en orden secuencial cada mes', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'Pedro', telefonoPrincipal: '71122334', createdAt: 0, updatedAt: 0),
    );

    // Préstamo de Bs 1,000 al 20% mensual en modalidad compuesta
    final fechaInicio = DateTime(2026, 1, 1);
    final primerCorte = DateTime(2026, 2, 1);
    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(1000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(1000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.compuesto,
        prorratearInteres: false,
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        fechaPrimerCorte: primerCorte.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    // Han pasado 3 meses completos sin abrir la app (15 de abril)
    final hoy = DateTime(2026, 4, 15);
    final devengados = await automaticoUseCase.execute(fechaReferencia: hoy);

    expect(devengados, 3);

    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    // Mes 1: Cap 1,000 + Int 200 (Total 1,200)
    // Mes 2: Capitaliza a Cap 1,200 + Int 240 (Total 1,440)
    // Mes 3: Capitaliza a Cap 1,440 + Int 288 (Total 1,728)
    expect(prestamoActualizado!.saldoActual.saldoCapital, Money.fromBs(1440));
    expect(prestamoActualizado.saldoActual.saldoInteres, Money.fromBs(288));
    expect(prestamoActualizado.saldoActual.totalDeuda, Money.fromBs(1728));

    // Verificar que los 3 movimientos en el libro contable se guardaron con fechas y saldos secuenciales correctos
    final movimientos = await prestamoRepo.obtenerMovimientos(prestamo.id!);
    final devengamientos = movimientos.where((m) => m.tipo == TipoMovimiento.interesGenerado).toList();
    expect(devengamientos.length, 3);

    // Movimiento 1 (1 de Febrero)
    expect(devengamientos[0].fecha, DateTime(2026, 2, 1).millisecondsSinceEpoch);
    expect(devengamientos[0].saldoCapitalResultante, Money.fromBs(1000));
    expect(devengamientos[0].saldoInteresResultante, Money.fromBs(200));

    // Movimiento 2 (1 de Marzo)
    expect(devengamientos[1].fecha, DateTime(2026, 3, 1).millisecondsSinceEpoch);
    expect(devengamientos[1].saldoCapitalResultante, Money.fromBs(1200));
    expect(devengamientos[1].saldoInteresResultante, Money.fromBs(240));

    // Movimiento 3 (1 de Abril)
    expect(devengamientos[2].fecha, DateTime(2026, 4, 1).millisecondsSinceEpoch);
    expect(devengamientos[2].saldoCapitalResultante, Money.fromBs(1440));
    expect(devengamientos[2].saldoInteresResultante, Money.fromBs(288));
  });

  test('Desembolso adicional con prorrateo: calcula el interés por tramos exactos de días', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'Carlos', telefonoPrincipal: '72233445', createdAt: 0, updatedAt: 0),
    );

    // Préstamo de 2,000 Bs al 20% mensual con prorrateo activo
    // Inicia el 1 de Mayo, corte el 31 de Mayo (30 días de diferencia)
    final fechaInicio = DateTime(2026, 5, 1);
    final fechaCorte = DateTime(2026, 5, 31);

    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(2000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(2000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        prorratearInteres: true,
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        fechaPrimerCorte: fechaCorte.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    // El 16 de Mayo (faltando exactamente 15 días para el 31), se desembolsan 1,000 Bs más
    final fechaDesembolsoAdicional = DateTime(2026, 5, 16);
    await prestamoRepo.registrarDesembolsoAdicionalTransaccional(
      prestamoId: prestamo.id!,
      montoAdicional: Money.fromBs(1000),
      detalle: 'Ampliación de mercadería',
      fecha: fechaDesembolsoAdicional.millisecondsSinceEpoch,
    );

    // Llegamos al día de corte (31 de Mayo)
    final devengados = await automaticoUseCase.execute(fechaReferencia: DateTime(2026, 5, 31));
    expect(devengados, 1);

    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    // Saldo Capital total debe ser 3,000 Bs
    expect(prestamoActualizado!.saldoActual.saldoCapital, Money.fromBs(3000));

    // Interés por tramos:
    // Base 2,000 Bs * 20% = 400 Bs (30 días de 30)
    // Adicional 1,000 Bs * 20% * (15 días / 30 días) = 100 Bs
    // Total interés generado = 500 Bs
    expect(prestamoActualizado.saldoActual.saldoInteres, Money.fromBs(500));
    expect(prestamoActualizado.saldoActual.totalDeuda, Money.fromBs(3500));
  });

  test('Desembolso adicional con prorrateo DESACTIVADO: calcula interés sobre el capital total consolidado', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'María', telefonoPrincipal: '73344556', createdAt: 0, updatedAt: 0),
    );

    // Préstamo de 2,000 Bs al 20% mensual SIN prorrateo
    final fechaInicio = DateTime(2026, 5, 1);
    final fechaCorte = DateTime(2026, 5, 31);

    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(2000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(2000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        prorratearInteres: false, // SIN prorrateo
        fechaInicio: fechaInicio.millisecondsSinceEpoch,
        fechaPrimerCorte: fechaCorte.millisecondsSinceEpoch,
        createdAt: fechaInicio.millisecondsSinceEpoch,
        updatedAt: fechaInicio.millisecondsSinceEpoch,
      ),
    );

    // Desembolso adicional de 1,000 Bs el 16 de Mayo
    await prestamoRepo.registrarDesembolsoAdicionalTransaccional(
      prestamoId: prestamo.id!,
      montoAdicional: Money.fromBs(1000),
      detalle: 'Aumento de capital',
      fecha: DateTime(2026, 5, 16).millisecondsSinceEpoch,
    );

    // Devengamiento al 31 de Mayo
    final devengados = await automaticoUseCase.execute(fechaReferencia: DateTime(2026, 5, 31));
    expect(devengados, 1);

    final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
    // Saldo Capital: 3,000 Bs
    expect(prestamoActualizado!.saldoActual.saldoCapital, Money.fromBs(3000));
    // Sin prorrateo: 20% directo de 3,000 Bs = 600 Bs
    expect(prestamoActualizado.saldoActual.saldoInteres, Money.fromBs(600));
    expect(prestamoActualizado.saldoActual.totalDeuda, Money.fromBs(3600));
  });

  test('Caso real semanal con prorrateo: 1000 Bs el 30/Sep + 200 Bs mismo día + 300 Bs el 03/Oct = 274.29 Bs al 07/Oct', () async {
    final cliente = await clienteRepo.crear(
      Cliente(nombre: 'Carlos', telefonoPrincipal: '71122334', createdAt: 0, updatedAt: 0),
    );

    // 1000 Bs el 30 de septiembre, 20% compuesto semanal, prorrateo activo
    final dtDesembolso = DateTime(2026, 9, 30, 10, 0, 0);
    final fechaPrimerCorte = DateTime(2026, 10, 7, 0, 0, 0);

    final prestamo = await prestamoRepo.crearConDesembolso(
      Prestamo(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(1000),
        saldoActual: SaldoCuenta(saldoCapital: Money.fromBs(1000), saldoInteres: Money.zero),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.semanal),
        modalidad: TipoModalidadInteres.compuesto,
        prorratearInteres: true,
        fechaInicio: dtDesembolso.millisecondsSinceEpoch,
        fechaPrimerCorte: fechaPrimerCorte.millisecondsSinceEpoch,
        createdAt: dtDesembolso.millisecondsSinceEpoch,
        updatedAt: dtDesembolso.millisecondsSinceEpoch,
      ),
    );

    // 200 Bs el mismo día (30 de septiembre)
    await prestamoRepo.registrarDesembolsoAdicionalTransaccional(
      prestamoId: prestamo.id!,
      montoAdicional: Money.fromBs(200),
      fecha: DateTime(2026, 9, 30, 15, 0, 0).millisecondsSinceEpoch,
      detalle: 'Desembolso adicional 200',
    );

    // 300 Bs el 3 de octubre
    await prestamoRepo.registrarDesembolsoAdicionalTransaccional(
      prestamoId: prestamo.id!,
      montoAdicional: Money.fromBs(300),
      fecha: DateTime(2026, 10, 3, 10, 0, 0).millisecondsSinceEpoch,
      detalle: 'Desembolso adicional 300',
    );

    // Al 7 de octubre
    final devengados = await automaticoUseCase.execute(fechaReferencia: DateTime(2026, 10, 7, 10, 0, 0));
    expect(devengados, 1);

    final prestamoFinal = await prestamoRepo.obtenerPorId(prestamo.id!);
    expect(prestamoFinal!.saldoActual.saldoCapital, Money.fromBs(1500));
    // Base 1200 Bs por 7 días = 240 Bs. Extra 300 Bs por 4 días = 34.29 Bs. Total = 274.29 Bs
    expect(prestamoFinal.saldoActual.saldoInteres, Money.fromBs(274.29));
    expect(prestamoFinal.saldoActual.totalDeuda, Money.fromBs(1774.29));
  });
}
