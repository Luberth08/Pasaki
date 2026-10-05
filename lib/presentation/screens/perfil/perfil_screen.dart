import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/perfil_prestamista.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _nombreFormKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _nombreEditCtrl = TextEditingController();
  final _bancoController = TextEditingController();
  final _cuentaController = TextEditingController();
  final _cuentaEditCtrl = TextEditingController();

  bool _editandoNombre = false;
  bool _editandoCuenta = false;

  String? _qrBase64;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();

  static const List<String> _bancosDisponibles = [
    'Banco Unión',
    'Banco de Crédito BCP',
    'Banco Nacional de Bolivia (BNB)',
    'Banco Mercantil Santa Cruz',
    'Banco Bisa',
    'Banco Solidario (BancoSol)',
    'Banco FIE',
    'Banco Ganadero',
    'Banco Prodem',
    'Banco Fortaleza',
    'Banco Ecofuturo',
    'Banco Comunidad',
    'La Primera EFV',
    'Promujer IFD',
    'Idepro IFD',
    'Crecer IFD',
    'Diaconía IFD',
  ];

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _nombreEditCtrl.dispose();
    _bancoController.dispose();
    _cuentaController.dispose();
    _cuentaEditCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _isLoading = true);
    try {
      final perfil = await ServiceLocator.perfilRepo.obtenerPerfil();
      if (perfil != null) {
        _nombreController.text = perfil.nombreTitular;
        _bancoController.text = perfil.banco ?? '';
        _cuentaController.text = perfil.numeroCuenta ?? '';
        _qrBase64 = perfil.qrImageBase64;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _guardarAutomatico({String? mensaje}) async {
    try {
      final titular = _nombreController.text.trim();
      final perfil = PerfilPrestamista(
        id: 1,
        nombreTitular: titular.isEmpty ? 'Prestamista' : titular,
        banco: _bancoController.text.trim().isEmpty ? null : _bancoController.text.trim(),
        numeroCuenta: _cuentaController.text.trim().isEmpty ? null : _cuentaController.text.trim(),
        qrImageBase64: _qrBase64,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await ServiceLocator.perfilRepo.guardarPerfil(perfil);

      if (mounted && mensaje != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  Future<void> _abrirSelectorBanco() async {
    final bancoSeleccionado = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModalSelectorBanco(
        bancoActual: _bancoController.text.trim().isEmpty ? null : _bancoController.text.trim(),
        bancos: _bancosDisponibles,
      ),
    );

    if (bancoSeleccionado != null && mounted) {
      setState(() {
        _bancoController.text = bancoSeleccionado;
      });
      await _guardarAutomatico(mensaje: 'Banco actualizado a "$bancoSeleccionado"');
    }
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (file != null) {
        final rawBytes = await file.readAsBytes();
        if (!mounted) return;

        // Abrir pantalla de recorte y encuadre 1:1
        final bytesRecortados = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (_) => _PantallaRecorteQr(imageBytes: rawBytes),
          ),
        );

        if (bytesRecortados != null && mounted) {
          setState(() {
            _qrBase64 = base64Encode(bytesRecortados);
          });
          await _guardarAutomatico(mensaje: 'Imagen QR guardada');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la imagen: $e')),
        );
      }
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Seleccionar Imagen de QR',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  title: const Text('Elegir de Galería'),
                  subtitle: const Text('Podrás recortar y encuadrar solo el código QR'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _seleccionarImagen(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  title: const Text('Tomar Foto con Cámara'),
                  subtitle: const Text('Podrás recortar y encuadrar solo el código QR'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _seleccionarImagen(ImageSource.camera);
                  },
                ),
                if (_qrBase64 != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.mora),
                    title: const Text('Quitar imagen QR actual', style: TextStyle(color: AppColors.mora)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _qrBase64 = null);
                      _guardarAutomatico(mensaje: 'Imagen QR eliminada');
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarDialogoInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Perfil del Prestamista', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Los datos del titular, la cuenta bancaria y la imagen QR que configures aquí se vincularán automáticamente a todas las Fichas de Cobro que generes para tus clientes.',
                style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textPrimary),
              ),
              SizedBox(height: 14),
              Text(
                'Recomendación Simple QR Bolivia:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              SizedBox(height: 6),
              Text(
                'En tu app bancaria, generá tu código QR con:\n• Monto: Bs. 0.00 (monto abierto, para que el cliente ingrese lo que va a pagar).\n• Vencimiento: Fecha muy lejana (ej. año 2030 o sin límite).\n\nDe esta forma, este mismo QR te servirá para todos tus cobros sin vencer jamás.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil de Cobro', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Información de perfil',
            onPressed: _mostrarDialogoInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección: Datos del Titular / Cuenta
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos del Titular / Cuenta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 14),

                    // Campo 1: Nombre del Titular
                    if (!_editandoNombre)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Nombre del Titular *', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _nombreController.text.trim().isNotEmpty
                                        ? _nombreController.text.trim()
                                        : 'Sin nombre configurado',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _nombreController.text.trim().isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                                      fontStyle: _nombreController.text.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _nombreEditCtrl.text = _nombreController.text;
                                  _editandoNombre = true;
                                });
                              },
                              icon: Icon(_nombreController.text.trim().isNotEmpty ? Icons.edit_outlined : Icons.add, size: 16),
                              label: Text(_nombreController.text.trim().isNotEmpty ? 'Editar' : 'Agregar'),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: Form(
                          key: _nombreFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _nombreEditCtrl,
                                autofocus: true,
                                maxLength: 60,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre Completo del Prestamista / Titular *',
                                  hintText: 'Ej. Juan Pérez Vaca',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                  counterText: '',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'El nombre es obligatorio para las fichas de cobro';
                                  }
                                  if (v.trim().length > 60) {
                                    return 'Máximo 60 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => setState(() => _editandoNombre = false),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Cancelar'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      if (_nombreFormKey.currentState!.validate()) {
                                        setState(() {
                                          _nombreController.text = _nombreEditCtrl.text.trim();
                                          _editandoNombre = false;
                                        });
                                        await _guardarAutomatico(mensaje: 'Nombre actualizado');
                                      }
                                    },
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Guardar'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Campo 2: Banco / Entidad Financiera (Selector tipo Cliente de Nuevo Préstamo)
                    InkWell(
                      onTap: _abrirSelectorBanco,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.account_balance_outlined, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Banco / Entidad Financiera', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _bancoController.text.trim().isNotEmpty
                                        ? _bancoController.text.trim()
                                        : 'Toca para seleccionar banco...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _bancoController.text.trim().isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                                      fontStyle: _bancoController.text.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_bancoController.text.trim().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                tooltip: 'Quitar banco',
                                onPressed: () async {
                                  setState(() => _bancoController.clear());
                                  await _guardarAutomatico(mensaje: 'Banco eliminado');
                                },
                              ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 26),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo 3: Número de Cuenta Bancaria
                    if (!_editandoCuenta)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.credit_card_outlined, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Número de Cuenta Bancaria', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _cuentaController.text.trim().isNotEmpty
                                        ? _cuentaController.text.trim()
                                        : 'Sin número de cuenta',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _cuentaController.text.trim().isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                                      fontStyle: _cuentaController.text.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_cuentaController.text.trim().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                tooltip: 'Quitar cuenta',
                                onPressed: () async {
                                  setState(() => _cuentaController.clear());
                                  await _guardarAutomatico(mensaje: 'Número de cuenta eliminado');
                                },
                              ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _cuentaEditCtrl.text = _cuentaController.text;
                                  _editandoCuenta = true;
                                });
                              },
                              icon: Icon(_cuentaController.text.trim().isNotEmpty ? Icons.edit_outlined : Icons.add, size: 16),
                              label: Text(_cuentaController.text.trim().isNotEmpty ? 'Editar' : 'Agregar'),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _cuentaEditCtrl,
                              autofocus: true,
                              maxLength: 30,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9\- ]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Número de Cuenta Bancaria',
                                hintText: 'Ej. 10000012345678',
                                prefixIcon: Icon(Icons.credit_card_outlined),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => setState(() => _editandoCuenta = false),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    setState(() {
                                      _cuentaController.text = _cuentaEditCtrl.text.trim();
                                      _editandoCuenta = false;
                                    });
                                    await _guardarAutomatico(mensaje: 'Número de cuenta guardado');
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Guardar'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sección: Código QR de Cobro
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Imagen QR de Cobro Bancario',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        if (_qrBase64 != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                            tooltip: 'Cambiar imagen',
                            onPressed: _mostrarOpcionesImagen,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Subí una captura del QR generado por tu banco (Simple QR Bolivia u otros).',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),

                    // Tip informativo sobre monto 0.00 y fecha de vencimiento lejana
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Consejo Simple QR: Generá tu QR en la app del banco con monto Bs. 0.00 (abierto) y vencimiento lejano (ej. 2030) para que nunca caduque.',
                              style: TextStyle(fontSize: 12, color: AppColors.primaryDark, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_qrBase64 != null) ...[
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.divider),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.memory(
                              base64Decode(_qrBase64!),
                              height: 220,
                              width: 220,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _mostrarOpcionesImagen,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Cambiar Imagen QR'),
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _mostrarOpcionesImagen,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.divider,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 44, color: AppColors.primary),
                                SizedBox(height: 8),
                                Text(
                                  'Toca aquí para subir tu Imagen QR',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Galería o Cámara • Podrás encuadrar solo el QR',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Pantalla interactiva para recortar el código QR con máscara oscurecida y estilo PasaKi
class _PantallaRecorteQr extends StatefulWidget {
  final Uint8List imageBytes;

  const _PantallaRecorteQr({required this.imageBytes});

  @override
  State<_PantallaRecorteQr> createState() => _PantallaRecorteQrState();
}

class _PantallaRecorteQrState extends State<_PantallaRecorteQr> {
  final GlobalKey _viewportKey = GlobalKey();
  bool _procesando = false;

  Future<void> _confirmarRecorte(double cropSize) async {
    if (_procesando) return;
    setState(() => _procesando = true);

    try {
      final boundary = _viewportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context, widget.imageBytes);
        return;
      }

      final renderBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      final viewportSize = renderBox?.size ?? Size.zero;

      const pixelRatio = 3.0;
      final fullImage = await boundary.toImage(pixelRatio: pixelRatio);

      final cropWidth = cropSize * pixelRatio;
      final cropHeight = cropSize * pixelRatio;
      final centerX = (viewportSize.width * pixelRatio) / 2;
      final centerY = (viewportSize.height * pixelRatio) / 2;

      final srcRect = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: cropWidth,
        height: cropHeight,
      );
      final dstRect = Rect.fromLTWH(0, 0, cropWidth, cropHeight);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      canvas.drawImageRect(fullImage, srcRect, dstRect, Paint());

      final croppedUiImage = await recorder.endRecording().toImage(
        cropWidth.round(),
        cropHeight.round(),
      );

      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null && mounted) {
        final resultBytes = byteData.buffer.asUint8List();
        Navigator.pop(context, resultBytes);
      } else {
        if (mounted) Navigator.pop(context, widget.imageBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al recortar imagen: $e')),
        );
        setState(() => _procesando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cropSize = (screenSize.width - 48).clamp(220.0, 320.0);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Recortar Código QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _procesando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, color: Colors.white, size: 26),
            tooltip: 'Confirmar recorte',
            onPressed: _procesando ? null : () => _confirmarRecorte(cropSize),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de instrucción minimalista
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primaryDark,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.crop_free_rounded, color: AppColors.accent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ajustá el QR dentro del recuadro claro',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // Visor con imagen interactiva y máscara oscurecida exterior
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa 1: Imagen interactiva limpia
                  RepaintBoundary(
                    key: _viewportKey,
                    child: Container(
                      color: Colors.white,
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5.0,
                        boundaryMargin: const EdgeInsets.all(400),
                        child: Center(
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Capa 2: Máscara oscurecida con hueco transparente central
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _MascaraRecortePainter(cropSize: cropSize),
                    ),
                  ),
                ],
              ),
            ),

            // Barra inferior con botón de confirmación
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _procesando ? null : () => _confirmarRecorte(cropSize),
                  icon: const Icon(Icons.crop_rounded, size: 20),
                  label: const Text(
                    'Confirmar Recorte',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dibuja un overlay oscurecido sobre todo el canvas excepto el cuadrado central de recorte.
class _MascaraRecortePainter extends CustomPainter {
  final double cropSize;

  _MascaraRecortePainter({required this.cropSize});

  @override
  void paint(Canvas canvas, Size size) {
    final rectFull = Rect.fromLTWH(0, 0, size.width, size.height);
    final rectCrop = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cropSize,
      height: cropSize,
    );

    // Máscara oscurecida exterior
    final path = Path()
      ..addRect(rectFull)
      ..addRect(rectCrop)
      ..fillType = PathFillType.evenOdd;

    final paintMascara = Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paintMascara);

    // Borde fino del recuadro
    final paintBorde = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(rectCrop, paintBorde);

    // Brackets (esquinas de enfoque estilo scanner)
    const cornerLength = 22.0;
    final paintCorner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Top-Left
    canvas.drawLine(Offset(rectCrop.left, rectCrop.top + cornerLength), Offset(rectCrop.left, rectCrop.top), paintCorner);
    canvas.drawLine(Offset(rectCrop.left, rectCrop.top), Offset(rectCrop.left + cornerLength, rectCrop.top), paintCorner);

    // Top-Right
    canvas.drawLine(Offset(rectCrop.right - cornerLength, rectCrop.top), Offset(rectCrop.right, rectCrop.top), paintCorner);
    canvas.drawLine(Offset(rectCrop.right, rectCrop.top), Offset(rectCrop.right, rectCrop.top + cornerLength), paintCorner);

    // Bottom-Left
    canvas.drawLine(Offset(rectCrop.left, rectCrop.bottom - cornerLength), Offset(rectCrop.left, rectCrop.bottom), paintCorner);
    canvas.drawLine(Offset(rectCrop.left, rectCrop.bottom), Offset(rectCrop.left + cornerLength, rectCrop.bottom), paintCorner);

    // Bottom-Right
    canvas.drawLine(Offset(rectCrop.right - cornerLength, rectCrop.bottom), Offset(rectCrop.right, rectCrop.bottom), paintCorner);
    canvas.drawLine(Offset(rectCrop.right, rectCrop.bottom), Offset(rectCrop.right, rectCrop.bottom - cornerLength), paintCorner);
  }

  @override
  bool shouldRepaint(covariant _MascaraRecortePainter oldDelegate) => oldDelegate.cropSize != cropSize;
}

