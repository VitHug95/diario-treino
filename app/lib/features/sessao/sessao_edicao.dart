import 'sessao_models.dart';

/// Estado editável de uma série durante o registro. Os campos de valor são
/// texto (controlados por TextEditingController na tela), mas a identidade da
/// métrica e o tipo vêm do rascunho e não mudam no PBI-15.
class SerieEdicao {
  SerieEdicao({
    required this.rodada,
    required this.ordem,
    required this.tipo,
    required this.intensidadeMetricaId,
    required this.intensidadeMetricaCodigo,
    required this.intensidadeMetricaNome,
    required this.intensidadeTexto,
    required this.volumeMetricaId,
    required this.volumeMetricaCodigo,
    required this.volumeMetricaNome,
    required this.volumeTexto,
    required this.descansoTexto,
  });

  final int rodada;
  final int ordem;
  final String tipo;
  final int intensidadeMetricaId;
  final String intensidadeMetricaCodigo;
  final String intensidadeMetricaNome;
  String intensidadeTexto;
  final int volumeMetricaId;
  final String volumeMetricaCodigo;
  final String volumeMetricaNome;
  String volumeTexto;
  String descansoTexto;

  bool get intensidadePorPesoCorporal =>
      intensidadeMetricaCodigo == 'PESO_CORPORAL';

  factory SerieEdicao.doRascunho(SerieRascunho s) => SerieEdicao(
        rodada: s.rodada,
        ordem: s.ordem,
        tipo: s.tipo,
        intensidadeMetricaId: s.intensidadeMetricaId,
        intensidadeMetricaCodigo: s.intensidadeMetricaCodigo,
        intensidadeMetricaNome: s.intensidadeMetricaNome,
        intensidadeTexto: _fmt(s.intensidade),
        volumeMetricaId: s.volumeMetricaId,
        volumeMetricaCodigo: s.volumeMetricaCodigo,
        volumeMetricaNome: s.volumeMetricaNome,
        volumeTexto: _fmt(s.volume),
        descansoTexto: s.descansoSeg?.toString() ?? '',
      );

  static String _fmt(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString().replaceAll('.', ',');
  }
}

/// Estado editável de um exercício no registro.
class ExercicioEdicao {
  ExercicioEdicao({
    required this.treinoExercicioId,
    required this.exercicioId,
    required this.nome,
    required this.grupoMuscular,
    required this.modalidade,
    required this.origemPreenchimento,
    required this.series,
    required this.realizado,
  });

  final String treinoExercicioId;
  final String exercicioId;
  final String nome;
  final String? grupoMuscular;
  final String modalidade;
  final String? origemPreenchimento;
  final List<SerieEdicao> series;

  /// Falso = exercício não realizado (não vira série ao salvar).
  bool realizado;

  factory ExercicioEdicao.doRascunho(RascunhoExercicio e) => ExercicioEdicao(
        treinoExercicioId: e.treinoExercicioId,
        exercicioId: e.exercicioId,
        nome: e.nome,
        grupoMuscular: e.grupoMuscular,
        modalidade: e.modalidade,
        origemPreenchimento: e.origemPreenchimento,
        series: e.series.map(SerieEdicao.doRascunho).toList(),
        // Começa marcado como realizado quando já há séries sugeridas.
        realizado: e.series.isNotEmpty,
      );
}
