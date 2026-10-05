import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/money.dart';
import '../../../core/services/compartir_ficha_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/ficha_cobro.dart';
import '../../../domain/models/movimiento_financiero.dart';
import '../../../domain/models/prestamo.dart';
import '../../../domain/models/tipo_movimiento.dart';
import '../cobro/cobro_screen.dart';

class DetallePrestamoScreen extends StatefulWidget {
  final int prestamoId;

  const DetallePrestamoScreen({super.key, required this.prestamoId});

  @override
  State<DetallePrestamoScreen> createState() => _DetallePrestamoScreenState();
}

class _DetallePrestamoScreenState extends State<DetallePrestamoScreen> with SingleTickerProviderStateMixin {
  Prestamo? _prestamo;
  List<MovimientoFinanciero> _movimientos = [];
  List<FichaCobro> _fichas = [];
  bool _cargando = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDetalle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalle() async {
    await ServiceLocator.verificarYDevengarAutomatico.execute();
    final prestamo = await ServiceLocator.prestamoRepo.obtenerPorId(widget.prestamoId);
    final movimientos = await ServiceLocator.prestamoRepo.obtenerMovimientos(widget.prestamoId);
    final fichas = await ServiceLocator.fichaCobroRepo.obtenerPorPrestamo(widget.prestamoId);

    if (mounted) {
      setState(() {
        _prestamo = prestamo;
        _movimientos = movimientos;
        _fichas = fichas;
        _cargando = false;
      });
    }
  }

