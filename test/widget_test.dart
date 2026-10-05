import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/core/di/service_locator.dart';
import 'package:pasaki/data/datasources/app_database.dart';
import 'package:pasaki/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final inMemoryDb = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
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
          await db.execute('''
            CREATE TABLE contactos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cliente_id INTEGER NOT NULL,
              telefono TEXT NOT NULL,
              etiqueta TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
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
              updated_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
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
              created_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
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
              updated_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
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
    AppDatabase.setCustomInstance(inMemoryDb);
    await ServiceLocator.initialize();
  });

  testWidgets('PasaKi App Smoke Test - Renderiza HomeScreen con titulo PasaKi', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PasakiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('PasaKi'), findsOneWidget);
    expect(find.text('Capital Prestado'), findsOneWidget);
    expect(find.text('Interés por Cobrar'), findsOneWidget);
  });
}
