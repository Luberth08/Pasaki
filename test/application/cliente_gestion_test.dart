import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/application/use_cases/clientes/actualizar_cliente_use_case.dart';
import 'package:pasaki/application/use_cases/clientes/eliminar_cliente_use_case.dart';
import 'package:pasaki/application/use_cases/clientes/registrar_cliente_use_case.dart';
import 'package:pasaki/application/use_cases/prestamos/crear_prestamo_use_case.dart';
import 'package:pasaki/core/domain/money.dart';
import 'package:pasaki/data/repositories/sqlite_cliente_repository.dart';
import 'package:pasaki/data/repositories/sqlite_prestamo_repository.dart';
import 'package:pasaki/domain/models/contacto.dart';
import 'package:pasaki/domain/models/periodo_tasa.dart';
import 'package:pasaki/domain/models/tasa_interes.dart';
import 'package:pasaki/domain/models/tipo_modalidad_interes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SqliteClienteRepository clienteRepo;
  late SqlitePrestamoRepository prestamoRepo;
  late RegistrarClienteUseCase registrarCliente;
  late ActualizarClienteUseCase actualizarCliente;
  late EliminarClienteUseCase eliminarCliente;
  late CrearPrestamoUseCase crearPrestamo;

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
        },
      ),
    );

    clienteRepo = SqliteClienteRepository(db);
    prestamoRepo = SqlitePrestamoRepository(db);

    registrarCliente = RegistrarClienteUseCase(clienteRepo);
    actualizarCliente = ActualizarClienteUseCase(clienteRepo);
    eliminarCliente = EliminarClienteUseCase(
      clienteRepository: clienteRepo,
      prestamoRepository: prestamoRepo,
    );
    crearPrestamo = CrearPrestamoUseCase(
      prestamoRepository: prestamoRepo,
      clienteRepository: clienteRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CU-01: Gestión de Clientes (Editar y Eliminar)', () {
    test('Actualizar información personal y contactos secundarios exitosamente', () async {
      final cliente = await registrarCliente.execute(
        nombre: 'Carlos',
        apellido: 'Gutiérrez',
        alias: 'Carlitos',
        telefonoPrincipal: '70011223',
        ci: '1234567 CB',
        direccion: 'Av. América #100',
        contactosAdicionales: [
          Contacto(
            clienteId: 0,
            telefono: '70099887',
            etiqueta: 'Esposa',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
      );

      // Actualizar datos y reemplazar contactos
      final actualizado = await actualizarCliente.execute(
        id: cliente.id!,
        nombre: 'Carlos Eduardo',
        apellido: 'Gutiérrez Rojas',
        alias: 'Don Carlos',
        ci: '1234567 CB',
        telefonoPrincipal: '70011223',
        direccion: 'Calle Sucre #250',
        esListaNegra: true,
        contactos: [
          Contacto(
            clienteId: cliente.id!,
            telefono: '76655443',
            etiqueta: 'Hermano',
            createdAt: 2000,
            updatedAt: 2000,
          ),
          Contacto(
            clienteId: cliente.id!,
            telefono: '71122334',
            etiqueta: 'Taller',
            createdAt: 2000,
            updatedAt: 2000,
          ),
        ],
      );

      expect(actualizado.nombre, 'Carlos Eduardo');
      expect(actualizado.apellido, 'Gutiérrez Rojas');
      expect(actualizado.alias, 'Don Carlos');
      expect(actualizado.direccion, 'Calle Sucre #250');
      expect(actualizado.esListaNegra, isTrue);

      // Verificar persistencia en base de datos
      final enDb = await clienteRepo.obtenerPorId(cliente.id!);
      expect(enDb, isNotNull);
      expect(enDb!.nombreVisual, 'Carlos Eduardo Gutiérrez Rojas ("Don Carlos")');
      expect(enDb.esListaNegra, isTrue);
      expect(enDb.contactos.length, 2);
      expect(enDb.contactos.map((c) => c.telefono).toList(), containsAll(['76655443', '71122334']));
    });

    test('Validaciones de obligatoriedad y límites de longitud en campos', () async {
      final cliente = await registrarCliente.execute(
        nombre: 'Elena',
        telefonoPrincipal: '77788990',
      );

      // Nombre obligatorio
      expect(
        () => actualizarCliente.execute(
          id: cliente.id!,
          nombre: '',
          telefonoPrincipal: '77788990',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Teléfono obligatorio
      expect(
        () => actualizarCliente.execute(
          id: cliente.id!,
          nombre: 'Elena',
          telefonoPrincipal: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Nombre excede 50 caracteres
      expect(
        () => registrarCliente.execute(
          nombre: 'A' * 51,
          telefonoPrincipal: '70011223',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Teléfono excede 20 caracteres
      expect(
        () => registrarCliente.execute(
          nombre: 'Juan',
          telefonoPrincipal: '1' * 21,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Dirección excede 120 caracteres
      expect(
        () => registrarCliente.execute(
          nombre: 'Juan',
          telefonoPrincipal: '70011223',
          direccion: 'D' * 121,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Contacto secundario excede límite
      expect(
        () => registrarCliente.execute(
          nombre: 'Juan',
          telefonoPrincipal: '70011223',
          contactosAdicionales: [
            Contacto(
              clienteId: 0,
              telefono: '70011223',
              etiqueta: 'E' * 31,
              createdAt: 0,
              updatedAt: 0,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Eliminar cliente sin préstamos elimina físicamente al cliente y sus contactos', () async {
      final cliente = await registrarCliente.execute(
        nombre: 'Mario',
        telefonoPrincipal: '78899001',
        contactosAdicionales: [
          Contacto(
            clienteId: 0,
            telefono: '79900112',
            etiqueta: 'Hijo',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
      );

      // Verificar que existe
      expect(await clienteRepo.obtenerPorId(cliente.id!), isNotNull);

      // Eliminar cliente sin préstamos
      await eliminarCliente.execute(cliente.id!);

      // Verificar que ya no existe en la base de datos
      final borrado = await clienteRepo.obtenerPorId(cliente.id!);
      expect(borrado, isNull);

      // Verificar que los contactos fueron eliminados en cascada
      final contactosRes = await db.query(
        'contactos',
        where: 'cliente_id = ?',
        whereArgs: [cliente.id],
      );
      expect(contactosRes, isEmpty);
    });

    test('Eliminar cliente con préstamos está estrictamente prohibido y lanza StateError', () async {
      final cliente = await registrarCliente.execute(
        nombre: 'Rodrigo',
        telefonoPrincipal: '74455667',
      );

      // Crear un préstamo vinculado al cliente
      await crearPrestamo.execute(
        clienteId: cliente.id!,
        capitalInicial: Money.fromBs(1000),
        tasa: const TasaInteres(porcentaje: 10.0, periodo: PeriodoTasa.mensual),
        modalidad: TipoModalidadInteres.simple,
        fechaInicio: DateTime.now().millisecondsSinceEpoch,
      );

      // Intentar eliminar al cliente debe fallar por integridad contable
      expect(
        () => eliminarCliente.execute(cliente.id!),
        throwsA(isA<StateError>()),
      );

      // El cliente sigue existiendo
      expect(await clienteRepo.obtenerPorId(cliente.id!), isNotNull);
    });
  });
}
