import '../../../core/domain/money.dart';
import '../../../domain/models/prestamo.dart';
import '../../../domain/models/saldo_cuenta.dart';
import '../../../domain/models/tasa_interes.dart';
import '../../../domain/models/tipo_modalidad_interes.dart';
import '../../../domain/repositories/cliente_repository.dart';
import '../../../domain/repositories/prestamo_repository.dart';

/// Caso de Uso: Registrar y desembolsar un nuevo préstamo (CU-04 / RF-07, RF-08, RF-10, RF-11).
class CrearPrestamoUseCase {
  final IPrestamoRepository prestamoRepository;
  final IClienteRepository clienteRepository;

  const CrearPrestamoUseCase({
    required this.prestamoRepository,
    required this.clienteRepository,
  });

  Future<Prestamo> execute({
    required int clienteId,
    required Money capitalInicial,
    TasaInteres tasa = TasaInteres.estandarDefecto,
    TipoModalidadInteres modalidad = TipoModalidadInteres.simple,
    bool prorratearInteres = false,
    int? fechaInicio,
    int? fechaPrimerCorte,
  }) async {
    // 1. Validar existencia del cliente
    final cliente = await clienteRepository.obtenerPorId(clienteId);
    if (cliente == null) {
      throw StateError('El cliente especificado no existe.');
    }

    // 2. Validar que no esté en Lista Negra (RF-04)
    if (cliente.esListaNegra) {
      throw StateError(
        'El cliente "${cliente.nombreVisual}" se encuentra en Lista Negra. No se permiten nuevos préstamos.',
      );
    }

    // 3. Validar monto de capital
    if (!capitalInicial.isPositive) {
      throw ArgumentError('El monto de capital inicial debe ser mayor a cero.');
    }
    if (capitalInicial.cents > 1000000000) {
      throw ArgumentError('El capital inicial no puede superar los Bs 10,000,000.00.');
    }

    // 4. Validar tasa de interés
    if (tasa.porcentaje < 0 || tasa.porcentaje > 500) {
      throw ArgumentError('La tasa de interés debe estar entre 0% y 500%.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final fechaOperacion = fechaInicio ?? now;

    // 4. Construir la entidad con saldos iniciales separados (RF-11)
    final nuevoPrestamo = Prestamo(
      clienteId: clienteId,
      capitalInicial: capitalInicial,
      tasa: tasa,
      modalidad: modalidad,
      prorratearInteres: prorratearInteres,
      saldoActual: SaldoCuenta(
        saldoCapital: capitalInicial,
        saldoInteres: Money.zero,
      ),
      fechaInicio: fechaOperacion,
      fechaPrimerCorte: fechaPrimerCorte,
      createdAt: now,
      updatedAt: now,
    );

    // 5. Persistir atómicamente con el movimiento de desembolso
    return await prestamoRepository.crearConDesembolso(nuevoPrestamo);
  }
}
