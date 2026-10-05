/// Contrato del repositorio de configuraciones de la aplicación.
abstract interface class IConfiguracionRepository {
  /// Obtiene la tasa de interés predeterminada configurada para nuevos préstamos (por defecto 20.0).
  Future<double> obtenerTasaPredeterminada();

  /// Guarda una nueva tasa de interés predeterminada.
  Future<void> guardarTasaPredeterminada(double tasa);
}
