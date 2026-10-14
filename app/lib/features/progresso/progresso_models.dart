/// Exercício que o atleta já treinou (GET /api/v1/progresso/exercicios),
/// para o seletor do gráfico (PBI-20).
class ExercicioComHistorico {
  const ExercicioComHistorico({
    required this.id,
    required this.nome,
    required this.modalidade,
  });

  final String id;
  final String nome;
  final String modalidade;

  factory ExercicioComHistorico.doJson(Map<String, dynamic> json) =>
      ExercicioComHistorico(
        id: json['id'] as String,
        nome: json['nome'] as String,
        modalidade: json['modalidade'] as String,
      );
}

/// Evolução de um exercício (GET /api/v1/progresso/exercicios/{id}, PBI-20).
class ProgressoExercicio {
  const ProgressoExercicio({
    required this.exercicioId,
    required this.nome,
    required this.modalidade,
    required this.metrica,
    required this.pontos,
    required this.resumo,
  });

  final String exercicioId;
  final String nome;
  final String modalidade;

  /// "CARGA" (força), "TEMPO" (isometria) ou nulo (sem gráfico no MVP).
  final String? metrica;

  final List<PontoProgresso> pontos;
  final ResumoProgresso resumo;

  bool get temGrafico => metrica != null;

  factory ProgressoExercicio.doJson(Map<String, dynamic> json) =>
      ProgressoExercicio(
        exercicioId: json['exercicioId'] as String,
        nome: json['nome'] as String,
        modalidade: json['modalidade'] as String,
        metrica: json['metrica'] as String?,
        pontos: (json['pontos'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(PontoProgresso.doJson)
            .toList(),
        resumo: ResumoProgresso.doJson(json['resumo'] as Map<String, dynamic>),
      );
}

/// Um ponto do gráfico (uma sessão). Força: valor = carga, repeticoes = reps
/// daquela carga. Isometria: valor = tempo, repeticoes nulo.
class PontoProgresso {
  const PontoProgresso({
    required this.data,
    required this.valor,
    required this.repeticoes,
  });

  final DateTime data;
  final double valor;
  final double? repeticoes;

  factory PontoProgresso.doJson(Map<String, dynamic> json) => PontoProgresso(
        data: DateTime.parse(json['data'] as String),
        valor: (json['valor'] as num).toDouble(),
        repeticoes: (json['repeticoes'] as num?)?.toDouble(),
      );
}

/// Resumo do período do gráfico.
class ResumoProgresso {
  const ResumoProgresso({
    required this.sessoes,
    required this.variacao,
    required this.sessoesComObservacao,
  });

  final int sessoes;
  final double? variacao;
  final int sessoesComObservacao;

  factory ResumoProgresso.doJson(Map<String, dynamic> json) => ResumoProgresso(
        sessoes: (json['sessoes'] as num).toInt(),
        variacao: (json['variacao'] as num?)?.toDouble(),
        sessoesComObservacao: (json['sessoesComObservacao'] as num).toInt(),
      );
}
