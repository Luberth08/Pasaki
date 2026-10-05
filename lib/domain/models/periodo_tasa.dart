enum PeriodoTasa {
  diario('Diario', 1),
  semanal('Semanal', 7),
  quincenal('Quincenal', 15),
  mensual('Mensual', 30),
  anual('Anual', 360);

  final String etiqueta;
  final int diasReferencia;
  const PeriodoTasa(this.etiqueta, this.diasReferencia);
}
