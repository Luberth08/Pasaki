import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Gestor de base de datos relacional SQLite local con soporte ACID y claves foráneas.
class AppDatabase {
  static Database? _instance;
  static const String _dbName = 'pasaki_local.db';
  static const int _dbVersion = 1;

  /// Obtiene la instancia activa de la base de datos (Singleton).
  static Future<Database> get instance async {
    if (_instance != null && _instance!.isOpen) {
      return _instance!;
    }
    _instance = await _initDatabase();
    return _instance!;
  }

  /// Permite inyectar una base de datos específica (ej: para pruebas unitarias con ffi/in-memory).
  static void setCustomInstance(Database db) {
    _instance = db;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE prestamos ADD COLUMN prorratear_interes INTEGER NOT NULL DEFAULT 0;');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE prestamos ADD COLUMN fecha_primer_corte INTEGER;');
        } catch (_) {}
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS fichas_cobro (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              prestamo_id INTEGER NOT NULL,
              cliente_nombre TEXT NOT NULL,
              cliente_telefono TEXT NOT NULL,
              monto_capital_cents INTEGER NOT NULL,
              monto_interes_cents INTEGER NOT NULL,
              monto_total_cents INTEGER NOT NULL,
              estado TEXT NOT NULL DEFAULT 'pendiente',
              mensaje_whatsapp TEXT NOT NULL,
              fecha_emision INTEGER NOT NULL,
              fecha_cobro INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              FOREIGN KEY (prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
            );
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_fichas_prestamo ON fichas_cobro(prestamo_id, estado);');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE fichas_cobro ADD COLUMN qr_data TEXT;');
        } catch (_) {}
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS perfil_prestamista (
              id INTEGER PRIMARY KEY,
              nombre_titular TEXT NOT NULL,
              banco TEXT,
              numero_cuenta TEXT,
              qr_image_base64 TEXT,
              updated_at INTEGER NOT NULL
            );
          ''');
        } catch (_) {}
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS configuraciones (
              clave TEXT PRIMARY KEY,
              valor TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
        } catch (_) {}
      },
    );
  }

  static Future<void> _onConfigure(Database db) async {
    // Activa la integridad referencial de claves foráneas en SQLite
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Tabla Clientes
    batch.execute('''
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
    batch.execute(
      'CREATE INDEX idx_clientes_busqueda ON clientes(nombre, alias, telefono_principal);',
    );

    // 2. Tabla Contactos
    batch.execute('''
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
    batch.execute('CREATE INDEX idx_contactos_cliente ON contactos(cliente_id);');

    // 3. Tabla Garantes (Garantía Social)
    batch.execute('''
      CREATE TABLE garantes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deudor_id INTEGER NOT NULL,
        garante_cliente_id INTEGER NOT NULL,
        relacion TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (deudor_id) REFERENCES clientes(id) ON DELETE CASCADE,
        FOREIGN KEY (garante_cliente_id) REFERENCES clientes(id) ON DELETE RESTRICT
      );
    ''');

    // 4. Tabla Préstamos
    batch.execute('''
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
    batch.execute('CREATE INDEX idx_prestamos_cliente ON prestamos(cliente_id);');
    batch.execute('CREATE INDEX idx_prestamos_estado ON prestamos(estado);');

    // 5. Tabla Garantías Prendarias
    batch.execute('''
      CREATE TABLE garantias_prendarias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prestamo_id INTEGER NOT NULL,
        descripcion TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
      );
    ''');
    batch.execute(
      'CREATE INDEX idx_garantias_prestamo ON garantias_prendarias(prestamo_id);',
    );

    // 6. Tabla Movimientos (Ledger contable inalterable)
    batch.execute('''
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
    batch.execute(
      'CREATE INDEX idx_movimientos_prestamo ON movimientos(prestamo_id, fecha);',
    );

    // 7. Tabla Fichas de Cobro (Intenciones de Cobro / Solicitudes QR)
    batch.execute('''
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
    batch.execute(
      'CREATE INDEX idx_fichas_prestamo ON fichas_cobro(prestamo_id, estado);',
    );

    // 8. Tabla Perfil Prestamista (Registro único id=1)
    batch.execute('''
      CREATE TABLE perfil_prestamista (
        id INTEGER PRIMARY KEY,
        nombre_titular TEXT NOT NULL,
        banco TEXT,
        numero_cuenta TEXT,
        qr_image_base64 TEXT,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 9. Tabla Configuraciones Generales
    batch.execute('''
      CREATE TABLE configuraciones (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await batch.commit(noResult: true);
  }

  /// Cierra la conexión de la base de datos si está abierta.
  static Future<void> close() async {
    if (_instance != null && _instance!.isOpen) {
      await _instance!.close();
      _instance = null;
    }
  }
}
