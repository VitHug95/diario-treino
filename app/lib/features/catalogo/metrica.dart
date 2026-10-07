/// Métrica disponível para medir (GET /api/v1/metricas). Espelha o
/// MetricaResumo da API.
class Metrica {
  const Metrica({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.unidade,
    required this.eixo,
  });

  final int id;
  final String codigo;
  final String nome;
  final String unidade;
  final String eixo; // INTENSIDADE | VOLUME

  bool get ehIntensidade => eixo == 'INTENSIDADE';
  bool get ehVolume => eixo == 'VOLUME';

  factory Metrica.doJson(Map<String, dynamic> json) => Metrica(
        id: (json['id'] as num).toInt(),
        codigo: json['codigo'] as String,
        nome: json['nome'] as String,
        unidade: json['unidade'] as String,
        eixo: json['eixo'] as String,
      );
}

/// Códigos de métrica usados nas sugestões por tipo (MER 3.4).
abstract final class MetricaCodigos {
  static const cargaKg = 'CARGA_KG';
  static const pesoCorporal = 'PESO_CORPORAL';
  static const zona = 'ZONA';
  static const repeticoes = 'REPETICOES';
  static const tempoSeg = 'TEMPO_SEG';
}
