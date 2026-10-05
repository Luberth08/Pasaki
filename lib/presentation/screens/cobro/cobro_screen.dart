import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/money.dart';
import '../../../core/services/compartir_ficha_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/ficha_cobro.dart';
import '../../../domain/models/perfil_prestamista.dart';
import '../../../domain/models/prestamo.dart';
import '../perfil/perfil_screen.dart';

class CobroScreen extends StatefulWidget {
  final Prestamo prestamo;

  const CobroScreen({super.key, required this.prestamo});

  @override
  State<CobroScreen> createState() => _CobroScreenState();
}

class _CobroScreenState extends State<CobroScreen> {
  late Prestamo _prestamo;
  PerfilPrestamista? _perfil;
  bool _cargando = true;

  final _montoTotalCtrl = TextEditingController();
  final _montoCapitalCtrl = TextEditingController();
  final _montoInteresCtrl = TextEditingController();

  bool _procesandoGuardado = false;

  @override
  void initState() {
    super.initState();
    _prestamo = widget.prestamo;
    final saldo = _prestamo.saldoActual;
    // Precarga inteligente: Si hay interés exigible acumulado, se sugiere abonar el interés
    if (saldo.saldoInteres.isPositive) {
      _montoInteresCtrl.text = saldo.saldoInteres.toBs().toStringAsFixed(0);
      _montoCapitalCtrl.text = '0';
    } else {
      _montoInteresCtrl.text = '0';
      _montoCapitalCtrl.text = saldo.saldoCapital.toBs().toStringAsFixed(0);
    }
    _recalcularTotal();
    _cargarPerfil();
  }

  void _recalcularTotal() {
    final cap = double.tryParse(_montoCapitalCtrl.text) ?? 0.0;
    final inte = double.tryParse(_montoInteresCtrl.text) ?? 0.0;
    _montoTotalCtrl.text = (cap + inte).toStringAsFixed(0);
  }

