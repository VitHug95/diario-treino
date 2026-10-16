import 'package:flutter/material.dart';

/// Peças compartilhadas pela lista (tela 18) e pelo detalhe do plano (tela 19).

/// Texto da confirmação de "Excluir plano". Quando o plano está em uso, avisa
/// que o uso passa para o último plano usado (regra da PBI-44).
String textoExcluirPlano({required bool emUso}) =>
    'O plano e as fichas dele serão apagados. As sessões que você já registrou '
    'e os gráficos continuam.'
    '${emUso ? ' Como ele está em uso, o uso passa para o último plano que você usou.' : ''}';

/// Mostra uma mensagem curta no rodapé.
void avisarPlano(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Confirmação de "Copiar para editar" (plano do professor, PBI-48).
Future<bool> confirmarCopiaPlano(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Copiar plano?'),
      content: const Text('Você ganha uma cópia sua, que pode editar. '
          'O plano do professor continua como está.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('COPIAR PLANO'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Diálogo que pede só o nome do plano (novo ou renomear).
Future<String?> dialogoNomePlano(BuildContext context,
    {required String titulo, String? inicial}) {
  final nome = TextEditingController(text: inicial ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: nome,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Nome do plano', hintText: 'Ex.: Treino de viagem'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, nome.text.trim());
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}
