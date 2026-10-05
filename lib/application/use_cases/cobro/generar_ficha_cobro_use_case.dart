import '../../../core/domain/money.dart';
import '../../../domain/models/ficha_cobro.dart';
import '../../../domain/repositories/cliente_repository.dart';
import '../../../domain/repositories/ficha_cobro_repository.dart';
import '../../../domain/repositories/prestamo_repository.dart';

/// Caso de Uso: Generar ficha resumida de cobro y preparar datos de pago QR (CU-08 / RF-20, RF-21, RF-22).
class GenerarFichaCobroUseCase {
  final IPrestamoRepository prestamoRepository;
  final IClienteRepository clienteRepository;
  final IFichaCobroRepository? fichaCobroRepository;

  const GenerarFichaCobroUseCase({
    required this.prestamoRepository,
    required this.clienteRepository,
    this.fichaCobroRepository,
  });

  Future<FichaCobro> execute({
    required int prestamoId,
    Money? montoCapital,
    Money? montoInteres,
    bool guardarEnHistorial = false,
    String? qrDataPrestamista,
    String? nombrePrestamista,
    String? bancoPrestamista,
    String? cuentaPrestamista,
  }) async {
    final prestamo = await prestamoRepository.obtenerPorId(prestamoId);
    if (prestamo == null) {
      throw StateError('El préstamo con ID $prestamoId no existe.');
    }

    final cliente = await clienteRepository.obtenerPorId(prestamo.clienteId);
    if (cliente == null) {
      throw StateError('El cliente asociado no existe.');
    }

    final saldo = prestamo.saldoActual;

    final cobroCap = montoCapital ?? saldo.saldoCapital;
    final cobroInt = montoInteres ?? saldo.saldoInteres;
    final cobroTotal = cobroCap + cobroInt;

    // Generar texto listo para compartir por WhatsApp (RF-20 / UX formal)
    final buffer = StringBuffer();
    buffer.writeln('*ESTADO DE CUENTA Y COBRO - PASAKI*');
    if (nombrePrestamista != null && nombrePrestamista.isNotEmpty) {
      buffer.writeln('*De:* $nombrePrestamista');
    }
    if (bancoPrestamista != null && bancoPrestamista.isNotEmpty) {
      buffer.writeln('*Banco:* $bancoPrestamista');
    }
    if (cuentaPrestamista != null && cuentaPrestamista.isNotEmpty) {
      buffer.writeln('*Cuenta:* $cuentaPrestamista');
    }
    buffer.writeln('*Cliente:* ${cliente.nombreVisual}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*Abono a Capital:*${cobroCap.formatBs()}');
    buffer.writeln('*Abono a Interés:*${cobroInt.formatBs()}');
    buffer.writeln('*TOTAL A TRANSFERIR:*${cobroTotal.formatBs()}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*Tasa:* ${prestamo.tasa.porcentaje}% ${prestamo.tasa.periodo.etiqueta.toLowerCase()}');
    buffer.writeln('*Podés transferir escaneando el código QR adjunto.*');

    final now = DateTime.now().millisecondsSinceEpoch;

    final ficha = FichaCobro(
      prestamoId: prestamoId,
      clienteNombre: cliente.nombreVisual,
      clienteTelefono: cliente.telefonoPrincipal,
      montoCapital: cobroCap,
      montoInteres: cobroInt,
      totalAPagar: cobroTotal,
      estado: 'pendiente',
      tasa: prestamo.tasa,
      modalidad: prestamo.modalidad,
      tieneMora: cobroInt.isPositive,
      qrData: qrDataPrestamista,
      mensajeWhatsApp: buffer.toString(),
      fechaEmision: now,
      createdAt: now,
      updatedAt: now,
    );

    if (guardarEnHistorial && fichaCobroRepository != null) {
      return await fichaCobroRepository!.guardar(ficha);
    }

    return ficha;
  }
}
