import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/rotas/app_router.dart';
import '../theme/app_colors.dart';
import 'mostrar_aviso.dart';

/// Depois de salvar um treino (PBI-64): vai direto para a Início e mostra o
/// aviso "Treino salvo". Substitui o diálogo "Treino registrado" de três
/// botões.
///
/// Decisão do PO (PBI-75): o aviso é só um pop curto, **sem ação**. Quem quiser
/// ver o treino abre pelo cartão de último treino na própria Início.
///
/// O messenger (e as cores) são pegos ANTES do `go`: o messenger é o da raiz do
/// app e sobrevive à troca de rota, então a pílula aparece com a Início já
/// aberta. Pegar `AppColors` depois do `go` leria o tema do context antigo, que
/// já está saindo — por isso resolvemos tudo antes.
void irParaInicioComTreinoSalvo(
  BuildContext context, {
  String mensagem = 'Treino salvo',
}) {
  final messenger = ScaffoldMessenger.of(context);
  final cores = AppColors.of(context);
  GoRouter.of(context).go(Rotas.inicio);
  mostrarAvisoNoMessenger(messenger, cores, mensagem);
}
