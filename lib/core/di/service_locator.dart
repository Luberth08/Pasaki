import 'package:sqflite/sqflite.dart';
import '../../application/use_cases/clientes/actualizar_cliente_use_case.dart';
import '../../application/use_cases/clientes/buscar_clientes_use_case.dart';
import '../../application/use_cases/clientes/eliminar_cliente_use_case.dart';
import '../../application/use_cases/clientes/registrar_cliente_use_case.dart';
import '../../application/use_cases/cobro/anular_ficha_cobro_use_case.dart';
import '../../application/use_cases/cobro/confirmar_ficha_cobro_use_case.dart';
import '../../application/use_cases/cobro/generar_ficha_cobro_use_case.dart';
import '../../application/use_cases/pagos/registrar_pago_use_case.dart';
import '../../application/use_cases/prestamos/crear_prestamo_use_case.dart';
import '../../application/use_cases/prestamos/desembolsar_adicional_use_case.dart';
import '../../application/use_cases/prestamos/devengar_intereses_use_case.dart';
import '../../application/use_cases/prestamos/verificar_y_devengar_automatico_use_case.dart';
import '../../data/datasources/app_database.dart';
import '../../data/repositories/sqlite_cliente_repository.dart';
import '../../data/repositories/sqlite_configuracion_repository.dart';
import '../../data/repositories/sqlite_ficha_cobro_repository.dart';
import '../../data/repositories/sqlite_perfil_repository.dart';
import '../../data/repositories/sqlite_prestamo_repository.dart';
import '../../domain/repositories/cliente_repository.dart';
import '../../domain/repositories/configuracion_repository.dart';
import '../../domain/repositories/ficha_cobro_repository.dart';
import '../../domain/repositories/perfil_repository.dart';
import '../../domain/repositories/prestamo_repository.dart';

/// Contenedor de dependencias centralizado y desacoplado (Service Locator).
class ServiceLocator {
  static late final Database db;

  // Repositorios
  static late final IClienteRepository clienteRepo;
  static late final IPrestamoRepository prestamoRepo;
  static late final IFichaCobroRepository fichaCobroRepo;
  static late final PerfilRepository perfilRepo;
  static late final IConfiguracionRepository configuracionRepo;

  // Casos de Uso
  static late final RegistrarClienteUseCase registrarCliente;
  static late final ActualizarClienteUseCase actualizarCliente;
  static late final EliminarClienteUseCase eliminarCliente;
  static late final BuscarClientesUseCase buscarClientes;
  static late final CrearPrestamoUseCase crearPrestamo;
  static late final DesembolsarAdicionalUseCase desembolsarAdicional;
  static late final DevengarInteresesUseCase devengarIntereses;
  static late final VerificarYDevengarAutomaticoUseCase verificarYDevengarAutomatico;
  static late final RegistrarPagoUseCase registrarPago;
  static late final GenerarFichaCobroUseCase generarFichaCobro;
  static late final ConfirmarFichaCobroUseCase confirmarFichaCobro;
  static late final AnularFichaCobroUseCase anularFichaCobro;

  /// Inicializa la base de datos y todas las capas de aplicación.
  static Future<void> initialize() async {
    db = await AppDatabase.instance;

    clienteRepo = SqliteClienteRepository(db);
    prestamoRepo = SqlitePrestamoRepository(db);
    fichaCobroRepo = SqliteFichaCobroRepository(db);
    perfilRepo = SqlitePerfilRepository(db);
    configuracionRepo = SqliteConfiguracionRepository(db);

    registrarCliente = RegistrarClienteUseCase(clienteRepo);
    actualizarCliente = ActualizarClienteUseCase(clienteRepo);
    eliminarCliente = EliminarClienteUseCase(
      clienteRepository: clienteRepo,
      prestamoRepository: prestamoRepo,
    );
    buscarClientes = BuscarClientesUseCase(clienteRepo);
    crearPrestamo = CrearPrestamoUseCase(
      prestamoRepository: prestamoRepo,
      clienteRepository: clienteRepo,
    );
    desembolsarAdicional = DesembolsarAdicionalUseCase(prestamoRepo);
    devengarIntereses = DevengarInteresesUseCase(
      prestamoRepository: prestamoRepo,
    );
    verificarYDevengarAutomatico = VerificarYDevengarAutomaticoUseCase(
      prestamoRepository: prestamoRepo,
      devengarInteresesUseCase: devengarIntereses,
    );
    registrarPago = RegistrarPagoUseCase(
      prestamoRepository: prestamoRepo,
    );
    generarFichaCobro = GenerarFichaCobroUseCase(
      prestamoRepository: prestamoRepo,
      clienteRepository: clienteRepo,
      fichaCobroRepository: fichaCobroRepo,
    );
    confirmarFichaCobro = ConfirmarFichaCobroUseCase(
      fichaCobroRepository: fichaCobroRepo,
      registrarPagoUseCase: registrarPago,
    );
    anularFichaCobro = AnularFichaCobroUseCase(fichaCobroRepo);
  }
}
