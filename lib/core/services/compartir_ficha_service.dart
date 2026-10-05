import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/ficha_cobro.dart';
import '../di/service_locator.dart';

/// Servicio para compartir fichas de cobro usando la hoja nativa del sistema.
/// Escribe la imagen QR en caché temporal para que Android/iOS y WhatsApp
/// puedan adjuntarla como archivo real junto al texto del cobro.
class CompartirFichaService {
  static Future<void> compartir(FichaCobro ficha) async {
    // 1. Obtener imagen QR (de la ficha o del perfil del prestamista)
    String? qrBase64 = ficha.qrData;
    if (qrBase64 == null || qrBase64.length < 50) {
      final perfil = await ServiceLocator.perfilRepo.obtenerPerfil();
      qrBase64 = perfil?.qrImageBase64;
    }

    // 2. Si hay QR y estamos en móvil/escritorio, escribir a archivo temporal
    if (!kIsWeb && qrBase64 != null && qrBase64.length > 50) {
      try {
        final bytes = base64Decode(qrBase64);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/qr_cobro.png');
        await file.writeAsBytes(bytes, flush: true);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png', name: 'qr_cobro.png')],
            text: ficha.mensajeWhatsApp,
          ),
        );
        return;
      } catch (e) {
        debugPrint('Error al compartir con archivo físico: $e');
      }
    }

    // 3. Fallback en caso de web o si no hay imagen QR configurada
    await SharePlus.instance.share(ShareParams(text: ficha.mensajeWhatsApp));
  }
}
