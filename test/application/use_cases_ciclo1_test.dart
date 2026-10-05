import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/application/use_cases/clientes/buscar_clientes_use_case.dart';
import 'package:pasaki/application/use_cases/clientes/registrar_cliente_use_case.dart';
import 'package:pasaki/application/use_cases/cobro/generar_ficha_cobro_use_case.dart';
import 'package:pasaki/application/use_cases/pagos/registrar_pago_use_case.dart';
import 'package:pasaki/application/use_cases/prestamos/crear_prestamo_use_case.dart';
import 'package:pasaki/application/use_cases/prestamos/desembolsar_adicional_use_case.dart';
import 'package:pasaki/application/use_cases/prestamos/devengar_intereses_use_case.dart';
import 'package:pasaki/core/domain/money.dart';
import 'package:pasaki/data/repositories/sqlite_cliente_repository.dart';
import 'package:pasaki/data/repositories/sqlite_prestamo_repository.dart';
import 'package:pasaki/domain/models/contacto.dart';
import 'package:pasaki/domain/models/periodo_tasa.dart';
import 'package:pasaki/domain/models/tasa_interes.dart';
import 'package:pasaki/domain/models/tipo_modalidad_interes.dart';
import 'package:pasaki/domain/models/tipo_movimiento.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SqliteClienteRepository clienteRepo;
  late SqlitePrestamoRepository prestamoRepo;

  late RegistrarClienteUseCase registrarCliente;
  late BuscarClientesUseCase buscarClientes;
  late CrearPrestamoUseCase crearPrestamo;
  late DesembolsarAdicionalUseCase desembolsarAdicional;
  late DevengarInteresesUseCase devengarIntereses;
  late RegistrarPagoUseCase registrarPago;
  late GenerarFichaCobroUseCase generarFichaCobro;

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

    clienteRepo = SqliteClienteRepository(db);
    prestamoRepo = SqlitePrestamoRepository(db);

    registrarCliente = RegistrarClienteUseCase(clienteRepo);
    buscarClientes = BuscarClientesUseCase(clienteRepo);
    crearPrestamo = CrearPrestamoUseCase(
      prestamoRepository: prestamoRepo,
      clienteRepository: clienteRepo,
    );
    desembolsarAdicional = DesembolsarAdicionalUseCase(prestamoRepo);
    devengarIntereses = DevengarInteresesUseCase(
      prestamoRepository: prestamoRepo,
    );
    registrarPago = RegistrarPagoUseCase(
      prestamoRepository: prestamoRepo,
    );
    generarFichaCobro = GenerarFichaCobroUseCase(
      prestamoRepository: prestamoRepo,
      clienteRepository: clienteRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Fase 3 - Casos de Uso del Ciclo 1 (Aplicación)', () {
    test('CU-01: RegistrarClienteUseCase valida campos y registra con contactos', () async {
      // 1. Falla si falta nombre
      expect(
        () => registrarCliente.execute(nombre: '   ', telefonoPrincipal: '70011223'),
        throwsA(isA<ArgumentError>()),
      );

      // 2. Registro exitoso
      final now = DateTime.now().millisecondsSinceEpoch;
      final cliente = await registrarCliente.execute(
        nombre: 'René',
        apellido: 'Vaca',
        alias: 'El mecánico',
        telefonoPrincipal: '70011223',
        contactosAdicionales: [
          Contacto(
            clienteId: 0,
            telefono: '79988776',
            etiqueta: 'Hermana',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(cliente.id, isNotNull);
      expect(cliente.nombreCompleto, equals('René Vaca'));
      expect(cliente.contactos.length, equals(1));
      expect(cliente.contactos.first.etiqueta, equals('Hermana'));

      // 3. Falla si intenta registrar cliente duplicado (mismo nombre y teléfono)
      expect(
        () => registrarCliente.execute(nombre: 'René', telefonoPrincipal: '70011223'),
        throwsA(isA<StateError>()),
      );
    });

    test('CU-01 / RF-27: BuscarClientesUseCase encuentra por alias o teléfono', () async {
      await registrarCliente.execute(
        nombre: 'María',
        alias: 'Doña Mary Verduras',
        telefonoPrincipal: '72233445',
      );

      final resultados = await buscarClientes.execute('Verduras');
      expect(resultados.length, equals(1));
      expect(resultados.first.nombre, equals('María'));
    });

    test('CU-04: CrearPrestamoUseCase valida lista negra y crea préstamo con desembolso', () async {
      final cliente = await registrarCliente.execute(
        nombre: 'Carlos',
        telefonoPrincipal: '78899001',
      );

      // Crear préstamo exitoso
      final prestamo = await crearPrestamo.execute(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(5000),
        tasa: const TasaInteres(porcentaje: 20.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
      );

      expect(prestamo.id, isNotNull);
      expect(prestamo.saldoActual.saldoCapital, equals(Money.fromBs(5000)));
      expect(prestamo.saldoActual.saldoInteres, equals(Money.zero));

      // Verificar que el movimiento inicial de desembolso esté registrado
      final movimientos = await prestamoRepo.obtenerMovimientos(prestamo.id!);
      expect(movimientos.length, equals(1));
      expect(movimientos.first.debe, equals(Money.fromBs(5000)));

      // Validar Lista Negra (RF-04)
      await clienteRepo.actualizar(cliente.copyWith(esListaNegra: true));
      expect(
        () => crearPrestamo.execute(
          clienteId: cliente.id!,
          capitalInicial: Money.fromBs(1000),
        ),
        throwsA(isA<StateError>()),
      );

      // Validar límites de seguridad en capital y tasa
      final clienteValido = await registrarCliente.execute(
        nombre: 'Pedro',
        telefonoPrincipal: '71122334',
      );
      expect(
        () => crearPrestamo.execute(
          clienteId: clienteValido.id!,
          capitalInicial: Money.fromBs(15000000),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => crearPrestamo.execute(
          clienteId: clienteValido.id!,
          capitalInicial: Money.fromBs(1000),
          tasa: const TasaInteres(porcentaje: 600.0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('CU-06: RegistrarPagoUseCase con distribución manual a capital (RF-16)', () async {
      final cliente = await registrarCliente.execute(
        nombre: 'Juan',
        telefonoPrincipal: '73344556',
      );

      final prestamo = await crearPrestamo.execute(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(3000),
      );

      // Devengar interés de 20% = 600 Bs
      await devengarIntereses.execute(prestamoId: prestamo.id!);

      // Pago acordado: 1000 Bs directo al capital y 0 a interés
      final distribucion = await registrarPago.execute(
        prestamoId: prestamo.id!,
        montoPagado: Money.fromBs(1000),
        montoACapital: Money.fromBs(1000),
        montoAInteres: Money.zero,
      );

      expect(distribucion.abonadoACapital, equals(Money.fromBs(1000)));
      expect(distribucion.abonadoAInteres, equals(Money.zero));
      expect(distribucion.nuevoSaldo.saldoCapital, equals(Money.fromBs(2000)));
      expect(distribucion.nuevoSaldo.saldoInteres, equals(Money.fromBs(600)));
      expect(distribucion.nuevoSaldo.totalDeuda, equals(Money.fromBs(2600)));
    });

    test('CU-08: GenerarFichaCobroUseCase genera datos, mensaje WhatsApp y alerta mora', () async {
      final cliente = await registrarCliente.execute(
        nombre: 'René',
        alias: 'Taller',
        telefonoPrincipal: '70011223',
      );

      final prestamo = await crearPrestamo.execute(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(4000),
      );

      // Devengar mes 1 (800 Bs interés)
      await devengarIntereses.execute(prestamoId: prestamo.id!);

      // Generar Ficha de Cobro
      final ficha = await generarFichaCobro.execute(
        prestamoId: prestamo.id!,
        qrDataPrestamista: 'assets/qr_prestamista.png',
        nombrePrestamista: 'Luberth Prestamista',
      );

      expect(ficha.clienteNombre, contains('René'));
      expect(ficha.saldoCapital, equals(Money.fromBs(4000)));
      expect(ficha.saldoInteres, equals(Money.fromBs(800)));
      expect(ficha.totalAPagar, equals(Money.fromBs(4800)));
      expect(ficha.tieneMora, isTrue); // RF-22: alerta de mora
      expect(ficha.qrData, equals('assets/qr_prestamista.png')); // RF-21

      // Verificar que el mensaje para WhatsApp tenga los datos desglosados
      expect(ficha.mensajeWhatsApp, contains('ESTADO DE CUENTA Y COBRO'));
      expect(ficha.mensajeWhatsApp, contains('Bs 4,800.00'));
      expect(ficha.mensajeWhatsApp, contains('Luberth Prestamista'));
    });

    test('CU-04 / RF-13: DesembolsarAdicionalUseCase consolida capital y registra en el libro mayor', () async {
      final cliente = await registrarCliente.execute(
        nombre: 'Sonia',
        apellido: 'Vaca',
        telefonoPrincipal: '75566778',
      );

      final prestamo = await crearPrestamo.execute(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(3000),
      );

      // Desembolsar 1,500 Bs adicionales
      await desembolsarAdicional.execute(
        prestamoId: prestamo.id!,
        monto: Money.fromBs(1500),
        nota: 'Compra de stock adicional',
      );

      final prestamoActualizado = await prestamoRepo.obtenerPorId(prestamo.id!);
      expect(prestamoActualizado!.saldoActual.saldoCapital, equals(Money.fromBs(4500)));

      // Verificar que se registró el movimiento de tipo desembolso
      final movimientos = await prestamoRepo.obtenerMovimientos(prestamo.id!);
      final desembolsos = movimientos.where((m) => m.tipo == TipoMovimiento.desembolso).toList();
      expect(desembolsos.length, equals(2)); // Inicial (3,000) + Adicional (1,500)
      expect(desembolsos.last.debe, equals(Money.fromBs(1500)));
      expect(desembolsos.last.detalle, equals('Compra de stock adicional'));
      expect(desembolsos.last.saldoCapitalResultante, equals(Money.fromBs(4500)));
    });
  });
}
