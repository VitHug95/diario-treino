import 'sessao_models.dart';

/// Agrupamento do bloco conjugado numa sessão gravada (PBI-103). Usa só o que
/// a sessão guardou (`bloco` e `posicaoNoBloco` em cada série, PBI-102), sem
/// depender da ficha atual: mexer na ficha depois não desmancha o histórico.

sealed class ItemSessao {
  const ItemSessao();
}

class ItemSessaoAvulso extends ItemSessao {
  const ItemSessaoAvulso(this.exercicio);
  final ExercicioSessaoDetalhe exercicio;
}

/// Um bloco: os membros na posição em que foram feitos e as rodadas (o maior
/// número de rodada entre as séries deles).
class ItemSessaoBloco extends ItemSessao {
  const ItemSessaoBloco(this.membros);
  final List<ExercicioSessaoDetalhe> membros;

  int get rodadas => membros
      .expand((m) => m.series)
      .fold(0, (maior, s) => s.rodada > maior ? s.rodada : maior);

  /// Pares (membro, série) da rodada [rodada], na ordem do bloco.
  List<(ExercicioSessaoDetalhe, SerieDetalhe)> daRodada(int rodada) => [
        for (final m in membros)
          for (final s in m.series)
            if (s.rodada == rodada) (m, s),
      ];

  /// Descanso da rodada: o que foi gravado na última série dela que tem
  /// descanso (o bloco grava só nela). Nulo ou 0 = sem descanso.
  int? descansoDaRodada(int rodada) {
    final comDescanso =
        daRodada(rodada).map((p) => p.$2.descansoSeg).whereType<int>().where((d) => d > 0);
    return comDescanso.isEmpty ? null : comDescanso.last;
  }
}

/// Número do bloco do exercício na sessão, ou nulo (avulso, não realizado ou
/// sessão antiga).
int? _blocoDe(ExercicioSessaoDetalhe e) =>
    e.series.map((s) => s.bloco).whereType<int>().firstOrNull;

int _posicaoDe(ExercicioSessaoDetalhe e) =>
    e.series.map((s) => s.posicaoNoBloco).whereType<int>().firstOrNull ?? 0;

/// Itens do detalhe: os exercícios na ordem da API, e cada bloco no lugar do
/// primeiro membro que aparece. Bloco com um membro só (o outro não foi feito)
/// é mostrado como avulso. Sessão antiga: tudo avulso, como antes.
List<ItemSessao> itensDaSessao(List<ExercicioSessaoDetalhe> exercicios) {
  final porBloco = <int, List<ExercicioSessaoDetalhe>>{};
  for (final e in exercicios) {
    final b = _blocoDe(e);
    if (b != null) (porBloco[b] ??= []).add(e);
  }
  final vistos = <int>{};
  final itens = <ItemSessao>[];
  for (final e in exercicios) {
    final b = _blocoDe(e);
    final membros = b == null ? null : porBloco[b]!;
    if (membros == null || membros.length < 2) {
      itens.add(ItemSessaoAvulso(e));
    } else if (vistos.add(b!)) {
      itens.add(ItemSessaoBloco(
          [...membros]..sort((x, y) => _posicaoDe(x).compareTo(_posicaoDe(y)))));
    }
  }
  return itens;
}
