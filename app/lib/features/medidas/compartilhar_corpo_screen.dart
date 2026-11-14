import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/estado_erro.dart';
import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'compartilhamento_comandos.dart';
import 'compartilhamento_repository.dart';

/// "Compartilhar com o educador" (E12 / PBI-96, tela 27): dois cadeados
/// independentes, trancados por padrão. Destrancar pede confirmação; trancar
/// não, e corta o acesso na hora. Mostra quem vê (educadores com vínculo ativo)
/// e avisa que, sem vínculo ativo, ninguém vê.
class CompartilharCorpoScreen extends ConsumerWidget {
  const CompartilharCorpoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(compartilhamentoCorporalProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Compartilhar com o educador')),
      body: SafeArea(
        child: estado.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar o compartilhamento.',
            aoTentar: () => tentarDeNovo(ref, [compartilhamentoCorporalProvider]),
          ),
          data: (c) => _Conteudo(atual: c),
        ),
      ),
    );
  }
}

class _Conteudo extends ConsumerStatefulWidget {
  const _Conteudo({required this.atual});

  final CompartilhamentoCorporal atual;

  @override
  ConsumerState<_Conteudo> createState() => _ConteudoState();
}

class _ConteudoState extends ConsumerState<_Conteudo> {
  bool _salvando = false;

  /// [parte] no plural, para o aviso e a confirmação ("Dados corporais" ou
  /// "Medidas"); [feminino] faz a concordância ("compartilhadas").
  Future<void> _mudar({required bool dados, required bool medidas, required String parte,
      required bool feminino, required bool destrancando}) async {
    if (destrancando) {
      final ok = await _confirmar(parte);
      if (!ok || !mounted) return;
    }
    setState(() => _salvando = true);
    try {
      await ref
          .read(compartilhamentoComandosProvider)
          .definir(dadosCorporais: dados, medidas: medidas);
      if (mounted) {
        final fim = feminino ? 'as' : 'os';
        mostrarAviso(context,
            destrancando ? '$parte compartilhad$fim' : '$parte privad$fim');
      }
    } on CompartilhamentoException catch (e) {
      if (mounted) mostrarErro(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<bool> _confirmar(String parte) async {
    final c = widget.atual;
    final quem = c.educadores.isEmpty
        ? 'Hoje você não tem educador com vínculo ativo; quando tiver, ele passa a ver.'
        : 'Hoje quem vê: ${c.educadores.join(', ')}.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Compartilhar ${parte.toLowerCase()}?'),
        content: Text('Todo educador com vínculo ativo passa a ver, só para leitura. '
            'Você pode trancar de novo quando quiser. $quem'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Compartilhar')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final c = widget.atual;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        Text(
          'Tudo começa privado. Escolha o que o seu educador pode ver. Ele só lê: '
          'nunca altera nada.',
          style: AppText.body.copyWith(color: cores.textSecondary),
        ),
        const SizedBox(height: AppSpacing.x16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: [
              _Cadeado(
                titulo: 'Dados corporais',
                descricao: 'Sexo, idade, altura, peso e TMB',
                liberado: c.dadosCorporais,
                habilitado: !_salvando,
                aoMudar: (v) => _mudar(
                    dados: v, medidas: c.medidas, parte: 'Dados corporais', feminino: false,
                    destrancando: v),
              ),
              Divider(height: 1, color: cores.lineDivider),
              _Cadeado(
                titulo: 'Medidas corporais',
                descricao: 'Medidas, histórico e evolução',
                liberado: c.medidas,
                habilitado: !_salvando,
                aoMudar: (v) => _mudar(
                    dados: c.dadosCorporais, medidas: v, parte: 'Medidas', feminino: true,
                    destrancando: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x24),
        Text('QUEM VÊ', style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x8),
        if (c.educadores.isEmpty)
          Text(
            'Você não tem educador com vínculo ativo. Ninguém vê, mesmo o que estiver '
            'compartilhado.',
            style: AppText.body,
          )
        else ...[
          for (final nome in c.educadores)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x6),
              child: Row(
                children: [
                  Icon(LucideIcons.userCheck, size: AppSizes.iconeSm, color: cores.iconMuted),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(child: Text(nome, style: AppText.body)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            c.algumLiberado
                ? 'Eles veem só o que estiver compartilhado acima.'
                : 'Com tudo privado, eles não veem nada do seu corpo.',
            style: AppText.caption.copyWith(color: cores.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.x16),
        Text(
          'Encerrar o vínculo também tira o acesso. O PDF do progresso nunca leva '
          'dados do corpo.',
          style: AppText.caption.copyWith(color: cores.textSecondary),
        ),
      ],
    );
  }
}

/// Um cadeado: título, o que inclui, o estado em texto ("Privado" ou
/// "Compartilhado", não só a cor) e o interruptor. Linha inteira tocável.
class _Cadeado extends StatelessWidget {
  const _Cadeado({
    required this.titulo,
    required this.descricao,
    required this.liberado,
    required this.habilitado,
    required this.aoMudar,
  });

  final String titulo;
  final String descricao;
  final bool liberado;
  final bool habilitado;
  final ValueChanged<bool> aoMudar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final estado = liberado ? 'Compartilhado' : 'Privado';
    return SwitchListTile(
      value: liberado,
      onChanged: habilitado ? aoMudar : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingCard),
      secondary: Icon(liberado ? LucideIcons.unlock : LucideIcons.lock,
          color: liberado ? cores.primaryText : cores.iconMuted, size: AppSizes.iconeMd),
      title: Text(titulo, style: AppText.title),
      subtitle: Text('$descricao · $estado',
          style: AppText.caption.copyWith(color: cores.textSecondary)),
    );
  }
}

/// Selo de privacidade nas telas do corpo (PBI-96): "Privado" com o cadeado ou
/// "Compartilhado com o educador". Toque abre a tela "Compartilhar".
class SeloCompartilhamento extends ConsumerWidget {
  const SeloCompartilhamento({super.key, required this.parte});

  /// Qual cadeado o selo mostra.
  final ParteDoCorpo parte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final c = ref.watch(compartilhamentoCorporalProvider).value;
    final liberado = c != null &&
        (parte == ParteDoCorpo.dadosCorporais ? c.dadosCorporais : c.medidas);
    final texto = liberado ? 'Compartilhado com o educador' : 'Privado: só você vê';
    return Semantics(
      button: true,
      label: '$texto. Toque para escolher o que compartilhar',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.avisos),
        onTap: () => context.push(Rotas.compartilharCorpo),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          child: Row(
            children: [
              Icon(liberado ? LucideIcons.unlock : LucideIcons.lock,
                  size: AppSizes.iconeSm,
                  color: liberado ? cores.primaryText : cores.iconMuted),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: Text(texto,
                    style: AppText.caption.copyWith(
                        color: liberado ? cores.primaryText : cores.textSecondary)),
              ),
              Text('Alterar', style: AppText.label.copyWith(color: cores.primaryText)),
            ],
          ),
        ),
      ),
    );
  }
}

enum ParteDoCorpo { dadosCorporais, medidas }

/// Resumo para a linha do Perfil: "Tudo privado", "Medidas compartilhadas"...
String resumoCompartilhamento(CompartilhamentoCorporal c) {
  if (c.dadosCorporais && c.medidas) return 'Dados e medidas compartilhados';
  if (c.dadosCorporais) return 'Dados corporais compartilhados';
  if (c.medidas) return 'Medidas compartilhadas';
  return 'Tudo privado';
}
