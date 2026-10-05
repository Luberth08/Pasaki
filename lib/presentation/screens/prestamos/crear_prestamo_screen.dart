import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/cliente.dart';
import '../../../domain/models/periodo_tasa.dart';
import '../../../domain/models/tasa_interes.dart';
import '../../../domain/models/tipo_modalidad_interes.dart';
import '../../../domain/services/calculador_fechas_corte.dart';
import '../clientes/registro_cliente_screen.dart';

class CrearPrestamoScreen extends StatefulWidget {
  final Cliente? clientePreseleccionado;

  const CrearPrestamoScreen({super.key, this.clientePreseleccionado});

  @override
  State<CrearPrestamoScreen> createState() => _CrearPrestamoScreenState();
}

class _CrearPrestamoScreenState extends State<CrearPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();

  Cliente? _clienteSeleccionado;
  List<Cliente> _clientesDisponibles = [];

  final _capitalCtrl = TextEditingController(text: '1000');
  final _tasaCtrl = TextEditingController(text: '20'); // 20% default (RF-08)

  PeriodoTasa _periodoTasa = PeriodoTasa.mensual;
  TipoModalidadInteres _modalidad = TipoModalidadInteres.simple;
  bool _prorratearInteres = false;

  int _diaSemanaDeseado = DateTime.now().weekday;
  int _diaMesDeseado = DateTime.now().day;
  int _mesAnualDeseado = DateTime.now().month;

  bool _cargando = false;
  bool _calculandoResumen = false;
  Timer? _debounceResumenTimer;

  @override
  void initState() {
    super.initState();
    _clienteSeleccionado = widget.clientePreseleccionado;
    _cargarClientes();
    _cargarTasaPredeterminada();
  }

  Future<void> _cargarTasaPredeterminada() async {
    try {
      final tasa = await ServiceLocator.configuracionRepo.obtenerTasaPredeterminada();
      if (mounted) {
        setState(() {
          final texto = tasa.truncateToDouble() == tasa ? tasa.toInt().toString() : tasa.toString();
          _tasaCtrl.text = texto;
        });
        _onValoresCambiados();
      }
    } catch (_) {}
  }

  Future<void> _cargarClientes() async {
    final clientes = await ServiceLocator.buscarClientes.execute();
    if (mounted) {
      setState(() {
        _clientesDisponibles = clientes.where((c) => !c.esListaNegra).toList();
        if (_clienteSeleccionado == null && _clientesDisponibles.isNotEmpty) {
          _clienteSeleccionado = _clientesDisponibles.first;
        } else if (_clienteSeleccionado != null) {
          _clienteSeleccionado = _clientesDisponibles.firstWhere(
            (c) => c.id == _clienteSeleccionado!.id,
            orElse: () => _clienteSeleccionado!,
          );
        }
      });
    }
  }

  Future<void> _crearNuevoCliente() async {
    final nuevoCliente = await Navigator.push<Cliente>(
      context,
      MaterialPageRoute(builder: (_) => const RegistroClienteScreen()),
    );

    if (nuevoCliente != null) {
      await _cargarClientes();
      if (mounted) {
        setState(() {
          _clienteSeleccionado = _clientesDisponibles.firstWhere(
            (c) => c.id == nuevoCliente.id,
            orElse: () => nuevoCliente,
          );
        });
      }
    }
  }

  Future<void> _abrirSelectorCliente() async {
    final clienteElegido = await showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalSelectorCliente(
        clientes: _clientesDisponibles,
        clienteActual: _clienteSeleccionado,
        onCrearNuevo: () async {
          Navigator.pop(ctx);
          await _crearNuevoCliente();
        },
      ),
    );

    if (clienteElegido != null && mounted) {
      setState(() {
        _clienteSeleccionado = clienteElegido;
      });
    }
  }

  @override
  void dispose() {
    _debounceResumenTimer?.cancel();
    _capitalCtrl.dispose();
    _tasaCtrl.dispose();
    super.dispose();
  }

  DateTime? _primerCorteMemo;
  List<DateTime>? _proximosCortesMemo;

  void _invalidarProyecciones() {
    _primerCorteMemo = null;
    _proximosCortesMemo = null;
  }

  void _onValoresCambiados() {
    _invalidarProyecciones();
    _debounceResumenTimer?.cancel();
    if (!_calculandoResumen) {
      setState(() {
        _calculandoResumen = true;
      });
    }

    _debounceResumenTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _calculandoResumen = false;
        });
      }
    });
  }

  void _agregarCapitalRapido(double extra) {
    final actual = double.tryParse(_capitalCtrl.text) ?? 0.0;
    final nuevo = (actual + extra).clamp(0.0, 10000000.0);
    _capitalCtrl.text = nuevo.toStringAsFixed(0);
    _onValoresCambiados();
  }

  Money get _capitalActual {
    final val = double.tryParse(_capitalCtrl.text) ?? 0.0;
    return Money.fromBs(val);
  }

  double get _tasaActual => double.tryParse(_tasaCtrl.text) ?? 0.0;

  Money get _interesProyectado => _capitalActual.applyPercentage(_tasaActual);

  DateTime get _fechaDesembolso {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _primerCorte {
    return _primerCorteMemo ??= CalculadorFechasCorte.calcularPrimerCorte(
      fechaDesembolso: _fechaDesembolso,
      periodo: _periodoTasa,
      diaSemanaDeseado: _diaSemanaDeseado,
      diaMesDeseado: _diaMesDeseado,
      mesAnualDeseado: _mesAnualDeseado,
    );
  }

  List<DateTime> get _proximosCortes {
    return _proximosCortesMemo ??= CalculadorFechasCorte.proyectarCortes(
      fechaDesembolso: _fechaDesembolso,
      periodo: _periodoTasa,
      diaSemanaDeseado: _diaSemanaDeseado,
      diaMesDeseado: _diaMesDeseado,
      mesAnualDeseado: _mesAnualDeseado,
      cantidad: 3,
    );
  }

  int get _diasHastaPrimerCorte {
    final diff = _primerCorte.difference(_fechaDesembolso).inDays;
    return diff <= 0 ? 1 : diff;
  }

  bool get _aplicaProrrateoPrimerCorte {
    return _periodoTasa != PeriodoTasa.diario &&
        _prorratearInteres &&
        _diasHastaPrimerCorte < _periodoTasa.diasReferencia;
  }

  Money get _interesPrimerCorte {
    final base = _interesProyectado;
    if (_aplicaProrrateoPrimerCorte) {
      final prop = _diasHastaPrimerCorte / _periodoTasa.diasReferencia;
      return Money.fromCents((base.cents * prop).round());
    }
    return base;
  }

  String _formatearFechaCorta(DateTime dt) {
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = meses[dt.month - 1];
    return '$dia $mes ${dt.year}';
  }

  Future<void> _guardarPrestamo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un cliente para el préstamo.')),
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      final prestamoCreado = await ServiceLocator.crearPrestamo.execute(
        clienteId: _clienteSeleccionado!.id!,
        capitalInicial: _capitalActual,
        tasa: TasaInteres(porcentaje: _tasaActual, periodo: _periodoTasa),
        modalidad: _modalidad,
        prorratearInteres: _prorratearInteres,
        fechaPrimerCorte: _primerCorte.millisecondsSinceEpoch,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Préstamo de ${_capitalActual.formatBs()} desembolsado a ${_clienteSeleccionado!.nombreVisual}.',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, prestamoCreado);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "").replaceAll("StateError: ", "").replaceAll("ArgumentError: ", "")}'),
            backgroundColor: AppColors.mora,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Préstamo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de Cliente
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cliente Deudor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (widget.clientePreseleccionado == null)
                    TextButton.icon(
                      onPressed: _crearNuevoCliente,
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: const Text('Nuevo'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.clientePreseleccionado != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.clientePreseleccionado!.nombreVisual,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (widget.clientePreseleccionado!.alias != null &&
                                widget.clientePreseleccionado!.alias!.isNotEmpty)
                              Text(
                                '"${widget.clientePreseleccionado!.alias}"',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              'WhatsApp: ${widget.clientePreseleccionado!.telefonoPrincipal}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Fijado',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (_clientesDisponibles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline, size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      const Text(
                        'Aún no tenés clientes registrados para otorgar un préstamo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _crearNuevoCliente,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Registrar Primer Cliente'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                )
              else
                FormField<Cliente>(
                  initialValue: _clienteSeleccionado,
                  validator: (val) {
                    if (_clienteSeleccionado == null) {
                      return 'Seleccioná un cliente para el préstamo';
                    }
                    return null;
                  },
                  builder: (state) {
                    final c = _clienteSeleccionado;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _abrirSelectorCliente,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: state.hasError ? AppColors.mora : AppColors.divider,
                                width: state.hasError ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: c != null
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.grey.shade100,
                                  child: Icon(
                                    Icons.person_outline,
                                    color: c != null ? AppColors.primary : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: c != null
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.nombreVisual,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              'WhatsApp: ${c.telefonoPrincipal}',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Toca para seleccionar cliente...',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 14,
                                          ),
                                        ),
                                ),
                                const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 6),
                            child: Text(
                              state.errorText!,
                              style: const TextStyle(color: AppColors.mora, fontSize: 12),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Monto de Capital
              const Text(
                'Capital a Desembolsar (Bs)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _capitalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                decoration: const InputDecoration(
                  counterText: '',
                  prefixText: 'Bs  ',
                  prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                  labelText: 'Monto de Capital *',
                  hintText: 'Ej: 1000',
                ),
                onChanged: (_) => _onValoresCambiados(),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresá el monto de capital';
                  final numVal = double.tryParse(val.trim()) ?? 0.0;
                  if (numVal <= 0) return 'El capital debe ser mayor a 0';
                  if (numVal > 10000000) return 'El monto máximo es de Bs 10,000,000';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // Chips de incremento rápido
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(label: const Text('+ Bs 500'), onPressed: () => _agregarCapitalRapido(500)),
                  ActionChip(label: const Text('+ Bs 1,000'), onPressed: () => _agregarCapitalRapido(1000)),
                  ActionChip(label: const Text('+ Bs 2,000'), onPressed: () => _agregarCapitalRapido(2000)),
                  ActionChip(label: const Text('+ Bs 5,000'), onPressed: () => _agregarCapitalRapido(5000)),
                ],
              ),
              const SizedBox(height: 24),

              // Tasa y Periodicidad
              const Text(
                'Condiciones de Interés',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _tasaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      maxLength: 5,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'Tasa (%) *',
                        hintText: 'Ej: 20',
                        suffixText: '%',
                      ),
                      onChanged: (_) => _onValoresCambiados(),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Ingresá la tasa';
                        final numVal = double.tryParse(val.trim());
                        if (numVal == null) return 'Tasa inválida';
                        if (numVal < 0) return 'No puede ser negativa';
                        if (numVal > 500) return 'Máximo 500%';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<PeriodoTasa>(
                      initialValue: _periodoTasa,
                      items: PeriodoTasa.values.map((p) {
                        return DropdownMenuItem(value: p, child: Text(p.etiqueta));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _periodoTasa = val;
                            if (_periodoTasa == PeriodoTasa.diario) {
                              _prorratearInteres = false;
                            }
                          });
                          _onValoresCambiados();
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Período'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selector interactivo de corte según período
              _buildConfiguracionCorte(),
              const SizedBox(height: 8),

              // Opción de Prorrateo de Interés (no aplica a diario)
              if (_periodoTasa != PeriodoTasa.diario) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Text(
                              'Prorratear interés',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                              tooltip: 'Explicación de prorrateo',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.pie_chart_outline, color: AppColors.primary, size: 22),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Prorrateo de Interés',
                                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'El prorrateo aplica únicamente al primer corte cuando el préstamo se entrega a mitad de período:',
                                            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                                          ),
                                          const SizedBox(height: 12),
                                          const Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                              Expanded(
                                                child: Text(
                                                  'Activado: El primer cobro cobra solo los días reales transcurridos desde el desembolso hasta la fecha de corte. Los cortes siguientes cobrarán el período completo.',
                                                  style: TextStyle(fontSize: 12.5, height: 1.35),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          const Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                              Expanded(
                                                child: Text(
                                                  'Desactivado: El primer corte cobra la cuota completa del período, sin importar cuántos días faltaban (práctica informal habitual).',
                                                  style: TextStyle(fontSize: 12.5, height: 1.35),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppColors.divider),
                                            ),
                                            child: const Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Ejemplo práctico',
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  'Prestás Bs 1,000 al 20% mensual el día 20, con corte fijado los días 30 (solo pasaron 10 días):',
                                                  style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  '• Con prorrateo: 1° corte cobra solo 10 días = Bs 67.\n• Sin prorrateo: 1° corte cobra el mes completo = Bs 200.',
                                                  style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Entendido'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _prorratearInteres,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() => _prorratearInteres = val);
                          _onValoresCambiados();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Tarjeta Cronograma Proyectado de Cortes (atenuado durante recálculo)
              AnimatedOpacity(
                opacity: _calculandoResumen ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: _buildCronogramaProyectado(),
              ),
              const SizedBox(height: 16),

              // Modalidad (Simple vs Compuesto) con explicación educativa
              Row(
                children: [
                  const Text(
                    'Modalidad de Cálculo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                    tooltip: 'Diferencia entre Interés Simple y Compuesto',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.calculate_outlined, color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Modalidades de Cálculo',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Interés Simple',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primaryDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'El interés se calcula siempre sobre el capital original. El interés acumulado impago nunca genera nuevos intereses.',
                                  style: TextStyle(fontSize: 12.5, height: 1.35),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.show_chart, size: 15, color: AppColors.primary),
                                          SizedBox(width: 6),
                                          Text(
                                            'Ejemplo Simple',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Prestás Bs 1,000 al 20% mensual:\n• Mes 1: Genera Bs 200.\n• Mes 2 (si no pagó): Acumula Bs 400 de interés total. El capital sigue siendo exactamente Bs 1,000.',
                                        style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Interés Compuesto',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primaryDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Si el cliente no paga los intereses al vencimiento, el interés impago se suma al capital (capitalización), generando intereses sobre una deuda mayor.',
                                  style: TextStyle(fontSize: 12.5, height: 1.35),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.stacked_line_chart, size: 15, color: AppColors.primary),
                                          SizedBox(width: 6),
                                          Text(
                                            'Ejemplo Compuesto',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Prestás Bs 1,000 al 20% mensual:\n• Mes 1: Debe Bs 200 de interés.\n• Si no paga, se capitaliza: la nueva deuda es Bs 1,200.\n• Mes 2: El 20% se calcula sobre Bs 1,200 = Bs 240.',
                                        style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Entendido'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<TipoModalidadInteres>(
                segments: const [
                  ButtonSegment(
                    value: TipoModalidadInteres.simple,
                    label: Text('Interés Simple'),
                    icon: Icon(Icons.show_chart),
                  ),
                  ButtonSegment(
                    value: TipoModalidadInteres.compuesto,
                    label: Text('Compuesto'),
                    icon: Icon(Icons.stacked_line_chart),
                  ),
                ],
                selected: {_modalidad},
                onSelectionChanged: (val) => setState(() => _modalidad = val.first),
              ),
              const SizedBox(height: 20),

              // Tarjeta Resumen Proyectado con recálculo atenuado
              AnimatedOpacity(
                opacity: _calculandoResumen ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Capital inicial:', style: TextStyle(color: AppColors.textSecondary)),
                          Text(_capitalActual.formatBs(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _aplicaProrrateoPrimerCorte
                                ? 'Interés 1° corte (prorrateado):'
                                : 'Interés ${_periodoTasa.etiqueta.toLowerCase()}:',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            _interesPrimerCorte.formatBs(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total al primer corte:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Row(
                            children: [
                              if (_calculandoResumen)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  ),
                                ),
                              Text(
                                (_capitalActual + _interesPrimerCorte).formatBs(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _cargando ? null : _guardarPrestamo,
                child: _cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmar y Desembolsar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfiguracionCorte() {
    switch (_periodoTasa) {
      case PeriodoTasa.diario:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Row(
            children: [
              Icon(Icons.event_available_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Corte de interés diario: se genera automáticamente cada 24 horas transcurridas.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );

      case PeriodoTasa.semanal:
        const dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
        final hoyDiaSemana = DateTime.now().weekday; // 1 = Lunes .. 7 = Domingo

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.event_repeat, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Día de corte de interés semanal:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    _diaSemanaDeseado == hoyDiaSemana
                        ? 'Hoy (${dias[_diaSemanaDeseado - 1]})'
                        : dias[_diaSemanaDeseado - 1],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 1; i <= 7; i++)
                    Builder(builder: (_) {
                      final esSeleccionado = _diaSemanaDeseado == i;
                      final esHoy = i == hoyDiaSemana;

                      return InkWell(
                        onTap: () {
                          setState(() => _diaSemanaDeseado = i);
                          _onValoresCambiados();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 44,
                          decoration: BoxDecoration(
                            color: esSeleccionado
                                ? AppColors.primary
                                : esHoy
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : AppColors.surfaceElevated.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: esSeleccionado
                                  ? AppColors.primary
                                  : esHoy
                                      ? AppColors.primary
                                      : AppColors.divider,
                              width: esSeleccionado || esHoy ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dias[i - 1],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: esSeleccionado
                                      ? Colors.white
                                      : esHoy
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                ),
                              ),
                              if (esHoy)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: esSeleccionado ? Colors.white : AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        );

      case PeriodoTasa.quincenal:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Row(
            children: [
              Icon(Icons.event_available_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Esquema quincenal fijo: Los cortes de interés se generarán los días 15 y fin de mes.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );

      case PeriodoTasa.mensual:
        return _buildCalendarioInteractivo(
          anio: DateTime.now().year,
          mes: DateTime.now().month,
          diaSeleccionado: _diaMesDeseado,
          onDiaSelected: (d) {
            setState(() => _diaMesDeseado = d);
            _onValoresCambiados();
          },
          permitirNavegarMeses: false,
        );

      case PeriodoTasa.anual:
        return _buildCalendarioInteractivo(
          anio: DateTime.now().year,
          mes: _mesAnualDeseado,
          diaSeleccionado: _diaMesDeseado,
          onDiaSelected: (d) {
            setState(() => _diaMesDeseado = d);
            _onValoresCambiados();
          },
          permitirNavegarMeses: true,
        );
    }
  }

  Widget _buildCalendarioInteractivo({
    required int anio,
    required int mes,
    required int diaSeleccionado,
    required ValueChanged<int> onDiaSelected,
    required bool permitirNavegarMeses,
  }) {
    final hoy = DateTime.now();
    final diasEnMesActual = CalculadorFechasCorte.diasEnMes(anio, mes);
    final primerDiaMes = DateTime(anio, mes, 1);
    final offsetPrimerDia = primerDiaMes.weekday - 1; // 0..6
    const diasSemanaHeader = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const mesesNombres = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final nombreMes = '${mesesNombres[mes - 1]} $anio';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (permitirNavegarMeses)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: mes > 1
                              ? () {
                                  setState(() => _mesAnualDeseado--);
                                  _onValoresCambiados();
                                }
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.chevron_left,
                              size: 20,
                              color: mes > 1 ? AppColors.primary : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        Text(
                          nombreMes,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        InkWell(
                          onTap: mes < 12
                              ? () {
                                  setState(() => _mesAnualDeseado++);
                                  _onValoresCambiados();
                                }
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: mes < 12 ? AppColors.primary : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          nombreMes,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      permitirNavegarMeses
                          ? 'Corte: $diaSeleccionado ${mesesNombres[mes - 1].substring(0, 3)}'
                          : diaSeleccionado == hoy.day
                              ? 'Hoy: Día ${hoy.day}'
                              : diaSeleccionado == 31
                                  ? 'Corte: Fin de mes'
                                  : 'Corte: Día $diaSeleccionado',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Cabecera L M X J V S D
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final d in diasSemanaHeader)
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),

              // Cuadrícula compacta
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: offsetPrimerDia + 31,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (ctx, index) {
                  if (index < offsetPrimerDia) {
                    return const SizedBox.shrink();
                  }

                  final diaNumero = index - offsetPrimerDia + 1;
                  final esDiaFaltante = diaNumero > diasEnMesActual;
                  final esHoy = diaNumero == hoy.day && mes == hoy.month && anio == hoy.year && !esDiaFaltante;
                  final esSeleccionado = diaNumero == diaSeleccionado;

                  return InkWell(
                    onTap: () => onDiaSelected(diaNumero),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: esSeleccionado
                            ? (esDiaFaltante ? AppColors.primary.withValues(alpha: 0.85) : AppColors.primary)
                            : esHoy
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : esDiaFaltante
                                    ? Colors.grey.shade50
                                    : AppColors.surfaceElevated.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: esSeleccionado
                              ? AppColors.primary
                              : esHoy
                                  ? AppColors.primary
                                  : esDiaFaltante
                                      ? AppColors.divider.withValues(alpha: 0.4)
                                      : AppColors.divider,
                          width: esSeleccionado || esHoy ? 1.5 : 1.0,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$diaNumero',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: esSeleccionado || esHoy ? FontWeight.bold : FontWeight.w500,
                              color: esSeleccionado
                                  ? Colors.white
                                  : esDiaFaltante
                                      ? AppColors.textMuted.withValues(alpha: 0.5)
                                      : esHoy
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                            ),
                          ),
                          if (esHoy)
                            Positioned(
                              bottom: 2,
                              child: Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: esSeleccionado ? Colors.white : AppColors.primary,
                                ),
                              ),
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
      ),
    );
  }

  Widget _buildCronogramaProyectado() {
    return Container(
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_note, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Cronograma Proyectado de Cortes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _proximosCortes.length; i++) ...[
            Builder(builder: (_) {
              final fecha = _proximosCortes[i];
              final esPrimero = i == 0;
              final montoInteres = esPrimero ? _interesPrimerCorte : _interesProyectado;
              final esProrrateadoEnPrimerCorte = esPrimero && _aplicaProrrateoPrimerCorte;

              return Padding(
                padding: EdgeInsets.only(bottom: i < _proximosCortes.length - 1 ? 10 : 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: esPrimero ? AppColors.primary : Colors.grey.shade200,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: esPrimero ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatearFechaCorta(fecha),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: esPrimero ? FontWeight.bold : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (esPrimero)
                            Text(
                              esProrrateadoEnPrimerCorte
                                  ? 'Primer corte en $_diasHastaPrimerCorte días (prorrateado)'
                                  : 'Primer corte en $_diasHastaPrimerCorte días',
                              style: TextStyle(
                                fontSize: 11,
                                color: esProrrateadoEnPrimerCorte ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: esProrrateadoEnPrimerCorte ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      montoInteres.formatBs(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: esPrimero ? AppColors.primaryDark : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ModalSelectorCliente extends StatefulWidget {
  final List<Cliente> clientes;
  final Cliente? clienteActual;
  final VoidCallback onCrearNuevo;

  const _ModalSelectorCliente({
    required this.clientes,
    required this.clienteActual,
    required this.onCrearNuevo,
  });

  @override
  State<_ModalSelectorCliente> createState() => _ModalSelectorClienteState();
}

class _ModalSelectorClienteState extends State<_ModalSelectorCliente> {
  final _searchCtrl = TextEditingController();
  String _filtro = '';
  bool _buscando = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    final queryLimpia = val.trim().toLowerCase();

    if (queryLimpia.isEmpty) {
      setState(() {
        _filtro = '';
        _buscando = false;
      });
      return;
    }

    setState(() {
      _buscando = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _filtro = queryLimpia;
          _buscando = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.clientes.where((c) {
      if (_filtro.isEmpty) return true;
      final matchNombre = c.nombre.toLowerCase().contains(_filtro);
      final matchApellido = c.apellido?.toLowerCase().contains(_filtro) ?? false;
      final matchAlias = c.alias?.toLowerCase().contains(_filtro) ?? false;
      final matchTel = c.telefonoPrincipal.contains(_filtro);
      return matchNombre || matchApellido || matchAlias || matchTel;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seleccionar Cliente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              TextButton.icon(
                onPressed: widget.onCrearNuevo,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Nuevo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            maxLength: 50,
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
                              _filtro = '';
                              _buscando = false;
                            });
                          },
                        )
                      : null),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtrados.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _buscando ? Icons.search : Icons.person_search_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _buscando
                                ? 'Buscando clientes...'
                                : (_filtro.isNotEmpty
                                    ? 'No se encontraron clientes para "$_filtro"'
                                    : 'No hay clientes registrados'),
                            style: const TextStyle(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          if (!_buscando) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: widget.onCrearNuevo,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Crear este Cliente'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : AnimatedOpacity(
                    opacity: _buscando ? 0.4 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final c = filtrados[i];
                      final esSeleccionado = c.id == widget.clienteActual?.id;

                      return InkWell(
                        onTap: () => Navigator.pop(context, c),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: esSeleccionado
                                ? AppColors.primary.withOpacity(0.06)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: esSeleccionado
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: esSeleccionado ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: esSeleccionado
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  c.nombre[0].toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: esSeleccionado ? Colors.white : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.nombreCompleto,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (c.alias != null && c.alias!.isNotEmpty)
                                      Text(
                                        '"${c.alias}"',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    Text(
                                      'WhatsApp: ${c.telefonoPrincipal}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (esSeleccionado)
                                const Icon(Icons.check_circle, color: AppColors.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
