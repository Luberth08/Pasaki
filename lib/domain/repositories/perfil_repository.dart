import '../models/perfil_prestamista.dart';

abstract class PerfilRepository {
  Future<PerfilPrestamista?> obtenerPerfil();
  Future<void> guardarPerfil(PerfilPrestamista perfil);
}
