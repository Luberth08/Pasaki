import 'package:flutter_test/flutter_test.dart';
import 'package:pasaki/data/repositories/sqlite_perfil_repository.dart';
import 'package:pasaki/domain/models/perfil_prestamista.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SqlitePerfilRepository perfilRepo;

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
    perfilRepo = SqlitePerfilRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Guarda y recupera el perfil del prestamista con QR en base64', () async {
    // 1. Inicialmente no hay perfil
    final vacio = await perfilRepo.obtenerPerfil();
    expect(vacio, isNull);

    // 2. Guardar perfil con datos bancarios e imagen QR simulada
    const perfilOriginal = PerfilPrestamista(
      nombreTitular: 'Luberth Prestamista',
      banco: 'Banco Unión',
      numeroCuenta: '10000045678912',
      qrImageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      updatedAt: 1774000000,
    );

    await perfilRepo.guardarPerfil(perfilOriginal);

    // 3. Recuperar perfil
    final recuperado = await perfilRepo.obtenerPerfil();
    expect(recuperado, isNotNull);
    expect(recuperado!.id, 1);
    expect(recuperado.nombreTitular, 'Luberth Prestamista');
    expect(recuperado.banco, 'Banco Unión');
    expect(recuperado.numeroCuenta, '10000045678912');
    expect(recuperado.tieneQr, isTrue);
    expect(recuperado.qrImageBase64, perfilOriginal.qrImageBase64);

    // 4. Actualizar datos (upsert registro único id=1)
    final perfilActualizado = recuperado.copyWith(
      banco: 'Banco de Crédito BCP',
      numeroCuenta: '20000099887766',
    );
    await perfilRepo.guardarPerfil(perfilActualizado);

    final recuperadoV2 = await perfilRepo.obtenerPerfil();
    expect(recuperadoV2!.banco, 'Banco de Crédito BCP');
    expect(recuperadoV2.numeroCuenta, '20000099887766');
    expect(recuperadoV2.nombreTitular, 'Luberth Prestamista');
  });
}
