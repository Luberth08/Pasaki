/// Tipos de transacciones registradas en el libro contable (Ledger) del préstamo.
enum TipoMovimiento {
  desembolso('Desembolso'),
  interesGenerado('Interés Generado'),
  pago('Pago'),
  condonacion('Condonación'),
  reestructuracion('Reestructuración'),
  congelacion('Congelación'),
  descongelacion('Descongelación');

  final String etiqueta;
  const TipoMovimiento(this.etiqueta);
}
