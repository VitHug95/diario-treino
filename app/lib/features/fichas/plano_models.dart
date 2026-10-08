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

/// Exercício prescrito dentro de uma ficha.
class TreinoExercicioResumo {
  const TreinoExercicioResumo({
    required this.id,
    required this.exercicioId,
    required this.nome,
    required this.grupoMuscular,
    required this.modalidade,
    required this.ordem,
    required this.rodadas,
  });

  final String id;
  final String exercicioId;
  final String nome;
  final String? grupoMuscular;
  final String modalidade;
  final int ordem;
  final int rodadas;

  factory TreinoExercicioResumo.doJson(Map<String, dynamic> json) =>
      TreinoExercicioResumo(
        id: json['id'] as String,
        exercicioId: json['exercicioId'] as String,
        nome: json['nome'] as String,
        grupoMuscular: json['grupoMuscular'] as String?,
        modalidade: json['modalidade'] as String,
        ordem: (json['ordem'] as num).toInt(),
        rodadas: (json['rodadas'] as num).toInt(),
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
