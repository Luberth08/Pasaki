import 'package:sqflite/sqflite.dart';
import '../../domain/repositories/configuracion_repository.dart';

/// Implementación SQLite para configuraciones del sistema.
class SqliteConfiguracionRepository implements IConfiguracionRepository {
  final Database db;

  static const String _tabla = 'configuraciones';
  static const String _claveTasa = 'tasa_interes_predeterminada';
  static const double _tasaDefault = 20.0;

  const SqliteConfiguracionRepository(this.db);

  @override
  Future<double> obtenerTasaPredeterminada() async {
    final rows = await db.query(
      _tabla,
      where: 'clave = ?',
      whereArgs: [_claveTasa],
    );

    if (rows.isEmpty) {
      return _tasaDefault;
    }

    final valorStr = rows.first['valor'] as String?;
    if (valorStr == null) return _tasaDefault;

    return double.tryParse(valorStr) ?? _tasaDefault;
  }

  @override
  Future<void> guardarTasaPredeterminada(double tasa) async {
    await db.insert(
      _tabla,
      {
        'clave': _claveTasa,
        'valor': tasa.toString(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
