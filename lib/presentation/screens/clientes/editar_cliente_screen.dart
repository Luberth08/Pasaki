import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/cliente.dart';
import '../../../domain/models/contacto.dart';

class EditarClienteScreen extends StatefulWidget {
  final Cliente cliente;

  const EditarClienteScreen({super.key, required this.cliente});

  @override
  State<EditarClienteScreen> createState() => _EditarClienteScreenState();
}

class _EditarClienteScreenState extends State<EditarClienteScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _aliasCtrl;
  late final TextEditingController _ciCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;

  List<Contacto> _contactosSecundarios = [];

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nombreCtrl = TextEditingController(text: c.nombre);
    _apellidoCtrl = TextEditingController(text: c.apellido ?? '');
    _aliasCtrl = TextEditingController(text: c.alias ?? '');
    _ciCtrl = TextEditingController(text: c.ci ?? '');
    _telefonoCtrl = TextEditingController(text: c.telefonoPrincipal);
    _direccionCtrl = TextEditingController(text: c.direccion ?? '');

    _contactosSecundarios = List<Contacto>.from(c.contactos);
  }

  Future<void> _abrirDialogoContacto({int? index}) async {
    final contactoExistente = index != null ? _contactosSecundarios[index] : null;
    final telCtrl = TextEditingController(text: contactoExistente?.telefono ?? '');
    final etiqCtrl = TextEditingController(text: contactoExistente?.etiqueta ?? '');
    final formDialogKey = GlobalKey<FormState>();

    final resultado = await showDialog<Contacto>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(index == null ? 'Agregar Teléfono Secundario' : 'Editar Teléfono Secundario'),
          content: Form(
            key: formDialogKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 20,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'Número de Teléfono *',
                    hintText: 'Ej: 71198765',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingresá el número de teléfono';
                    }
                    if (val.trim().length < 7) {
                      return 'Mínimo 7 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: etiqCtrl,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'Etiqueta (Opcional)',
                    hintText: 'Ej: Esposa, Taller, Hermano',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formDialogKey.currentState!.validate()) return;
                final now = DateTime.now().millisecondsSinceEpoch;
                final contacto = Contacto(
                  id: contactoExistente?.id,
                  clienteId: widget.cliente.id ?? 0,
                  telefono: telCtrl.text.trim(),
                  etiqueta: etiqCtrl.text.trim().isNotEmpty ? etiqCtrl.text.trim() : null,
                  createdAt: contactoExistente?.createdAt ?? now,
                  updatedAt: now,
                );
                Navigator.pop(ctx, contacto);
              },
              child: Text(index == null ? 'Agregar' : 'Guardar'),
            ),
          ],
        );
      },
    );

    if (resultado != null) {
      setState(() {
        if (index == null) {
          _contactosSecundarios.add(resultado);
        } else {
          _contactosSecundarios[index] = resultado;
        }
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _aliasCtrl.dispose();
    _ciCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      await ServiceLocator.actualizarCliente.execute(
        id: widget.cliente.id!,
        nombre: _nombreCtrl.text,
        apellido: _apellidoCtrl.text,
        alias: _aliasCtrl.text,
        ci: _ciCtrl.text,
        telefonoPrincipal: _telefonoCtrl.text,
        direccion: _direccionCtrl.text,
        genero: widget.cliente.genero,
        fechaNacimiento: widget.cliente.fechaNacimiento,
        esListaNegra: widget.cliente.esListaNegra,
        contactos: _contactosSecundarios,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Información del cliente actualizada correctamente.'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "").replaceAll("ArgumentError: ", "").replaceAll("StateError: ", "")}'),
            backgroundColor: AppColors.mora,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Cliente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Datos Principales (Obligatorios)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreCtrl,
                maxLength: 50,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Nombre *',
                  hintText: 'Ej: René',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresá el nombre del cliente';
                  if (val.trim().length > 50) return 'Máximo 50 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 20,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Teléfono Principal (WhatsApp) *',
                  hintText: 'Ej: 70012345 o +59170012345',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresá el teléfono de cobro';
                  if (val.trim().length < 7) return 'El teléfono debe tener al menos 7 dígitos';
                  if (val.trim().length > 20) return 'Máximo 20 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Datos de Referencia y Negocio (Opcionales)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _aliasCtrl,
                maxLength: 40,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Alias / Apodo del Cliente',
                  hintText: 'Ej: El mecánico, Doña Mary verduras',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _apellidoCtrl,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'Apellido',
                        hintText: 'Ej: Vaca',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ciCtrl,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'Cédula (CI)',
                        hintText: 'Ej: 4589234 SC',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccionCtrl,
                maxLength: 120,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Dirección o Ubicación',
                  hintText: 'Ej: Barrio Los Pozos, calle 3 #45',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Teléfonos Secundarios',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _abrirDialogoContacto(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_contactosSecundarios.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider.withOpacity(0.6)),
                  ),
                  child: const Center(
                    child: Text(
                      'No hay números secundarios registrados.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...List.generate(_contactosSecundarios.length, (i) {
                  final c = _contactosSecundarios[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary.withOpacity(0.08),
                          child: const Icon(Icons.phone_outlined, size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.telefono,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (c.etiqueta != null && c.etiqueta!.isNotEmpty)
                                Text(
                                  c.etiqueta!,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                          tooltip: 'Editar',
                          onPressed: () => _abrirDialogoContacto(index: i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.mora),
                          tooltip: 'Eliminar',
                          onPressed: () {
                            setState(() {
                              _contactosSecundarios.removeAt(i);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _guardando ? null : _guardarCambios,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar Cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
