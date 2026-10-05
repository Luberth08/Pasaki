import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Habilitar soporte de SQLite en Web (Chrome) vía WebAssembly / IndexedDB
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Inicialización de la base de datos local SQLite y casos de uso
  await ServiceLocator.initialize();

  runApp(const PasakiApp());
}

class PasakiApp extends StatelessWidget {
  const PasakiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PasaKi - Microcréditos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
