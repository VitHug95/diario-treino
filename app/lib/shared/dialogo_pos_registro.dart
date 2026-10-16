import 'package:flutter/material.dart';

/// Escolha do atleta após salvar um treino (PBI-51). Unifica as cópias gêmeas
/// que registrar_sessao e resumo tinham (enum `_AcaoPosRegistro` + AlertDialog).
enum AcaoPosRegistro { inicio, progresso, verTreino }

/// Diálogo "Treino registrado": pergunta o que fazer agora. Devolve a ação
/// escolhida, ou `null` se o diálogo foi fechado sem escolha. A navegação de
/// cada opção fica a cargo do chamador (as rotas diferem por contexto).
Future<AcaoPosRegistro?> dialogoPosRegistro(BuildContext context) {
  return showDialog<AcaoPosRegistro>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Treino registrado'),
      content: const Text('Seu treino foi salvo. O que você quer fazer agora?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, AcaoPosRegistro.inicio),
          child: const Text('Ir para o Início'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, AcaoPosRegistro.verTreino),
          child: const Text('Ver o treino'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, AcaoPosRegistro.progresso),
          child: const Text('Ver progresso'),
        ),
      ],
    ),
  );
}
