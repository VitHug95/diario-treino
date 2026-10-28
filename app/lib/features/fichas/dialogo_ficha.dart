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
      content: SizedBox(
        // Largura explícita: sem ela, numa Column dentro do AlertDialog no web
        // (CanvasKit) o campo encolhe e a área de toque não acompanha a borda
        // desenhada — o clique só "pegava" na beirada do campo.
        width: AppSizes.larguraDialogo,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nome,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: A'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: AppSpacing.x12),
              TextFormField(
                controller: descricao,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)', hintText: 'Ex.: Peito e tríceps'),
                onFieldSubmitted: (_) => _salvar(ctx, formKey, nome, descricao),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => _salvar(ctx, formKey, nome, descricao),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// Valida o nome e fecha o diálogo devolvendo os dados. Usado pelo botão Salvar
/// e pelo Enter no campo de descrição.
void _salvar(
  BuildContext ctx,
  GlobalKey<FormState> formKey,
  TextEditingController nome,
  TextEditingController descricao,
) {
  if (!formKey.currentState!.validate()) return;
  Navigator.pop(ctx, DadosFicha(nome.text.trim(), descricao.text.trim()));
}
