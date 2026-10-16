import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/theme_tokens.dart';

/// Diálogos de confirmação com a hierarquia de perigo do design (PBI-53).
///
/// Base do que a PBI-51 vai extrair como componente compartilhado: por ora a
/// aparência (vermelho de perigo, saída em coluna) mora aqui e as telas chamam
/// estas funções em vez de montar `AlertDialog` à mão.

/// Confirmação de uma ação destrutiva (Descartar treino, Excluir ficha, sessão,
/// plano...). O botão de confirmar é vermelho cheio (`dangerFill` + `dangerOn`,
/// 48 px) e o cancelar tem o mesmo peso e tamanho (contorno). Devolve `true`
/// quando o usuário confirma.
///
/// O botão de confirmar é um [FilledButton] (os testes de widget procuram por
/// ele pelo tipo e rótulo); a cor de perigo vem do tema, nunca hardcoded.
Future<bool> confirmarPerigo(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String rotuloConfirmar,
  String rotuloCancelar = 'Cancelar',
}) async {
  final cores = AppColors.of(context);
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        SizedBox(
          height: AppSizes.botaoSecundario,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(rotuloCancelar),
          ),
        ),
        SizedBox(
          height: AppSizes.botaoSecundario,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: cores.dangerFill,
              foregroundColor: cores.dangerOn,
            ),
            child: Text(rotuloConfirmar),
          ),
        ),
      ],
    ),
  );
  return confirmou ?? false;
}

/// Escolha ao sair de um treino em andamento (treino livre e registro já
/// feito; o treino ao vivo sai só por Finalizar ou Descartar, PBI-63).
enum SaidaTreino { finalizar, continuarDepois, descartar }

/// Diálogo "Sair do treino?": três ações em coluna, largura total, 48 px, da
/// mais segura para a mais perigosa (PBI-53): "Finalizar agora" (cheio, azul),
/// "Continuar depois" (contorno) e "Descartar treino" (texto vermelho).
/// Devolve a ação escolhida, ou `null` se o usuário fechou sem escolher.
///
/// Não usa `AlertDialog.actions` (que empilha os botões com pesos próprios): os
/// três botões vão no `content`, em coluna, para a hierarquia ser previsível.
Future<SaidaTreino?> dialogoSairDoTreino(BuildContext context) {
  final cores = AppColors.of(context);
  return showDialog<SaidaTreino>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sair do treino?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('O treino continua salvo no aparelho. Você escolhe o que fazer.'),
          const SizedBox(height: AppSpacing.x16),
          SizedBox(
            height: AppSizes.botaoSecundario,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, SaidaTreino.finalizar),
              child: const Text('Finalizar agora'),
            ),
          ),
          const SizedBox(height: AppSpacing.entreItens),
          SizedBox(
            height: AppSizes.botaoSecundario,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, SaidaTreino.continuarDepois),
              child: const Text('Continuar depois'),
            ),
          ),
          const SizedBox(height: AppSpacing.entreItens),
          SizedBox(
            height: AppSizes.botaoSecundario,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, SaidaTreino.descartar),
              style: TextButton.styleFrom(foregroundColor: cores.danger),
              child: const Text('Descartar treino'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Descartar treino?" do treino ao vivo (PBI-63): botão vermelho cheio e o
/// [rotuloCancelar] ("Voltar ao treino" na tela do treino, "Voltar ao resumo"
/// no Resumo). Devolve `true` quando confirma.
Future<bool> confirmarDescarte(BuildContext context, {required String rotuloCancelar}) =>
    confirmarPerigo(
      context,
      titulo: 'Descartar treino?',
      texto: 'O que você fez neste treino será perdido.',
      rotuloConfirmar: 'Descartar treino',
      rotuloCancelar: rotuloCancelar,
    );

/// Escolha no "Salvar treino vazio?" do Resumo do treino (PBI-63).
enum EscolhaTreinoVazio { salvar, voltar, descartar }

/// "Salvar treino vazio?" (PBI-63, rodada 2): aparece no "Salvar treino" do
/// Resumo quando nenhuma série foi marcada. Três ações em coluna, 48 px:
/// "Salvar mesmo assim" (cheio), "Descartar treino" (contorno vermelho, com
/// lixeira) e "Voltar ao resumo" (texto). Fechar sem escolher devolve `null`
/// (fica no Resumo).
Future<EscolhaTreinoVazio?> dialogoTreinoVazio(BuildContext context) {
  final cores = AppColors.of(context);
  return showDialog<EscolhaTreinoVazio>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Salvar treino vazio?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Você irá salvar sem inserir nenhum dado, tem certeza?'),
          const SizedBox(height: AppSpacing.x16),
          SizedBox(
            height: AppSizes.botaoSecundario,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, EscolhaTreinoVazio.salvar),
              child: const Text('Salvar mesmo assim'),
            ),
          ),
          const SizedBox(height: AppSpacing.entreItens),
          SizedBox(
            height: AppSizes.botaoSecundario,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, EscolhaTreinoVazio.descartar),
              style: OutlinedButton.styleFrom(
                foregroundColor: cores.danger,
                side: BorderSide(color: cores.danger),
              ),
              icon: const Icon(LucideIcons.trash2, size: AppSizes.iconeSm),
              label: const Text('Descartar treino'),
            ),
          ),
          const SizedBox(height: AppSpacing.entreItens),
          SizedBox(
            height: AppSizes.botaoSecundario,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, EscolhaTreinoVazio.voltar),
              child: const Text('Voltar ao resumo'),
            ),
          ),
        ],
      ),
    ),
  );
}
