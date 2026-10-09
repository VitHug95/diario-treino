import 'package:flutter/widgets.dart';

import '../catalogo/exercicio_resumo.dart';
import '../catalogo/metrica.dart';
import 'sessao_models.dart';

/// Estado editável de uma série durante o registro (PBI-15/16). A identidade da
/// métrica e o tipo vêm do rascunho; rodada/ordem podem mudar ao adicionar ou
/// remover séries. Os valores ficam em [TextEditingController] próprios, para a
/// lista aceitar inserção e remoção sem embaralhar o que o usuário digitou.
class SerieEdicao {
  SerieEdicao({
    required this.rodada,
    required this.ordem,
    required this.tipo,
    required this.intensidadeMetricaId,
    required this.intensidadeMetricaCodigo,
    required this.intensidadeMetricaNome,
    required String intensidadeTexto,
    required this.volumeMetricaId,
    required this.volumeMetricaCodigo,
    required this.volumeMetricaNome,
    required String volumeTexto,
    required String descansoTexto,
  })  : id = UniqueKey(),
        intensidade = TextEditingController(text: intensidadeTexto),
        volume = TextEditingController(text: volumeTexto),
        descanso = TextEditingController(text: descansoTexto);

  /// Identidade estável para a chave de widget (sobrevive a reordenações).
  final Key id;

  int rodada;
  int ordem;
  final String tipo;
  final int intensidadeMetricaId;
  final String intensidadeMetricaCodigo;
  final String intensidadeMetricaNome;
  final TextEditingController intensidade;
  final int volumeMetricaId;
  final String volumeMetricaCodigo;
  final String volumeMetricaNome;
  final TextEditingController volume;
  final TextEditingController descanso;

  bool get intensidadePorPesoCorporal =>
      intensidadeMetricaCodigo == 'PESO_CORPORAL';

  String get intensidadeTexto => intensidade.text;
  String get volumeTexto => volume.text;
  String get descansoTexto => descanso.text;

  void dispose() {
    intensidade.dispose();
    volume.dispose();
    descanso.dispose();
  }

  factory SerieEdicao.doRascunho(SerieRascunho s) => SerieEdicao(
        rodada: s.rodada,
        ordem: s.ordem,
        tipo: s.tipo,
        intensidadeMetricaId: s.intensidadeMetricaId,
        intensidadeMetricaCodigo: s.intensidadeMetricaCodigo,
        intensidadeMetricaNome: s.intensidadeMetricaNome,
        intensidadeTexto: fmt(s.intensidade),
        volumeMetricaId: s.volumeMetricaId,
        volumeMetricaCodigo: s.volumeMetricaCodigo,
        volumeMetricaNome: s.volumeMetricaNome,
        volumeTexto: fmt(s.volume),
        descansoTexto: s.descansoSeg?.toString() ?? '',
      );

  factory SerieEdicao.doDetalhe(SerieDetalhe s) => SerieEdicao(
        rodada: s.rodada,
        ordem: s.ordem,
        tipo: s.tipo,
        intensidadeMetricaId: s.intensidadeMetricaId,
        intensidadeMetricaCodigo: s.intensidadeMetricaCodigo,
        intensidadeMetricaNome: s.intensidadeMetricaNome,
        intensidadeTexto: fmt(s.intensidade),
        volumeMetricaId: s.volumeMetricaId,
        volumeMetricaCodigo: s.volumeMetricaCodigo,
        volumeMetricaNome: s.volumeMetricaNome,
        volumeTexto: fmt(s.volume),
        descansoTexto: s.descansoSeg?.toString() ?? '',
      );

  /// Cria uma cópia desta série (mesmos valores e métricas) para a próxima
  /// rodada. Usado pelo "adicionar série copia a anterior".
  SerieEdicao copiarComoRodada(int novaRodada) => SerieEdicao(
        rodada: novaRodada,
        ordem: ordem,
        tipo: tipo,
        intensidadeMetricaId: intensidadeMetricaId,
        intensidadeMetricaCodigo: intensidadeMetricaCodigo,
        intensidadeMetricaNome: intensidadeMetricaNome,
        intensidadeTexto: intensidade.text,
        volumeMetricaId: volumeMetricaId,
        volumeMetricaCodigo: volumeMetricaCodigo,
        volumeMetricaNome: volumeMetricaNome,
        volumeTexto: volume.text,
        descansoTexto: descanso.text,
      );

