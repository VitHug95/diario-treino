import 'package:flutter/material.dart';

import '../../theme/theme_tokens.dart';

/// Diálogo que pede o e-mail do aluno a convidar (PBI-88). Devolve o e-mail
/// (trim) ou nulo se cancelar. Segue o padrão dos diálogos de formulário da
/// casa: largura fixa (CanvasKit no web) e autofocus no campo.
Future<String?> dialogoConvidarAluno(BuildContext context) {
  final email = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void confirmar(BuildContext ctx) {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(ctx, email.text.trim());
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Convidar aluno'),
      content: SizedBox(
        width: AppSizes.larguraDialogo,
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail do aluno',
              hintText: 'Ex.: aluno@email.com',
            ),
            validator: (v) {
              final texto = (v ?? '').trim();
              if (texto.isEmpty) return 'Informe o e-mail do aluno';
              if (!texto.contains('@') || !texto.contains('.')) {
                return 'Informe um e-mail válido';
              }
              return null;
            },
            onFieldSubmitted: (_) => confirmar(ctx),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => confirmar(ctx),
          child: const Text('Convidar'),
        ),
      ],
    ),
  );
}
