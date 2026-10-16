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

/// Um plano na lista de planos (GET /api/v1/planos, PBI-44/45). Espelha o
/// `PlanoDaLista` da API.
class PlanoDaLista {
  const PlanoDaLista({
    required this.id,
    required this.nome,
    required this.inicio,
    required this.emUso,
    required this.autor,
    required this.somenteLeitura,
    required this.quantidadeFichas,
    required this.quantidadeExercicios,
  });

  final String id;
  final String nome;
  final DateTime inicio;

  /// O plano que a Início segue. No máximo um por atleta.
  final bool emUso;

  /// Nome do autor (para "Prof. Nome" quando não é o próprio atleta).
  final String autor;

  /// Plano do professor (autor ≠ atleta): o atleta só lê, treina e copia.
  final bool somenteLeitura;

  final int quantidadeFichas;
  final int quantidadeExercicios;

  factory PlanoDaLista.doJson(Map<String, dynamic> json) => PlanoDaLista(
        id: json['id'] as String,
        nome: json['nome'] as String,
        inicio: DateTime.parse(json['inicio'] as String),
        emUso: json['emUso'] as bool,
        autor: (json['autor'] as String?) ?? '',
        somenteLeitura: json['somenteLeitura'] as bool,
        quantidadeFichas: (json['quantidadeFichas'] as num).toInt(),
        quantidadeExercicios: (json['quantidadeExercicios'] as num).toInt(),
      );
}

/// Ordena a lista de planos: em uso primeiro, depois pelo início mais recente
/// (PBI-45). A API já devolve nessa ordem; reordenar aqui deixa a tela
/// determinística independentemente do servidor.
List<PlanoDaLista> ordenarPlanos(List<PlanoDaLista> planos) {
  final copia = [...planos];
  copia.sort((a, b) {
    if (a.emUso != b.emUso) return a.emUso ? -1 : 1;
    return b.inicio.compareTo(a.inicio);
  });
  return copia;
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
    this.marcadores = const [],
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

  /// Tags prescritas por rodada (TV-1). Só rodadas com tag ≠ VALIDA vêm aqui.
  final List<MarcadorRodada> marcadores;

  /// Já tem alvos definidos (etapa de esforço gravada).
  bool get temAlvo => alvo != null;

  /// Tag prescrita de uma rodada (1-based), ou 'VALIDA' se não houver.
  String marcadorDaRodada(int rodada) =>
      marcadores
          .where((m) => m.rodada == rodada)
          .map((m) => m.marcador)
          .firstOrNull ??
      'VALIDA';

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
        marcadores: ((json['marcadores'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(MarcadorRodada.doJson)
            .toList(),
      );
}

/// Tag prescrita de uma rodada de um exercício da ficha (TV-1). Espelha o
/// MarcadorRodada da API.
class MarcadorRodada {
  const MarcadorRodada({required this.rodada, required this.marcador});

  final int rodada;
  final String marcador;

  factory MarcadorRodada.doJson(Map<String, dynamic> json) => MarcadorRodada(
        rodada: (json['rodada'] as num).toInt(),
        marcador: json['marcador'] as String,
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
    this.volumeAlvoMax,
  });

  final int intensidadeMetricaId;
  final String intensidadeMetricaCodigo;
  final String intensidadeMetricaNome;
  final double? intensidadeAlvo;
  final int volumeMetricaId;
  final String volumeMetricaCodigo;
  final String volumeMetricaNome;
  final double? volumeAlvo;

  /// Máximo da faixa de volume (TV-2); nulo = sem faixa.
  final double? volumeAlvoMax;

  factory AlvoExercicio.doJson(Map<String, dynamic> json) => AlvoExercicio(
        intensidadeMetricaId: (json['intensidadeMetricaId'] as num).toInt(),
        intensidadeMetricaCodigo: json['intensidadeMetricaCodigo'] as String,
        intensidadeMetricaNome: json['intensidadeMetricaNome'] as String,
        intensidadeAlvo: (json['intensidadeAlvo'] as num?)?.toDouble(),
        volumeMetricaId: (json['volumeMetricaId'] as num).toInt(),
        volumeMetricaCodigo: json['volumeMetricaCodigo'] as String,
        volumeMetricaNome: json['volumeMetricaNome'] as String,
        volumeAlvo: (json['volumeAlvo'] as num?)?.toDouble(),
        volumeAlvoMax: (json['volumeAlvoMax'] as num?)?.toDouble(),
      );
}

/// Formata o volume prescrito (TV-2): "8 a 12 reps" com faixa, "10 reps" sem.
/// [unidade] é opcional (ex.: "reps", "s"); vazio quando não há métrica. Números
/// inteiros saem sem casas; decimais com vírgula.
String formatarVolumeAlvo(double? min, double? max, [String unidade = '']) {
  String n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

  if (min == null) return '';
  final valor = (max != null && max != min) ? '${n(min)} a ${n(max)}' : n(min);
  return unidade.isEmpty ? valor : '$valor $unidade';
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
