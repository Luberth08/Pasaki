import '../models/ficha_cobro.dart';

abstract class IFichaCobroRepository {
  Future<FichaCobro> guardar(FichaCobro ficha);
  Future<List<FichaCobro>> obtenerPorPrestamo(int prestamoId);
  Future<List<FichaCobro>> obtenerPendientesPorPrestamo(int prestamoId);
  Future<FichaCobro?> obtenerPorId(int id);
  Future<void> actualizarEstado(int fichaId, String estado, {int? fechaCobro});
  Future<int> contarPendientesPorPrestamo(int prestamoId);
}
