import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/cliente.dart';
import '../../../domain/models/prestamo.dart';
import '../../widgets/metric_card.dart';
import '../clientes/detalle_cliente_screen.dart';
import '../clientes/registro_cliente_screen.dart';
import '../cobro/cobro_screen.dart';
import '../configuracion/configuracion_screen.dart';
import '../prestamos/crear_prestamo_screen.dart';
import '../prestamos/detalle_prestamo_screen.dart';

enum FiltroCliente { todos, alDia, atrasados }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0; // 0 = Inicio, 1 = Clientes
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _buscando = false;
  Timer? _debounceTimer;

  FiltroCliente _filtroSeleccionado = FiltroCliente.todos;

  List<Cliente> _clientes = [];
  Map<int, List<Prestamo>> _prestamosPorCliente = {};
  List<Prestamo> _prestamosActivos = [];

  Money _totalCapitalPrestado = Money.zero;
  Money _totalInteresPendiente = Money.zero;
  bool _cargando = true;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex);
    _cargarDatos(mostrarSpinner: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    final queryLimpia = val.trim().toLowerCase();

    if (queryLimpia.isEmpty) {
      setState(() {
        _searchQuery = '';
        _buscando = false;
      });
      return;
    }

    setState(() {
      _buscando = true;
    });

    // Debounce óptimo de producción (250 ms)
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = queryLimpia;
          _buscando = false;
        });
      }
    });
  }

  Future<void> _cargarDatos({bool mostrarSpinner = false}) async {
    if (mostrarSpinner) {
      setState(() => _cargando = true);
    }
    // Evaluación perezosa (Lazy Catch-Up): Devenga intereses de ciclos vencidos automáticamente
    await ServiceLocator.verificarYDevengarAutomatico.execute();

    final clientes = await ServiceLocator.buscarClientes.execute();
    final prestamosActivos = await ServiceLocator.prestamoRepo.obtenerActivos();

    final Map<int, List<Prestamo>> mapa = {};
    Money capTotal = Money.zero;
    Money intTotal = Money.zero;

    for (final p in prestamosActivos) {
      mapa.putIfAbsent(p.clienteId, () => []).add(p);
      capTotal = capTotal + p.saldoActual.saldoCapital;
      intTotal = intTotal + p.saldoActual.saldoInteres;
    }

    if (mounted) {
      setState(() {
        _clientes = clientes;
        _prestamosActivos = prestamosActivos;
        _prestamosPorCliente = mapa;
        _totalCapitalPrestado = capTotal;
        _totalInteresPendiente = intTotal;
        _cargando = false;
      });
    }
  }

  List<Cliente> get _clientesFiltrados {
    List<Cliente> lista = _clientes;

    if (_searchQuery.isNotEmpty) {
      lista = lista.where((c) {
        final matchNombre = c.nombre.toLowerCase().contains(_searchQuery);
        final matchApellido = c.apellido?.toLowerCase().contains(_searchQuery) ?? false;
        final matchAlias = c.alias?.toLowerCase().contains(_searchQuery) ?? false;
        final matchTelefono = c.telefonoPrincipal.contains(_searchQuery);
        final matchCi = c.ci?.toLowerCase().contains(_searchQuery) ?? false;
        final matchContactos = c.contactos.any(
          (ct) =>
              ct.telefono.contains(_searchQuery) ||
              (ct.etiqueta?.toLowerCase().contains(_searchQuery) ?? false),
        );
        return matchNombre ||
            matchApellido ||
            matchAlias ||
            matchTelefono ||
            matchCi ||
            matchContactos;
      }).toList();
    }

    switch (_filtroSeleccionado) {
      case FiltroCliente.todos:
        return lista;
      case FiltroCliente.alDia:
        return lista.where((c) {
          final prestamos = _prestamosPorCliente[c.id] ?? [];
          return prestamos.isNotEmpty && prestamos.every((p) => p.saldoActual.saldoInteres.isZero);
        }).toList();
      case FiltroCliente.atrasados:
        return lista.where((c) {
          final prestamos = _prestamosPorCliente[c.id] ?? [];
          return prestamos.any((p) => p.saldoActual.saldoInteres.isPositive);
        }).toList();
    }
  }

  void _abrirModalCreacion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
              const Text(
                '¿Qué querés registrar?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentLight,
                  child: Icon(Icons.person_add, color: AppColors.primary),
                ),
                title: const Text('Registrar Nuevo Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Crear ficha con nombre, teléfono y alias'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegistroClienteScreen()),
                  );
                  if (res != null) _cargarDatos();
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentLight,
                  child: Icon(Icons.add_card, color: AppColors.primary),
                ),
                title: const Text('Desembolsar Nuevo Préstamo', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Configurar capital, tasa y modalidad'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CrearPrestamoScreen()),
                  );
                  if (res != null) _cargarDatos();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _tabIndex == 2
          ? null
          : AppBar(
              title: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.accentLight),
                  const SizedBox(width: 10),
                  Text(
                    _tabIndex == 0 ? 'PasaKi' : 'Clientes',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _cargarDatos(mostrarSpinner: true),
                ),
              ],
            ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : PageView(
              controller: _pageController,
              onPageChanged: (idx) {
                setState(() {
                  _tabIndex = idx;
                });
                if (idx == 0 || idx == 1) {
                  _cargarDatos();
                }
              },
              children: [
                _buildTabInicio(),
                _buildTabClientes(),
                const ConfiguracionScreen(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _tabIndex = idx;
          });
          _pageController.animateToPage(
            idx,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
          if (idx == 0 || idx == 1) {
            _cargarDatos();
          }
        },
        indicatorColor: AppColors.accentLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.primary),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: 'Configuración',
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 2
          ? null
          : FloatingActionButton(
              onPressed: _abrirModalCreacion,
              tooltip: 'Registrar',
              child: const Icon(Icons.add, size: 28),
            ),
    );
  }

  /// Pestaña 0: Inicio / Resumen de Cartera y Cobranzas Rápidas
  Widget _buildTabInicio() {
    final totalCartera = _totalCapitalPrestado + _totalInteresPendiente;

    return RefreshIndicator(
      onRefresh: () => _cargarDatos(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumen de Métricas
            Row(
              children: [
                MetricCard(
                  label: 'Capital Prestado',
                  value: _totalCapitalPrestado.formatBs(),
                  icon: Icons.payments_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Interés por Cobrar',
                  value: _totalInteresPendiente.formatBs(),
                  icon: Icons.trending_up,
                  color: _totalInteresPendiente.isPositive ? AppColors.mora : AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL EN CALLE (CARTERA)',
                    style: TextStyle(color: AppColors.accentLight, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    totalCartera.formatBs(),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sección de Préstamos Activos con Acceso Directo de Cobro (Regla 3 Toques)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Préstamos Activos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
                Text(
                  '${_prestamosActivos.length} activos',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_prestamosActivos.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 54, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text('No hay préstamos pendientes de cobro.', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _prestamosActivos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final p = _prestamosActivos[i];
                  final saldo = p.saldoActual;
                  final cliente = _clientes.firstWhere(
                    (c) => c.id == p.clienteId,
                    orElse: () => Cliente(
                      id: p.clienteId,
                      nombre: 'Cliente #${p.clienteId}',
                      telefonoPrincipal: '',
                      createdAt: 0,
                      updatedAt: 0,
                    ),
                  );
                  final tieneMora = saldo.saldoInteres.isPositive;

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
                        border: Border.all(
                          color: tieneMora ? AppColors.mora.withOpacity(0.4) : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: tieneMora ? AppColors.moraLight : AppColors.accentLight,
                            child: Icon(
                              tieneMora ? Icons.warning_amber_rounded : Icons.monetization_on_outlined,
                              color: tieneMora ? AppColors.mora : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cliente.nombreVisual,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Capital: ${saldo.saldoCapital.formatBs()} | Int: ${saldo.saldoInteres.formatBs()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tieneMora ? AppColors.mora : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                saldo.totalDeuda.formatBs(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  final cobrado = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => CobroScreen(prestamo: p)),
                                  );
                                  if (cobrado == true) _cargarDatos();
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.qr_code_2, size: 14),
                                    SizedBox(width: 4),
                                    Text('Cobrar', style: TextStyle(fontSize: 12)),
                                  ],
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

  /// Pestaña 1: Clientes (Buscador, Cápsulas de Filtro fijas y Lista Virtualizada)
  Widget _buildTabClientes() {
    final filtrados = _clientesFiltrados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera Fija: Título, Buscador y Cápsulas de Filtro
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Clientes',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Lista de clientes',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // Buscador con icono de lupa y placeholder
              TextField(
                controller: _searchCtrl,
                maxLength: 60,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Buscar por nombre, alias o teléfono...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : (_searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _debounceTimer?.cancel();
                                _searchCtrl.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _buscando = false;
                                });
                              },
                            )
                          : null),
                ),
              ),
              const SizedBox(height: 12),

              // Cápsulas para filtrar (Filter Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('Todos (${_clientes.length})'),
                      selected: _filtroSeleccionado == FiltroCliente.todos,
                      onSelected: (sel) {
                        if (sel) setState(() => _filtroSeleccionado = FiltroCliente.todos);
                      },
                      selectedColor: AppColors.accentLight,
                      checkmarkColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Al día'),
                      selected: _filtroSeleccionado == FiltroCliente.alDia,
                      onSelected: (sel) {
                        if (sel) setState(() => _filtroSeleccionado = FiltroCliente.alDia);
                      },
                      selectedColor: AppColors.accentLight,
                      checkmarkColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Atrasados'),
                      selected: _filtroSeleccionado == FiltroCliente.atrasados,
                      onSelected: (sel) {
                        if (sel) setState(() => _filtroSeleccionado = FiltroCliente.atrasados);
                      },
                      selectedColor: AppColors.moraLight,
                      checkmarkColor: AppColors.mora,
                      labelStyle: TextStyle(
                        color: _filtroSeleccionado == FiltroCliente.atrasados ? AppColors.mora : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista de Clientes Virtualizada con Scroll Independiente
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _cargarDatos(),
            child: filtrados.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(40),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              _buscando ? Icons.search : Icons.person_off_outlined,
                              size: 54,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _buscando
                                  ? 'Buscando clientes...'
                                  : (_searchQuery.isNotEmpty
                                      ? 'No se encontraron clientes para "$_searchQuery".'
                                      : (_clientes.isEmpty
                                          ? 'No tenés clientes registrados aún.'
                                          : 'No hay clientes en esta categoría.')),
                              style: const TextStyle(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                            if (!_buscando && _searchQuery.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text('Registrar Nuevo Cliente'),
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegistroClienteScreen()),
                                  );
                                  if (res != null) _cargarDatos();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : AnimatedOpacity(
                    opacity: _buscando ? 0.4 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final cliente = filtrados[i];
                      final prestamosCliente = _prestamosPorCliente[cliente.id] ?? [];
                      final tienePrestamoActivo = prestamosCliente.isNotEmpty;

                      Money deudaTotal = Money.zero;
                      bool tieneMora = false;

                      for (final p in prestamosCliente) {
                        deudaTotal = deudaTotal + p.saldoActual.totalDeuda;
                        if (p.saldoActual.saldoInteres.isPositive) {
                          tieneMora = true;
                        }
                      }

                      return InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetalleClienteScreen(clienteId: cliente.id!),
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
                            border: Border.all(
                              color: tieneMora ? AppColors.mora.withOpacity(0.4) : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: tieneMora
                                    ? AppColors.moraLight
                                    : (tienePrestamoActivo ? AppColors.accentLight : AppColors.surfaceElevated),
                                child: Text(
                                  cliente.nombre[0].toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: tieneMora
                                        ? AppColors.mora
                                        : (tienePrestamoActivo ? AppColors.primary : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            cliente.nombreCompleto,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        if (tieneMora)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.mora,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text('MORA',
                                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    if (cliente.alias != null)
                                      Text(
                                        '"${cliente.alias}"',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'WhatsApp: ${cliente.telefonoPrincipal}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    deudaTotal.formatBs(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: tieneMora ? AppColors.mora : AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tienePrestamoActivo ? '${prestamosCliente.length} activo(s)' : 'Sin préstamos',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tienePrestamoActivo ? AppColors.primary : AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
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
                ),
          ),
        ),
      ],
    );
  }
}
