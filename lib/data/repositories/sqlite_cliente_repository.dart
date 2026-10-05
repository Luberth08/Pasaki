import 'package:sqflite/sqflite.dart';
import '../../domain/models/cliente.dart';
import '../../domain/models/contacto.dart';
import '../../domain/repositories/cliente_repository.dart';

class SqliteClienteRepository implements IClienteRepository {
  final Database db;

  const SqliteClienteRepository(this.db);

  @override
  Future<Cliente> crear(Cliente cliente) async {
    return await db.transaction((txn) async {
      final id = await txn.insert('clientes', cliente.toMap());

      for (final contacto in cliente.contactos) {
        await txn.insert('contactos', {
          ...contacto.toMap(),
          'cliente_id': id,
        });
      }

      return cliente.copyWith(id: id);
    });
  }

  @override
  Future<void> actualizar(Cliente cliente) async {
    if (cliente.id == null) return;
    await db.transaction((txn) async {
      await txn.update(
        'clientes',
        cliente.toMap(),
        where: 'id = ?',
        whereArgs: [cliente.id],
      );

      // Sincronizar contactos secundarios
      await txn.delete(
        'contactos',
        where: 'cliente_id = ?',
        whereArgs: [cliente.id],
      );
      for (final contacto in cliente.contactos) {
        await txn.insert(
          'contactos',
          contacto.copyWith(clienteId: cliente.id).toMap(),
        );
      }
    });
  }

  @override
  Future<Cliente?> obtenerPorId(int id) async {
    final results = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final contactosResults = await db.query(
      'contactos',
      where: 'cliente_id = ?',
      whereArgs: [id],
    );

    final contactos = contactosResults.map((c) => Contacto.fromMap(c)).toList();
    return Cliente.fromMap(results.first, contactos: contactos);
  }

  @override
  Future<List<Cliente>> obtenerTodos() async {
    final results = await db.query('clientes', orderBy: 'nombre ASC');
    final List<Cliente> lista = [];

    for (final row in results) {
      final id = row['id'] as int;
      final contactosResults = await db.query(
        'contactos',
        where: 'cliente_id = ?',
        whereArgs: [id],
      );
      final contactos = contactosResults.map((c) => Contacto.fromMap(c)).toList();
      lista.add(Cliente.fromMap(row, contactos: contactos));
    }

    return lista;
  }

  @override
  Future<List<Cliente>> buscar(String query) async {
    final q = '%${query.trim()}%';
    final results = await db.query(
      'clientes',
      where: 'nombre LIKE ? OR apellido LIKE ? OR alias LIKE ? OR telefono_principal LIKE ?',
      whereArgs: [q, q, q, q],
      orderBy: 'nombre ASC',
    );

    final List<Cliente> lista = [];
    for (final row in results) {
      final id = row['id'] as int;
      final contactosResults = await db.query(
        'contactos',
        where: 'cliente_id = ?',
        whereArgs: [id],
      );
      final contactos = contactosResults.map((c) => Contacto.fromMap(c)).toList();
      lista.add(Cliente.fromMap(row, contactos: contactos));
    }

    return lista;
  }

  @override
  Future<void> eliminar(int id) async {
    await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Contacto> agregarContacto(Contacto contacto) async {
    final id = await db.insert('contactos', contacto.toMap());
    return contacto.copyWith(id: id);
  }

  @override
  Future<void> eliminarContacto(int contactoId) async {
    await db.delete('contactos', where: 'id = ?', whereArgs: [contactoId]);
  }
}
