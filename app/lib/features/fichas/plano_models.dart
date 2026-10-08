/// Plano ativo com suas fichas (GET /api/v1/planos/ativo).
class PlanoAtivo {
  const PlanoAtivo({required this.id, required this.nome, required this.treinos});

  final String id;
  final String nome;
  final List<TreinoResumo> treinos;

  factory PlanoAtivo.doJson(Map<String, dynamic> json) => PlanoAtivo(
        id: json['id'] as String,
        nome: json['nome'] as String,
        treinos: (json['treinos'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(TreinoResumo.doJson)
            .toList(),
      );
}

/// Ficha com seus exercícios prescritos (GET /api/v1/treinos/{id}).
class TreinoDetalhe {
  const TreinoDetalhe({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.ordem,
    required this.exercicios,
  });

  final String id;
  final String nome;
  final String? descricao;
  final int ordem;
  final List<TreinoExercicioResumo> exercicios;

  factory TreinoDetalhe.doJson(Map<String, dynamic> json) => TreinoDetalhe(
        id: json['id'] as String,
        nome: json['nome'] as String,
        descricao: json['descricao'] as String?,
        ordem: (json['ordem'] as num).toInt(),
        exercicios: (json['exercicios'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(TreinoExercicioResumo.doJson)
            .toList(),
      );
}

/// Exercício prescrito dentro de uma ficha, com os alvos (PBI-14).
class TreinoExercicioResumo {
  const TreinoExercicioResumo({
    required this.id,
    required this.exercicioId,
    required this.nome,
    required this.grupoMuscular,
    required this.modalidade,
    required this.ordem,
    required this.rodadas,
    required this.descansoSeg,
    required this.instrucao,
    required this.alvo,
  });

  final String id;
  final String exercicioId;
  final String nome;
  final String? grupoMuscular;
  final String modalidade;
  final int ordem;
  final int rodadas;

  /// Descanso-alvo entre séries, em segundos. Nulo até definir.
  final int? descansoSeg;

  /// Instrução livre (ex.: "cadência lenta"). Nula se não houver.
  final String? instrucao;

  /// Alvos prescritos (intensidade/volume). Nulo até o atleta definir.
  final AlvoExercicio? alvo;

  /// Já tem alvos definidos (etapa de esforço gravada).
  bool get temAlvo => alvo != null;

  factory TreinoExercicioResumo.doJson(Map<String, dynamic> json) =>
      TreinoExercicioResumo(
        id: json['id'] as String,
        exercicioId: json['exercicioId'] as String,
        nome: json['nome'] as String,
        grupoMuscular: json['grupoMuscular'] as String?,
        modalidade: json['modalidade'] as String,
        ordem: (json['ordem'] as num).toInt(),
        rodadas: (json['rodadas'] as num).toInt(),
        descansoSeg: (json['descansoSeg'] as num?)?.toInt(),
        instrucao: json['instrucao'] as String?,
        alvo: json['alvo'] == null
            ? null
            : AlvoExercicio.doJson(json['alvo'] as Map<String, dynamic>),
      );
}

/// Alvos prescritos de um exercício (etapa de esforço). Espelha o
/// AlvoExercicio da API.
class AlvoExercicio {
  const AlvoExercicio({
    required this.intensidadeMetricaId,
    required this.intensidadeMetricaCodigo,
    required this.intensidadeMetricaNome,
    required this.intensidadeAlvo,
    required this.volumeMetricaId,
    required this.volumeMetricaCodigo,
    required this.volumeMetricaNome,
    required this.volumeAlvo,
  });

  final int intensidadeMetricaId;
  final String intensidadeMetricaCodigo;
  final String intensidadeMetricaNome;
  final double? intensidadeAlvo;
  final int volumeMetricaId;
  final String volumeMetricaCodigo;
  final String volumeMetricaNome;
  final double? volumeAlvo;

  factory AlvoExercicio.doJson(Map<String, dynamic> json) => AlvoExercicio(
        intensidadeMetricaId: (json['intensidadeMetricaId'] as num).toInt(),
        intensidadeMetricaCodigo: json['intensidadeMetricaCodigo'] as String,
        intensidadeMetricaNome: json['intensidadeMetricaNome'] as String,
        intensidadeAlvo: (json['intensidadeAlvo'] as num?)?.toDouble(),
        volumeMetricaId: (json['volumeMetricaId'] as num).toInt(),
        volumeMetricaCodigo: json['volumeMetricaCodigo'] as String,
        volumeMetricaNome: json['volumeMetricaNome'] as String,
        volumeAlvo: (json['volumeAlvo'] as num?)?.toDouble(),
      );
}

/// Ficha dentro do plano.
class TreinoResumo {
  const TreinoResumo({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.ordem,
  });

  final String id;
  final String nome;
  final String? descricao;
  final int ordem;

  factory TreinoResumo.doJson(Map<String, dynamic> json) => TreinoResumo(
        id: json['id'] as String,
        nome: json['nome'] as String,
        descricao: json['descricao'] as String?,
        ordem: (json['ordem'] as num).toInt(),
      );
}
