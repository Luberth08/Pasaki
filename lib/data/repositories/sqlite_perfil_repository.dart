import 'package:sqflite/sqflite.dart';
import '../../domain/models/perfil_prestamista.dart';
import '../../domain/repositories/perfil_repository.dart';

class SqlitePerfilRepository implements PerfilRepository {
  final Database db;

  SqlitePerfilRepository(this.db);

  @override
  Future<PerfilPrestamista?> obtenerPerfil() async {
    final results = await db.query(
      'perfil_prestamista',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return PerfilPrestamista.fromMap(results.first);
  }

  @override
  Future<void> guardarPerfil(PerfilPrestamista perfil) async {
    await db.insert(
      'perfil_prestamista',
      perfil.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
