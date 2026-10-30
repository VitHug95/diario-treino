import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../features/auth/perfil_api.dart';
import '../../features/catalogo/catalogo_repository.dart';
import '../../features/educador/educador_repository.dart';
import '../../features/fichas/fichas_repository.dart';
import '../../features/progresso/progresso_repository.dart';
import '../../features/sessao/sessao_repository.dart';
import '../../features/sessao/treino_em_andamento.dart';

/// O que mudou numa escrita (PBI-70). Quem grava avisa por aqui; quem lê só
/// observa o provider e se atualiza sozinho.
enum Mudanca {
  /// Plano ou ficha: criar, renomear, excluir, uso, duplicar, exercícios e
  /// alvos da ficha.
  planos,

  /// Sessão: salvar, editar, excluir.
  sessoes,

  /// Catálogo: exercício próprio criado.
  catalogo,

  /// Rascunho do treino em andamento gravado ou apagado no aparelho.
  treinoEmAndamento,

  /// Vínculo educador-aluno: ativar o papel, convidar, aceitar, recusar,
  /// encerrar (PBI-88).
  vinculos,
}

/// Mapa único de invalidação (PBI-70): cada mudança invalida tudo o que é
/// derivado dela. É o ÚNICO lugar do app que chama `invalidate` para manter as
/// telas em dia; as telas não invalidam por conta própria (teste de
/// arquitetura em `test/arquitetura_invalidacao_test.dart`).
///
/// Invalidar uma família inteira ou um provider que ninguém observa é barato:
/// só o que está na tela é buscado de novo.
void invalidarDerivados(Ref ref, Mudanca mudanca) {
  switch (mudanca) {
    case Mudanca.planos:
      _planosEFichas(ref);
    case Mudanca.sessoes:
      ref
        ..invalidate(sessoesRecentesProvider)
        ..invalidate(sessoesDoMesProvider)
        ..invalidate(sessoesDoPeriodoProvider)
        ..invalidate(sessaoDetalheProvider)
        ..invalidate(fichaTemSessoesProvider)
        ..invalidate(historicoExercicioProvider)
        ..invalidate(exerciciosComHistoricoProvider)
        ..invalidate(progressoDoExercicioProvider)
        ..invalidate(progressoPorExercicioProvider);
      // Último treino de cada ficha e o rascunho pré-preenchido (última vez).
      _planosEFichas(ref);
    case Mudanca.catalogo:
      ref.invalidate(catalogoProvider);
    case Mudanca.treinoEmAndamento:
      // Avança a versão que o treinoEmAndamentoProvider observa.
      ref.read(versaoRascunhoTreinoProvider.notifier).avancar();
    case Mudanca.vinculos:
      ref
        // O perfil muda ao virar educador (ganha o papel EDUCADOR).
        ..invalidate(perfilProvider)
        ..invalidate(convitesPendentesProvider)
        ..invalidate(alunosProvider);
  }
}

/// "Tentar de novo" e "puxar para atualizar": a tela busca de novo as PRÓPRIAS
/// leituras que mostra. Não serve para avisar outras telas de uma escrita;
/// isso é papel de [invalidarDerivados], chamado pelos comandos.
void tentarDeNovo(WidgetRef ref, List<ProviderOrFamily> leituras) {
  for (final leitura in leituras) {
    ref.invalidate(leitura);
  }
}

void _planosEFichas(Ref ref) {
  ref
    ..invalidate(planosProvider)
    ..invalidate(planoAtivoProvider)
    ..invalidate(planoPorIdProvider)
    ..invalidate(planoDetalheProvider)
    ..invalidate(fichaDetalheProvider)
    ..invalidate(rascunhoSessaoProvider);
}