  /// Formata um número para exibição (inteiro sem casas, decimal com vírgula).
  static String fmt(double? v) {
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
    this.foraDaFicha = false,
  });

  /// Nulo quando o exercício foi adicionado fora da ficha (PBI-17): a série é
  /// gravada sem vínculo com o prescrito.
  final String? treinoExercicioId;
  final String exercicioId;
  final String nome;
  final String? grupoMuscular;
  final String modalidade;
  final String? origemPreenchimento;
  final List<SerieEdicao> series;

  /// Exercício adicionado fora da ficha (PBI-17), para rótulo na tela.
  final bool foraDaFicha;

  /// Falso = exercício não realizado (não vira série ao salvar).
  bool realizado;

  /// Recolhido na tela: mostra só o resumo (PBI-16).
  bool recolhido = false;

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

  /// Monta um exercício para edição a partir do detalhe da sessão (PBI-18).
  /// Exercício não realizado começa desmarcado; os feitos trazem suas séries.
  factory ExercicioEdicao.doDetalhe(ExercicioSessaoDetalhe e) => ExercicioEdicao(
        treinoExercicioId: e.treinoExercicioId,
        exercicioId: e.exercicioId,
        nome: e.nome,
        grupoMuscular: e.grupoMuscular,
        modalidade: e.modalidade,
        origemPreenchimento: e.plano != null ? 'Plano: ${e.plano}' : null,
        series: e.series.map(SerieEdicao.doDetalhe).toList(),
        realizado: !e.naoRealizado,
        foraDaFicha: e.foraDaFicha,
      );

  /// Monta um exercício fora da ficha (PBI-17) a partir do item do catálogo.
  /// As métricas vêm por código; [porCodigo] resolve o id e o nome via a lista
  /// de métricas. Começa com uma série vazia para o atleta preencher.
  factory ExercicioEdicao.foraDaFichaDoCatalogo(
    ExercicioResumo e,
    Map<String, Metrica> porCodigo,
  ) {
    final intensidade = porCodigo[e.intensidadeMetricaCodigo];
    final volume = porCodigo[e.volumeMetricaCodigo];

    final serie = SerieEdicao(
      rodada: 1,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: intensidade?.id ?? 0,
      intensidadeMetricaCodigo: e.intensidadeMetricaCodigo,
      intensidadeMetricaNome: intensidade?.nome ?? e.intensidadeMetricaNome,
      intensidadeTexto: '',
      volumeMetricaId: volume?.id ?? 0,
      volumeMetricaCodigo: e.volumeMetricaCodigo,
      volumeMetricaNome: volume?.nome ?? e.volumeMetricaNome,
      volumeTexto: '',
      descansoTexto: '',
    );

    return ExercicioEdicao(
      treinoExercicioId: null,
      exercicioId: e.id,
      nome: e.nome,
      grupoMuscular: e.grupoMuscular,
      modalidade: e.modalidade,
      origemPreenchimento: null,
      series: [serie],
      realizado: true,
      foraDaFicha: true,
    );
  }

  /// Adiciona uma série copiando a última (ou uma vazia, se não houver nenhuma).
  void adicionarSerie() {
    final novaRodada = series.isEmpty ? 1 : series.last.rodada + 1;
    if (series.isEmpty) {
      // Sem base para copiar não há como inferir métricas; o chamador trata.
      return;
    }
    series.add(series.last.copiarComoRodada(novaRodada));
  }

  /// Remove a série do índice e renumera as rodadas na sequência.
  void removerSerie(int index) {
    series.removeAt(index).dispose();
    _renumerar();
  }

  void _renumerar() {
    for (var i = 0; i < series.length; i++) {
      series[i].rodada = i + 1;
    }
  }

  /// Resumo do exercício recolhido, ex.: "3 séries · 30 kg × 10, 35 kg × 8".
  /// Sem séries preenchidas, convida a tocar para registrar.
  String get resumo {
    if (!realizado) return 'Não realizado';
    final feitas = series.where((s) => s.volume.text.trim().isNotEmpty).toList();
    if (feitas.isEmpty) return 'Toque para registrar as séries';

    final partes = feitas.map((s) {
      final vol = s.volume.text.trim();
      if (s.intensidadePorPesoCorporal) return vol;
      final i = s.intensidade.text.trim();
      return i.isEmpty ? vol : '$i × $vol';
    }).toList();

    final n = feitas.length;
    return '$n ${n == 1 ? 'série' : 'séries'} · ${partes.join(', ')}';
  }
}