  Future<void> _confirmarFicha(FichaCobro ficha) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Confirmar Cobro de Ficha #${ficha.id}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Al confirmar, se asentará el cobro recibido en el libro mayor con el desglose exacto de la ficha:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a Asentar:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        ficha.totalAPagar.formatBs(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Abono a Capital:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(ficha.montoCapital.formatBs(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Abono a Interés:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(ficha.montoInteres.formatBs(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Si el deudor pagó un monto diferente, cancelá esta confirmación y anulá la ficha para registrar el monto correcto.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar y Asentar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      try {
        await ServiceLocator.confirmarFichaCobro.execute(
          fichaId: ficha.id!,
          montoRealCapital: ficha.montoCapital,
          montoRealInteres: ficha.montoInteres,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pago de Ficha QR confirmado y asentado en el libro contable.'),
              backgroundColor: AppColors.primary,
            ),
          );
          _cargarDetalle();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.mora),
          );
        }
      }
    }
  }

  Future<void> _anularFicha(FichaCobro ficha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Anular Ficha de Cobro?'),
        content: const Text(
          'Esta ficha ya no podrá ser cobrada ni causará asientos contables en el libro.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.mora),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anular Ficha'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await ServiceLocator.anularFichaCobro.execute(ficha.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ficha de cobro anulada.')),
        );
        _cargarDetalle();
      }
    }
  }

  void _compartirWhatsApp(FichaCobro ficha) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Código QR de la Ficha',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 6),
            Text(
              'Total a transferir: ${ficha.totalAPagar.formatBs()}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryLight, width: 2),
              ),
              child: Center(
                child: (ficha.qrData != null && ficha.qrData!.length > 50)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          base64Decode(ficha.qrData!),
                          width: 176,
                          height: 176,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Icon(Icons.qr_code_2, size: 120, color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 20),
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
              },
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Compartir Ficha (WhatsApp y más)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoDesembolsoAdicional() async {
    if (_prestamo == null || _prestamo!.isLiquidado) return;

    final formKey = GlobalKey<FormState>();
    final montoCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    DateTime fechaSeleccionada = DateTime.now();

    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final montoNum = double.tryParse(montoCtrl.text.trim()) ?? 0.0;
          final capitalActual = _prestamo!.saldoActual.saldoCapital;
          final nuevoCapital = capitalActual + Money.fromBs(montoNum);

          return Container(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Desembolso Adicional',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Este monto se sumará al capital del préstamo actual.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Campo de Monto
                    TextFormField(
                      controller: montoCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Monto a Desembolsar (Bs.) *',
                        hintText: 'Ej. 1000',
                        prefixText: 'Bs. ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setModalState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Ingresá el monto a desembolsar';
                        final numVal = double.tryParse(val.trim());
                        if (numVal == null || numVal <= 0) return 'Monto debe ser mayor a 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Selector de Fecha
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: fechaSeleccionada,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  fechaSeleccionada = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    DateTime.now().hour,
                                    DateTime.now().minute,
                                  );
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.divider),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Fecha de entrega', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text(
                                        '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Nota opcional
                    TextFormField(
                      controller: notaCtrl,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Nota o Motivo (Opcional)',
                        hintText: 'Ej. Mercadería extra, ampliación...',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resumen de impacto de saldo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Capital actual:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(capitalActual.formatBs(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Aumento:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(
                                '+ ${Money.fromBs(montoNum).formatBs()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Nuevo Capital Consolidado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                nuevoCapital.formatBs(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _prestamo!.prorratearInteres ? Icons.info_outline_rounded : Icons.info_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _prestamo!.prorratearInteres
                                      ? 'Con prorrateo activo, este monto solo generará intereses por los días restantes hasta el próximo corte.'
                                      : 'Sin prorrateo: en el próximo corte el interés se calculará sobre el total de capital consolidado.',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(ctx, true);
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Confirmar Desembolso', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (confirmado == true && mounted) {
      final montoNum = double.tryParse(montoCtrl.text.trim()) ?? 0.0;
      try {
        await ServiceLocator.desembolsarAdicional.execute(
          prestamoId: _prestamo!.id!,
          monto: Money.fromBs(montoNum),
          fecha: fechaSeleccionada,
          nota: notaCtrl.text.trim().isNotEmpty ? notaCtrl.text.trim() : null,
        );

        await _cargarDetalle();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Desembolso de Bs. ${montoCtrl.text.trim()} registrado exitosamente'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al desembolsar: $e'), backgroundColor: AppColors.mora),
          );
        }
      }
    }
  }

  Color _colorPorTipo(TipoMovimiento tipo) {
    switch (tipo) {
      case TipoMovimiento.desembolso:
        return AppColors.primary;
      case TipoMovimiento.pago:
        return AppColors.accent;
      case TipoMovimiento.interesGenerado:
        return AppColors.advertencia;
      case TipoMovimiento.condonacion:
        return Colors.purple;
      case TipoMovimiento.reestructuracion:
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _iconoPorTipo(TipoMovimiento tipo) {
    switch (tipo) {
      case TipoMovimiento.desembolso:
        return Icons.arrow_outward;
      case TipoMovimiento.pago:
        return Icons.arrow_downward;
      case TipoMovimiento.interesGenerado:
        return Icons.trending_up;
      case TipoMovimiento.condonacion:
        return Icons.card_giftcard;
      case TipoMovimiento.reestructuracion:
        return Icons.published_with_changes;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Préstamo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_prestamo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Préstamo')),
        body: const Center(child: Text('Préstamo no encontrado')),
      );
    }

    final saldo = _prestamo!.saldoActual;
    final pendientesCount = _fichas.where((f) => f.isPendiente).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Préstamo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar y devengar',
            onPressed: () => _cargarDetalle(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tarjeta Resumen Superior (Saldos y Condiciones)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Deuda: ${saldo.totalDeuda.formatBs()}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _prestamo!.isLiquidado ? AppColors.accentLight : AppColors.primaryLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _prestamo!.estado.toUpperCase(),
                          style: TextStyle(
                            color: _prestamo!.isLiquidado ? AppColors.accent : AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Saldo Capital', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(saldo.saldoCapital.formatBs(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Interés Pendiente', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                saldo.saldoInteres.formatBs(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: saldo.saldoInteres.isPositive ? AppColors.mora : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tasa: ${_prestamo!.tasa.porcentaje}% ${_prestamo!.tasa.periodo.etiqueta.toLowerCase()}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        'Prorrateo: ${_prestamo!.prorratearInteres ? "Activo" : "Desactivado"}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          onPressed: (_prestamo == null || _prestamo!.isLiquidado)
                              ? null
                              : () => _mostrarDialogoDesembolsoAdicional(),
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text('Desembolsar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: _prestamo!.isLiquidado
                              ? null
                              : () async {
                                  final cobrado = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => CobroScreen(prestamo: _prestamo!)),
                                  );
                                  if (cobrado == true) {
                                    _cargarDetalle();
                                  }
                                },
                          icon: const Icon(Icons.qr_code_2, size: 20),
                          label: const Text('Generar QR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Pestañas (TabBar) solicitadas
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(
                icon: const Icon(Icons.menu_book_outlined, size: 20),
                text: 'Movimientos (${_movimientos.length})',
              ),
              Tab(
                icon: Badge(
                  isLabelVisible: pendientesCount > 0,
                  label: Text('$pendientesCount'),
                  backgroundColor: AppColors.mora,
                  child: const Icon(Icons.qr_code_scanner, size: 20),
                ),
                text: pendientesCount > 0 ? 'Fichas QR ($pendientesCount)' : 'Fichas QR (${_fichas.length})',
              ),
            ],
          ),

          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabMovimientos(),
                _buildTabFichasQr(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pestaña 1: Libro Contable de Movimientos
  Widget _buildTabMovimientos() {
    if (_movimientos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarDetalle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay movimientos registrados.', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDetalle,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
      itemCount: _movimientos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final m = _movimientos[index];
        final color = _colorPorTipo(m.tipo);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(_iconoPorTipo(m.tipo), size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          m.tipo.etiqueta,
                          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                        ),
                        if (m.debe != null)
                          Text('+ ${m.debe!.formatBs()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))
                        else if (m.haber != null)
                          Text('- ${m.haber!.formatBs()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(m.detalle, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateTime.fromMillisecondsSinceEpoch(m.fecha).toLocal().toString().split(' ')[0],
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        Text(
                          'Capital: ${m.saldoCapitalResultante.formatBs()} | Int: ${m.saldoInteresResultante.formatBs()}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  }

  /// Pestaña 2: Fichas QR (Pendientes e Historial)
  Widget _buildTabFichasQr() {
    if (_fichas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'No hay fichas QR generadas.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Generá una ficha para enviarle el QR de cobro por WhatsApp a tu deudor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _prestamo!.isLiquidado
                    ? null
                    : () async {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => CobroScreen(prestamo: _prestamo!)),
                        );
                        if (res == true) _cargarDetalle();
                      },
                icon: const Icon(Icons.add),
                label: const Text('Generar Ficha QR'),
              ),
            ],
          ),
        ),
      );
    }

    final pendientes = _fichas.where((f) => f.isPendiente).toList();
    final historicas = _fichas.where((f) => !f.isPendiente).toList();

    return RefreshIndicator(
      onRefresh: _cargarDetalle,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (pendientes.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.pending_actions, size: 18, color: AppColors.advertencia),
                SizedBox(width: 8),
                Text(
                  'Pendientes de Cobro (En el aire)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...pendientes.map((f) => _buildTarjetaFichaPendiente(f)),
            const SizedBox(height: 20),
          ],

          if (historicas.isNotEmpty) ...[
            const Text(
              'Historial de Fichas Anteriores',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ...historicas.map((f) => _buildTarjetaFichaHistorica(f)),
          ],
        ],
      ),
    );
  }

  Widget _buildTarjetaFichaPendiente(FichaCobro f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Ámbar suave
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ficha #${f.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PENDIENTE',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Solicitado:', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                f.totalAPagar.formatBs(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Desglose: Capital ${f.montoCapital.formatBs()} | Interés ${f.montoInteres.formatBs()}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Emitida el ${DateTime.fromMillisecondsSinceEpoch(f.fechaEmision).toLocal().toString().split('.')[0]}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E7E34),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _compartirWhatsApp(f),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _confirmarFicha(f),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Confirmar', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Anular Ficha',
                icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                onPressed: () => _anularFicha(f),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaFichaHistorica(FichaCobro f) {
    final esCobrada = f.isCobrada;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: esCobrada ? AppColors.accentLight : Colors.grey.shade200,
                child: Icon(
                  esCobrada ? Icons.check : Icons.close,
                  size: 16,
                  color: esCobrada ? AppColors.accent : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ficha #${f.id} - ${f.totalAPagar.formatBs()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cap: ${f.montoCapital.formatBs()} | Int: ${f.montoInteres.formatBs()}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: esCobrada ? AppColors.accentLight : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              f.estado.toUpperCase(),
              style: TextStyle(
                color: esCobrada ? AppColors.accent : Colors.grey.shade700,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
