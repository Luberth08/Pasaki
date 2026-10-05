import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/data/repositories/sqlite_configuracion_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SqliteConfiguracionRepository configuracionRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE configuraciones (
              clave TEXT PRIMARY KEY,
              valor TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
        },
      ),
    );

    configuracionRepo = SqliteConfiguracionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Retorna tasa predeterminada 20.0 por defecto cuando no hay nada configurado', () async {
    final tasa = await configuracionRepo.obtenerTasaPredeterminada();
    expect(tasa, 20.0);
  });

  test('Guarda y recupera una nueva tasa predeterminada', () async {
    await configuracionRepo.guardarTasaPredeterminada(15.5);
    final tasa = await configuracionRepo.obtenerTasaPredeterminada();
    expect(tasa, 15.5);

    // Sobrescribir
    await configuracionRepo.guardarTasaPredeterminada(10.0);
    final tasaActualizada = await configuracionRepo.obtenerTasaPredeterminada();
    expect(tasaActualizada, 10.0);
  });
}