  Future<void> _cargarPerfil() async {
    try {
      final perfil = await ServiceLocator.perfilRepo.obtenerPerfil();
      if (mounted) {
        setState(() {
          _perfil = perfil;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  void dispose() {
    _montoTotalCtrl.dispose();
    _montoCapitalCtrl.dispose();
    _montoInteresCtrl.dispose();
    super.dispose();
  }

  String _generarMensajePreview(Money cap, Money inte, Money total) {
    final buffer = StringBuffer();
    buffer.writeln('*ESTADO DE CUENTA Y COBRO - PASAKI*');
    if (_perfil != null && _perfil!.nombreTitular.isNotEmpty) {
      buffer.writeln('*De:* ${_perfil!.nombreTitular}');
    }
    if (_perfil?.banco != null && _perfil!.banco!.isNotEmpty) {
      buffer.writeln('*Banco:* ${_perfil!.banco}');
    }
    if (_perfil?.numeroCuenta != null && _perfil!.numeroCuenta!.isNotEmpty) {
      buffer.writeln('*Cuenta:* ${_perfil!.numeroCuenta}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('*Abono a Capital:*${cap.formatBs()}');
    buffer.writeln('*Abono a Interés:*${inte.formatBs()}');
    buffer.writeln('*TOTAL A TRANSFERIR:*${total.formatBs()}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*Podés transferir escaneando el código QR adjunto.*');
    return buffer.toString();
  }

  void _mostrarModalExito(FichaCobro ficha) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Ficha de Cobro Guardada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 6),
              Text(
                'La ficha se guardó como pendiente por ${ficha.totalAPagar.formatBs()}. Ya podés enviarla a tu deudor.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_perfil?.tieneQr == true) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: Image.memory(
                      base64Decode(_perfil!.qrImageBase64!),
                      height: 160,
                      width: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await CompartirFichaService.compartir(ficha);
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                },
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text('Compartir Ficha (WhatsApp y más)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Cerrar y volver'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _guardarFichaCobro() async {
    final montoCapVal = double.tryParse(_montoCapitalCtrl.text) ?? 0.0;
    final montoIntVal = double.tryParse(_montoInteresCtrl.text) ?? 0.0;
    final totalVal = montoCapVal + montoIntVal;

    if (totalVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un monto a cobrar (en Capital o Interés).')),
      );
      return;
    }

    setState(() => _procesandoGuardado = true);
    try {
      final fichaGuardada = await ServiceLocator.generarFichaCobro.execute(
        prestamoId: _prestamo.id!,
        montoCapital: Money.fromBs(montoCapVal),
        montoInteres: Money.fromBs(montoIntVal),
        guardarEnHistorial: true,
        nombrePrestamista: _perfil?.nombreTitular,
        bancoPrestamista: _perfil?.banco,
        cuentaPrestamista: _perfil?.numeroCuenta,
        qrDataPrestamista: _perfil?.qrImageBase64,
      );

      if (mounted) {
        setState(() => _procesandoGuardado = false);
        _mostrarModalExito(fichaGuardada);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesandoGuardado = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.mora),
        );
      }
    }
  }

  Future<void> _asentarCobroDirecto() async {
    final montoCapVal = double.tryParse(_montoCapitalCtrl.text) ?? 0.0;
    final montoIntVal = double.tryParse(_montoInteresCtrl.text) ?? 0.0;
    final totalVal = montoCapVal + montoIntVal;

    if (totalVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un monto a cobrar (en Capital o Interés).')),
      );
      return;
    }

    setState(() => _procesandoGuardado = true);
    try {
      final montoCap = Money.fromBs(montoCapVal);
      final montoInt = Money.fromBs(montoIntVal);
      final montoTotal = Money.fromBs(totalVal);

      await ServiceLocator.registrarPago.execute(
        prestamoId: _prestamo.id!,
        montoPagado: montoTotal,
        montoACapital: montoCap,
        montoAInteres: montoInt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cobro de ${montoTotal.formatBs()} asentado exitosamente en el libro.'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "").replaceAll("StateError: ", "")}'),
            backgroundColor: AppColors.mora,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _procesandoGuardado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final saldo = _prestamo.saldoActual;
    final capNum = double.tryParse(_montoCapitalCtrl.text) ?? 0.0;
    final intNum = double.tryParse(_montoInteresCtrl.text) ?? 0.0;
    final capMoney = Money.fromBs(capNum);
    final intMoney = Money.fromBs(intNum);
    final totalMoney = capMoney + intMoney;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ficha de Cobro'),
        actions: [
          IconButton(
            tooltip: 'Configurar Perfil / QR',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
              _cargarPerfil();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumen de Deuda del Préstamo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Exigible',
                        style: TextStyle(color: AppColors.accentLight, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: saldo.saldoInteres.isPositive ? AppColors.mora : AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          saldo.saldoInteres.isPositive ? 'CON MORA' : 'AL DÍA',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      saldo.totalDeuda.formatBs(),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Capital: ${saldo.saldoCapital.formatBs()}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Interés: ${saldo.saldoInteres.formatBs()}',
                          style: TextStyle(
                            color: saldo.saldoInteres.isPositive ? const Color(0xFFFCA5A5) : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Formulario de Configuración de Montos
            const Text(
              'Configurar Monto a Cobrar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 8),

            // Accesos rápidos (Chips)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (saldo.saldoInteres.isPositive) ...[
                    ActionChip(
                      avatar: const Icon(Icons.trending_up, size: 16, color: AppColors.mora),
                      label: Text('Solo Interés (${saldo.saldoInteres.formatBs()})'),
                      onPressed: () {
                        setState(() {
                          _montoInteresCtrl.text = saldo.saldoInteres.toBs().toStringAsFixed(0);
                          _montoCapitalCtrl.text = '0';
                          _recalcularTotal();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  ActionChip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                    label: Text('Liquidar Todo (${saldo.totalDeuda.formatBs()})'),
                    onPressed: () {
                      setState(() {
                        _montoInteresCtrl.text = saldo.saldoInteres.toBs().toStringAsFixed(0);
                        _montoCapitalCtrl.text = saldo.saldoCapital.toBs().toStringAsFixed(0);
                        _recalcularTotal();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.payments_outlined, size: 16, color: AppColors.accent),
                    label: const Text('Solo Capital'),
                    onPressed: () {
                      setState(() {
                        _montoInteresCtrl.text = '0';
                        _montoCapitalCtrl.text = saldo.saldoCapital.toBs().toStringAsFixed(0);
                        _recalcularTotal();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _montoCapitalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Abono a Capital',
                      prefixText: 'Bs ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _recalcularTotal()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _montoInteresCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Abono a Interés',
                      prefixText: 'Bs ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _recalcularTotal()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // SECCIÓN: VISTA PREVIA EN VIVO DE LA FICHA QR
            const Text(
              'Ficha y QR que se enviarán',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 10),

            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Preview del QR o Alerta de Falta de QR
                    if (_perfil != null && _perfil!.tieneQr) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8),
                          child: Image.memory(
                            base64Decode(_perfil!.qrImageBase64!),
                            height: 180,
                            width: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _perfil!.nombreTitular,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                      ),
                      if (_perfil!.banco != null)
                        Text(
                          '${_perfil!.banco} ${_perfil!.numeroCuenta != null ? "- Cta: ${_perfil!.numeroCuenta}" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.advertenciaLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.advertencia.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, color: AppColors.advertencia, size: 28),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No tenés un código QR configurado en tu perfil.',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryDark,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.upload_file_rounded, size: 18),
                                label: const Text('Subir mi QR en Perfil'),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PerfilScreen()),
                                  );
                                  _cargarPerfil();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 24),

                    // Desglose Numérico de la Ficha
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total a Transferir:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          totalMoney.formatBs(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Capital: ${capMoney.formatBs()}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text('Interés: ${intMoney.formatBs()}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Preview del Mensaje de WhatsApp
                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _generarMensajePreview(capMoney, intMoney, totalMoney),
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón Principal: Guardar Ficha de Cobro
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _procesandoGuardado ? null : _guardarFichaCobro,
              icon: _procesandoGuardado
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined, size: 22),
              label: Text(
                _procesandoGuardado ? 'Guardando...' : 'Guardar Ficha de Cobro',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Botón Secundario: Asentar Cobro Directo en Efectivo
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _procesandoGuardado ? null : _asentarCobroDirecto,
              icon: const Icon(Icons.payments_outlined, size: 20),
              label: const Text('Asentar Cobro Directo en Efectivo'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
