import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/fichas_comandos.dart';
import '../fichas/fichas_repository.dart';

/// Peças compartilhadas pela lista (tela 18) e pelo detalhe do plano (tela 19).

/// Rota do detalhe de um plano (tela 19).
String rotaDoPlano(String planoId) =>
    '${Rotas.planoDetalhe}?id=${Uri.encodeQueryComponent(planoId)}';

/// Caminho único de criar plano (PBI-69): pede só o nome ("Novo plano"), cria
/// (o primeiro do atleta nasce em uso) e abre o detalhe do plano vazio, com
/// "Nova ficha". Vale para a lista, o estado vazio de Planos e a Início.
///
/// `go` (e não `push`): de qualquer aba, o atleta cai na aba Planos com a
/// pilha lista → detalhe, então a seta do detalhe leva à lista já com o plano.
Future<void> criarPlanoEAbrir(BuildContext context, WidgetRef ref) async {
  final nome = await dialogoNovoPlano(context);
  if (nome == null || !context.mounted) return;
  try {
    final id = await ref.read(fichasComandosProvider).criarPlano(nome);
    if (context.mounted) context.go(rotaDoPlano(id));
  } on FichasException catch (e) {
    if (context.mounted) avisarPlano(context, e.mensagem);
  }
}

/// Diálogo "Novo plano" (tela 27): só o nome, já sugerido como "Meu plano",
/// com "Criar plano" (primário, largura total) e "Cancelar".
Future<String?> dialogoNovoPlano(BuildContext context) {
  final nome = TextEditingController(text: 'Meu plano');
  final formKey = GlobalKey<FormState>();
  final cores = AppColors.of(context);

  void confirmar(BuildContext ctx) {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(ctx, nome.text.trim());
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Novo plano'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dê um nome para o plano. Você pode mudar depois.',
                style: AppText.bodyS.copyWith(color: cores.textSecondary)),
            const SizedBox(height: AppSpacing.x16),
            TextFormField(
              controller: nome,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do plano'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome do plano' : null,
              onFieldSubmitted: (_) => confirmar(ctx),
            ),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        SizedBox(
          width: double.infinity,
          height: AppSizes.botaoSecundario,
          child: FilledButton(
            onPressed: () => confirmar(ctx),
            child: const Text('CRIAR PLANO'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ),
      ],
    ),
  );
}

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
