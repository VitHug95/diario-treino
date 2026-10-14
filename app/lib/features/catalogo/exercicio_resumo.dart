/// Item do catálogo como vem de GET /api/v1/exercicios (espelha o
/// ExercicioResumo da API).
class ExercicioResumo {
  const ExercicioResumo({
    required this.id,
    required this.nome,
    required this.grupoMuscular,
    required this.membroId,
    required this.membroNome,
    required this.musculoId,
    required this.musculoNome,
    required this.modalidade,
    required this.intensidadeMetricaCodigo,
    required this.intensidadeMetricaNome,
    required this.volumeMetricaCodigo,
    required this.volumeMetricaNome,
    required this.proprio,
  });

  final String id;
  final String nome;

  /// Texto livre legado (PBI-31). Mantido só enquanto a etapa 4 não removê-lo;
  /// a UI usa [membroNome]/[musculoNome].
  final String? grupoMuscular;
  final int? membroId;
  final String? membroNome;
  final int? musculoId;
  final String? musculoNome;
  final String modalidade;
  final String intensidadeMetricaCodigo;
  final String intensidadeMetricaNome;
  final String volumeMetricaCodigo;
  final String volumeMetricaNome;
  final bool proprio;

  /// Forma de medir legível, ex.: "Carga × repetições".
  String get formaDeMedir => '$intensidadeMetricaNome × $volumeMetricaNome';

  /// Classificação para a legenda: "Membro · Músculo", só o membro, ou vazio
  /// (quando ainda não classificado — ex.: "Levantamento terra").
  String get classificacao {
    if (membroNome == null) return '';
    return musculoNome == null ? membroNome! : '$membroNome · $musculoNome';
  }

  factory ExercicioResumo.doJson(Map<String, dynamic> json) => ExercicioResumo(
        id: json['id'] as String,
        nome: json['nome'] as String,
        grupoMuscular: json['grupoMuscular'] as String?,
        membroId: (json['membroId'] as num?)?.toInt(),
        membroNome: json['membroNome'] as String?,
        musculoId: (json['musculoId'] as num?)?.toInt(),
        musculoNome: json['musculoNome'] as String?,
        modalidade: json['modalidade'] as String,
        intensidadeMetricaCodigo: json['intensidadeMetricaCodigo'] as String,
        intensidadeMetricaNome: json['intensidadeMetricaNome'] as String,
        volumeMetricaCodigo: json['volumeMetricaCodigo'] as String,
        volumeMetricaNome: json['volumeMetricaNome'] as String,
        proprio: json['proprio'] as bool,
      );
}