/// Modal Selector de Banco estilo Nuevo Préstamo con búsqueda optimizada para móviles de gama baja
/// y opción para agregar bancos personalizados.
class _ModalSelectorBanco extends StatefulWidget {
  final String? bancoActual;
  final List<String> bancos;

  const _ModalSelectorBanco({
    required this.bancoActual,
    required this.bancos,
  });

  @override
  State<_ModalSelectorBanco> createState() => _ModalSelectorBancoState();
}

class _ModalSelectorBancoState extends State<_ModalSelectorBanco> {
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  String _filtro = '';
  bool _buscando = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (!_buscando) {
      setState(() => _buscando = true);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _filtro = val.trim().toLowerCase();
          _buscando = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final queryLimpia = _searchCtrl.text.trim();
    final filtrados = widget.bancos.where((b) {
      if (_filtro.isEmpty) return true;
      return b.toLowerCase().contains(_filtro);
    }).toList();

    final existeExacto = widget.bancos.any(
      (b) => b.trim().toLowerCase() == queryLimpia.toLowerCase(),
    );
    final puedeAgregarNuevo = queryLimpia.isNotEmpty && !existeExacto;

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
          // Barra de agarre superior
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seleccionar Banco',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Buscador con debounce y feedback visual para gama baja
          TextField(
            controller: _searchCtrl,
            maxLength: 50,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Buscar banco o entidad financiera...',
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

          // Opción para añadir banco si no está en la lista o se escribe uno nuevo
          if (puedeAgregarNuevo) ...[
            InkWell(
              onTap: () => Navigator.pop(context, queryLimpia),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Añadir "$queryLimpia"',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            'Usar como nombre de banco para tu perfil',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Lista de bancos
          Expanded(
            child: filtrados.isEmpty && !puedeAgregarNuevo
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _buscando ? Icons.search : Icons.account_balance_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _buscando
                                ? 'Buscando bancos...'
                                : 'No se encontraron resultados para "$queryLimpia"',
                            style: const TextStyle(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          if (!_buscando && queryLimpia.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context, queryLimpia),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text('Añadir "$queryLimpia"'),
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
                        final b = filtrados[i];
                        final esSeleccionado = b == widget.bancoActual;

                        return InkWell(
                          onTap: () => Navigator.pop(context, b),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: esSeleccionado
                                  ? AppColors.primary.withValues(alpha: 0.08)
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
                                  radius: 18,
                                  backgroundColor: esSeleccionado
                                      ? AppColors.primary
                                      : AppColors.primary.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.account_balance_outlined,
                                    size: 18,
                                    color: esSeleccionado ? Colors.white : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    b,
                                    style: TextStyle(
                                      fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 14.5,
                                      color: esSeleccionado ? AppColors.primaryDark : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (esSeleccionado)
                                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
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
