import 'package:sqflite/sqflite.dart';
import '../../domain/models/ficha_cobro.dart';
import '../../domain/repositories/ficha_cobro_repository.dart';

class SqliteFichaCobroRepository implements IFichaCobroRepository {
  final Database db;

  const SqliteFichaCobroRepository(this.db);

  @override
  Future<FichaCobro> guardar(FichaCobro ficha) async {
    final id = await db.insert('fichas_cobro', ficha.toMap());
    return ficha.copyWith(id: id);
  }

  @override
  Future<List<FichaCobro>> obtenerPorPrestamo(int prestamoId) async {
    final rows = await db.query(
      'fichas_cobro',
      where: 'prestamo_id = ?',
      whereArgs: [prestamoId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => FichaCobro.fromMap(r)).toList();
  }

  @override
  Future<List<FichaCobro>> obtenerPendientesPorPrestamo(int prestamoId) async {
    final rows = await db.query(
      'fichas_cobro',
      where: 'prestamo_id = ? AND estado = ?',
      whereArgs: [prestamoId, 'pendiente'],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => FichaCobro.fromMap(r)).toList();
  }

  @override
  Future<FichaCobro?> obtenerPorId(int id) async {
    final rows = await db.query(
      'fichas_cobro',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FichaCobro.fromMap(rows.first);
  }

  @override
  Future<void> actualizarEstado(int fichaId, String estado, {int? fechaCobro}) async {
    await db.update(
      'fichas_cobro',
      {
        'estado': estado,
        'fecha_cobro': ?fechaCobro,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [fichaId],
    );
  }

  @override
  Future<int> contarPendientesPorPrestamo(int prestamoId) async {
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM fichas_cobro WHERE prestamo_id = ? AND estado = ?',
      [prestamoId, 'pendiente'],
    ));
    return count ?? 0;
  }
}
