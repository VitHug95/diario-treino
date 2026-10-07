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
