import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/cliente.dart';
import '../../../domain/models/prestamo.dart';
import '../prestamos/crear_prestamo_screen.dart';
import '../prestamos/detalle_prestamo_screen.dart';
import 'editar_cliente_screen.dart';

class DetalleClienteScreen extends StatefulWidget {
  final int clienteId;

  const DetalleClienteScreen({super.key, required this.clienteId});

  @override
  State<DetalleClienteScreen> createState() => _DetalleClienteScreenState();
}

class _DetalleClienteScreenState extends State<DetalleClienteScreen> {
  Cliente? _cliente;
  List<Prestamo> _prestamos = [];
  bool _cargando = true;
  bool _mostrarTodosContactos = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final cliente = await ServiceLocator.clienteRepo.obtenerPorId(widget.clienteId);
    final prestamos = await ServiceLocator.prestamoRepo.obtenerPorCliente(widget.clienteId);

    if (mounted) {
      setState(() {
        _cliente = cliente;
        _prestamos = prestamos;
        _cargando = false;
      });
    }
  }

  Future<void> _editarCliente() async {
    if (_cliente == null) return;
    final modificado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarClienteScreen(cliente: _cliente!),
      ),
    );
    if (modificado == true) {
      _cargarDatos();
    }
  }

  Future<void> _confirmarEliminarCliente() async {
    if (_cliente == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Cliente?'),
        content: Text(
          'Esta acción eliminará definitivamente al cliente "${_cliente!.nombreVisual}" del sistema. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mora,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ServiceLocator.eliminarCliente.execute(_cliente!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente eliminado correctamente.'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ficha del Cliente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_cliente == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ficha del Cliente')),
        body: const Center(child: Text('Cliente no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_cliente!.nombreVisual),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar cliente',
            onPressed: _editarCliente,
          ),
          if (_prestamos.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.mora),
              tooltip: 'Eliminar cliente',
              onPressed: _confirmarEliminarCliente,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Perfil del Cliente
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          _cliente!.nombre[0].toUpperCase(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _cliente!.nombreCompleto,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                            if (_cliente!.alias != null)
                              Text(
                                '"${_cliente!.alias}"',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            Text(
                              'WhatsApp: ${_cliente!.telefonoPrincipal}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_cliente!.direccion != null || _cliente!.ci != null) ...[
                    const Divider(height: 24),
                    if (_cliente!.ci != null)
                      Text('CI: ${_cliente!.ci}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    if (_cliente!.direccion != null)
                      Text('Dirección: ${_cliente!.direccion}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                  if (_cliente!.contactos.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Otros Contactos:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        if (_cliente!.contactos.length > 2)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _mostrarTodosContactos = !_mostrarTodosContactos;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                _mostrarTodosContactos
                                    ? 'Ver menos'
                                    : '+ Ver ${_cliente!.contactos.length - 2} más',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...(_mostrarTodosContactos
                            ? _cliente!.contactos
                            : _cliente!.contactos.take(2))
                        .map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${c.telefono} ${c.etiqueta != null && c.etiqueta!.isNotEmpty ? "(${c.etiqueta})" : ""}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Encabezado de Préstamos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Préstamos del Cliente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final nuevo = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CrearPrestamoScreen(clientePreseleccionado: _cliente),
                      ),
                    );
                    if (nuevo != null) {
                      _cargarDatos();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo Préstamo'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_prestamos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Este cliente no tiene préstamos registrados.', style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _prestamos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final p = _prestamos[i];
                  final saldo = p.saldoActual;

                  return InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetallePrestamoScreen(prestamoId: p.id!),
                        ),
                      );
                      _cargarDatos();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: p.isLiquidado ? AppColors.accentLight : AppColors.primaryLight.withOpacity(0.12),
                            child: Icon(
                              p.isLiquidado ? Icons.check_circle_outline : Icons.monetization_on_outlined,
                              color: p.isLiquidado ? AppColors.accent : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Capital Inicial: ${p.capitalInicial.formatBs()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tasa: ${p.tasa.porcentaje}% ${p.tasa.periodo.etiqueta.toLowerCase()} (${p.modalidad.etiqueta})',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                saldo.totalDeuda.formatBs(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: saldo.isLiquidado ? AppColors.accent : AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.estado.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: p.isLiquidado ? AppColors.accent : (saldo.saldoInteres.isPositive ? AppColors.mora : AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
