import 'package:flutter/material.dart';

/// Paleta de colores "Emerald Forest" diseñada para el dominio financiero de PasaKi.
class AppColors {
  // Primarios: Tonos Verde Esmeralda / Jade
  static const Color primary = Color(0xFF0F766E); // Esmeralda profundo
  static const Color primaryLight = Color(0xFF059669); // Esmeralda vibrante
  static const Color primaryDark = Color(0xFF134E4A); // Bosque oscuro

  // Acentos y estados positivos
  static const Color accent = Color(0xFF10B981); // Menta fresca / Al día
  static const Color accentLight = Color(0xFFD1FAE5); // Fondo menta suave

  // Semáforos de riesgo y alertas (RNF-11)
  static const Color mora = Color(0xFFEF4444); // Rojo coral para clientes con mora
  static const Color moraLight = Color(0xFFFEE2E2); // Fondo suave para alertas de mora
  static const Color advertencia = Color(0xFFF59E0B); // Ámbar para atención
  static const Color advertenciaLight = Color(0xFFFEF3C7);

  // Superficies y neutros
  static const Color background = Color(0xFFF8FAFC); // Blanco pizarra limpio
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Color(0xFFF1F5F9);

  // Textos y divisores
  static const Color textPrimary = Color(0xFF0F172A); // Casi negro para legibilidad
  static const Color textSecondary = Color(0xFF64748B); // Gris pizarra medio
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color divider = Color(0xFFE2E8F0);
}
