import 'package:flutter/material.dart';

import '../../theme/theme_tokens.dart';
import 'plano_models.dart';

/// Resultado do diálogo de criar/editar ficha.
class DadosFicha {
  const DadosFicha(this.nome, this.descricao);
  final String nome;
  final String? descricao;
}

/// Diálogo com nome e descrição da ficha. [inicial] preenche para edição.
/// Usado pela tela da ficha (tela 13) e pelo detalhe do plano (tela 19).
Future<DadosFicha?> dialogoFicha(BuildContext context, {TreinoResumo? inicial}) {
  final nome = TextEditingController(text: inicial?.nome ?? '');
  final descricao = TextEditingController(text: inicial?.descricao ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<DadosFicha>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(inicial == null ? 'Nova ficha' : 'Renomear ficha'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: A'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: AppSpacing.x12),
            TextFormField(
              controller: descricao,
              decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)', hintText: 'Ex.: Peito e tríceps'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, DadosFicha(nome.text.trim(), descricao.text.trim()));
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}
