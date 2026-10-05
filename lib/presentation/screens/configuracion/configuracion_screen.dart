import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../perfil/perfil_screen.dart';

/// Pantalla principal de Configuración del sistema.
class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  double _tasaPredeterminada = 20.0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguraciones();
  }

  Future<void> _cargarConfiguraciones() async {
    try {
      final tasa = await ServiceLocator.configuracionRepo.obtenerTasaPredeterminada();
      if (mounted) {
        setState(() {
          _tasaPredeterminada = tasa;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editarTasaPredeterminada() async {
    final formKey = GlobalKey<FormState>();
    final textoInicial = _tasaPredeterminada.truncateToDouble() == _tasaPredeterminada
        ? _tasaPredeterminada.toInt().toString()
        : _tasaPredeterminada.toString();
    final ctrl = TextEditingController(text: textoInicial);

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.percent_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Tasa Predeterminada', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta tasa se completará automáticamente al momento de registrar cualquier nuevo préstamo.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                maxLength: 5,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Tasa mensual / periódica (%)',
                  hintText: 'Ej: 20',
                  suffixText: '%',
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresá un porcentaje';
                  final numVal = double.tryParse(val.trim());
                  if (numVal == null) return 'Porcentaje no válido';
                  if (numVal < 0) return 'No puede ser negativo';
                  if (numVal > 500) return 'Máximo 500%';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardado == true && mounted) {
      final nuevaTasa = double.tryParse(ctrl.text.trim()) ?? 20.0;
      await ServiceLocator.configuracionRepo.guardarTasaPredeterminada(nuevaTasa);
      setState(() => _tasaPredeterminada = nuevaTasa);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tasa predeterminada actualizada a ${ctrl.text}%'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final tasaFormateada = _tasaPredeterminada.truncateToDouble() == _tasaPredeterminada
        ? '${_tasaPredeterminada.toInt()}%'
        : '$_tasaPredeterminada%';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'Configuración',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ajustes del sistema y preferencias de préstamos',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Sección: Datos del Prestamista
        const Text(
          'DATOS DEL PRESTAMISTA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: AppColors.accentLight,
              child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 22),
            ),
            title: const Text('Perfil del Prestamista', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Nombre titular, cuenta bancaria y código QR para cobros', style: TextStyle(fontSize: 12.5)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Sección: Preferencias de Préstamos
        const Text(
          'PREFERENCIAS DE PRÉSTAMOS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: AppColors.accentLight,
              child: const Icon(Icons.percent_rounded, color: AppColors.primary, size: 20),
            ),
            title: const Text('Tasa de Interés Predeterminada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Tasa cargada por defecto al crear nuevos préstamos', style: TextStyle(fontSize: 12.5)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tasaFormateada,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              ],
            ),
            onTap: _editarTasaPredeterminada,
          ),
        ),
        const SizedBox(height: 24),

        // Sección: Información
        const Text(
          'INFORMACIÓN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceElevated,
                  child: const Icon(Icons.smartphone_rounded, color: AppColors.textSecondary, size: 20),
                ),
                title: const Text('PasaKi Microcréditos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Versión 1.0.0 • SQLite Offline Local', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
