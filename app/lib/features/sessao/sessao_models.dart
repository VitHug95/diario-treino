/// Rascunho de sessão vindo de GET /api/v1/treinos/{id}/rascunho-sessao.
/// Espelha o RascunhoSessao da API (PBI-15).
class RascunhoSessao {
  const RascunhoSessao({
    required this.treinoId,
    required this.treinoNome,
    required this.data,
    required this.exercicios,
  });

  final String treinoId;
  final String treinoNome;
  final DateTime data;
  final List<RascunhoExercicio> exercicios;

  factory RascunhoSessao.doJson(Map<String, dynamic> json) => RascunhoSessao(
        treinoId: json['treinoId'] as String,
        treinoNome: json['treinoNome'] as String,
        data: DateTime.parse(json['data'] as String),
        exercicios: (json['exercicios'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(RascunhoExercicio.doJson)
            .toList(),
      );
}

/// Exercício do rascunho, com o aviso de origem do pré-preenchimento.
class RascunhoExercicio {
  const RascunhoExercicio({
    required this.treinoExercicioId,
    required this.exercicioId,
    required this.nome,
    required this.grupoMuscular,
    required this.modalidade,
    required this.ordem,
    required this.origemPreenchimento,
    required this.series,
  });

  final String treinoExercicioId;
  final String exercicioId;
  final String nome;
  final String? grupoMuscular;
  final String modalidade;
  final int ordem;

  /// Aviso de onde veio o preenchimento (ex.: "Preenchido com o último
  /// treino (27/09)"). Nulo quando não há séries sugeridas.
  final String? origemPreenchimento;

  final List<SerieRascunho> series;

  factory RascunhoExercicio.doJson(Map<String, dynamic> json) =>
      RascunhoExercicio(
        treinoExercicioId: json['treinoExercicioId'] as String,
        exercicioId: json['exercicioId'] as String,
        nome: json['nome'] as String,
        grupoMuscular: json['grupoMuscular'] as String?,
        modalidade: json['modalidade'] as String,
        ordem: (json['ordem'] as num).toInt(),
        origemPreenchimento: json['origemPreenchimento'] as String?,
        series: (json['series'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SerieRascunho.doJson)
            .toList(),
      );
}

/// Série sugerida no rascunho (par intensidade/volume).
class SerieRascunho {
  const SerieRascunho({
    required this.rodada,
    required this.ordem,
    required this.tipo,
    required this.intensidadeMetricaId,
    required this.intensidadeMetricaCodigo,
    required this.intensidadeMetricaNome,
    required this.intensidade,
    required this.volumeMetricaId,
    required this.volumeMetricaCodigo,
    required this.volumeMetricaNome,
    required this.volume,
    required this.descansoSeg,
  });

  final int rodada;
  final int ordem;
  final String tipo;
  final int intensidadeMetricaId;
  final String intensidadeMetricaCodigo;
  final String intensidadeMetricaNome;
  final double? intensidade;
  final int volumeMetricaId;
  final String volumeMetricaCodigo;
  final String volumeMetricaNome;
  final double? volume;
  final int? descansoSeg;

  /// Peso corporal não tem valor de intensidade a digitar (MER 3.11).
  bool get intensidadePorPesoCorporal =>
      intensidadeMetricaCodigo == 'PESO_CORPORAL';

  factory SerieRascunho.doJson(Map<String, dynamic> json) => SerieRascunho(
        rodada: (json['rodada'] as num).toInt(),
        ordem: (json['ordem'] as num).toInt(),
        tipo: json['tipo'] as String,
        intensidadeMetricaId: (json['intensidadeMetricaId'] as num).toInt(),
        intensidadeMetricaCodigo: json['intensidadeMetricaCodigo'] as String,
        intensidadeMetricaNome: json['intensidadeMetricaNome'] as String,
        intensidade: (json['intensidade'] as num?)?.toDouble(),
        volumeMetricaId: (json['volumeMetricaId'] as num).toInt(),
        volumeMetricaCodigo: json['volumeMetricaCodigo'] as String,
        volumeMetricaNome: json['volumeMetricaNome'] as String,
        volume: (json['volume'] as num?)?.toDouble(),
        descansoSeg: (json['descansoSeg'] as num?)?.toInt(),
      );
}
