/// Item do catálogo como vem de GET /api/v1/exercicios (espelha o
/// ExercicioResumo da API).
class ExercicioResumo {
  const ExercicioResumo({
    required this.id,
    required this.nome,
    required this.grupoMuscular,
    required this.modalidade,
    required this.intensidadeMetricaCodigo,
    required this.intensidadeMetricaNome,
    required this.volumeMetricaCodigo,
    required this.volumeMetricaNome,
    required this.proprio,
  });

  final String id;
  final String nome;
  final String? grupoMuscular;
  final String modalidade;
  final String intensidadeMetricaCodigo;
  final String intensidadeMetricaNome;
  final String volumeMetricaCodigo;
  final String volumeMetricaNome;
  final bool proprio;

  /// Forma de medir legível, ex.: "Carga × repetições".
  String get formaDeMedir => '$intensidadeMetricaNome × $volumeMetricaNome';

  factory ExercicioResumo.doJson(Map<String, dynamic> json) => ExercicioResumo(
        id: json['id'] as String,
        nome: json['nome'] as String,
        grupoMuscular: json['grupoMuscular'] as String?,
        modalidade: json['modalidade'] as String,
        intensidadeMetricaCodigo: json['intensidadeMetricaCodigo'] as String,
        intensidadeMetricaNome: json['intensidadeMetricaNome'] as String,
        volumeMetricaCodigo: json['volumeMetricaCodigo'] as String,
        volumeMetricaNome: json['volumeMetricaNome'] as String,
        proprio: json['proprio'] as bool,
      );
}

/// Modalidades para o filtro da tela (inclui "Todos").
enum ModalidadeFiltro {
  todos('Todos', null),
  forca('Força', 'FORCA'),
  isometria('Isometria', 'ISOMETRIA'),
  cardio('Cardio', 'CARDIO');

  const ModalidadeFiltro(this.rotulo, this.valorApi);

  /// Rótulo exibido na tela.
  final String rotulo;

  /// Valor enviado à API (null = sem filtro).
  final String? valorApi;
}
