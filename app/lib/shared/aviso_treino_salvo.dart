import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/rotas/app_router.dart';

/// Depois de salvar um treino (PBI-64): vai direto para a Início e mostra o
/// aviso "Treino salvo" com a ação "Ver treino". Substitui o diálogo
/// "Treino registrado" de três botões.
///
/// O messenger e o roteador são pegos ANTES do `go`: o messenger é o da raiz
/// do app (sobrevive à troca de rota, o aviso aparece na Início) e o roteador
/// faz o `push` do detalhe só quando o atleta toca em "Ver treino", com a
/// Início já aberta. Isso resolve o bug do "Ver o treino" que fazia `go` e
/// `push` na mesma chamada e caía na Início.
///
/// O SnackBar com ação é anunciado pelo leitor de tela e não some sozinho
/// enquanto a navegação acessível está ligada.
void irParaInicioComTreinoSalvo(
  BuildContext context,
  String sessaoId, {
  String mensagem = 'Treino salvo',
}) {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  router.go(Rotas.inicio);
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(mensagem),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Ver treino',
        onPressed: () => router.push(
          Rotas.detalheSessao,
          extra: DetalheSessaoArgs(sessaoId: sessaoId),
        ),
      ),
    ));
}
