import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/fichas_comandos.dart';
import '../fichas/fichas_repository.dart';
import '../fichas/plano_models.dart';
import 'acoes_plano.dart';

/// Tela 18 (PBI-45): lista de planos do atleta. O plano em uso vem primeiro,
/// com borda e a tag "Em uso"; cada cartão tem dois alvos separados (abrir o
/// plano e o menu de ações). Sem nenhum plano, mostra o estado vazio próprio
/// (tela 27, PBI-68): o Bem-vindo fica só na Início.
class PlanosScreen extends ConsumerWidget {
  const PlanosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planosAsync = ref.watch(planosProvider);

    return planosAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        body: EstadoErro(
          mensagem: 'Não foi possível carregar os planos.',
          aoTentar: () => ref.refresh(planosProvider),
        ),
      ),
      data: (planos) {
        if (planos.isEmpty) return const _SemPlanos();
        return _ListaPlanos(planos: ordenarPlanos(planos));
      },
    );
  }
}

class _ListaPlanos extends ConsumerWidget {
  const _ListaPlanos({required this.planos});

  final List<PlanoDaLista> planos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(planosProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SEUS TREINOS',
                            style: AppText.overline
                                .copyWith(color: cores.textSecondary)),
                        const SizedBox(height: AppSpacing.x4),
                        Text('PLANOS', style: AppText.displayM),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: AppSizes.touchMin,
                    child: FilledButton.icon(
                      // O tema deixa o botão principal com largura total; aqui
                      // ele divide a linha com o título, então fica compacto.
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, AppSizes.touchMin),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x14),
                      ),
                      onPressed: () => criarPlanoEAbrir(context, ref),
                      icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
                      label: const Text('NOVO PLANO'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x16),
              for (final plano in planos) ...[
                _CartaoPlano(plano: plano),
                const SizedBox(height: AppSpacing.entreCards),
              ],
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Só um plano fica em uso: é ele que alimenta a semana da Início. '
                'Os outros continuam à mão para iniciar quando você quiser.',
                style: AppText.caption.copyWith(color: cores.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartão de um plano: nome, tag "Em uso", resumo e, para plano do professor,
/// o chip "Do professor · só leitura". O toque no corpo abre o plano; o botão
/// "⋯" abre as ações. São dois alvos separados, cada um com 44 px no mínimo.
class _CartaoPlano extends ConsumerWidget {
  const _CartaoPlano({required this.plano});

  final PlanoDaLista plano;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final primaria = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: plano.emUso ? primaria : cores.lineDefault,
          width: plano.emUso ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Abrir plano ${plano.nome}',
              excludeSemantics: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: () => _abrirPlano(context, plano.id),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: AppSizes.touchMin),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.paddingCard),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.x8,
                            runSpacing: AppSpacing.x4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(plano.nome.toUpperCase(),
                                  style: AppText.displayS),
                              if (plano.emUso) const _TagEmUso(),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.x4),
                          Text(_resumo(plano),
                              style: AppText.caption
                                  .copyWith(color: cores.textSecondary)),
                          if (plano.somenteLeitura) ...[
                            const SizedBox(height: AppSpacing.x8),
                            const _ChipProfessor(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _abrirMenu(context, ref, plano),
            icon: const Icon(LucideIcons.moreHorizontal, size: AppSizes.iconeMd),
            tooltip: 'Mais ações de ${plano.nome}',
            constraints: const BoxConstraints(
              minWidth: AppSizes.touchMin,
              minHeight: AppSizes.touchMin,
            ),
          ),
        ],
      ),
    );
  }

  /// "3 fichas · 14 exercícios · desde 12/09/2026" (próprio) ou
  /// "3 fichas · 15 exercícios · Prof. Rafael" (do professor).
  static String _resumo(PlanoDaLista p) {
    final fichas = '${p.quantidadeFichas} ${p.quantidadeFichas == 1 ? 'ficha' : 'fichas'}';
    final exercicios =
        '${p.quantidadeExercicios} ${p.quantidadeExercicios == 1 ? 'exercício' : 'exercícios'}';
    final fim = p.somenteLeitura && p.autor.isNotEmpty
        ? 'Prof. ${p.autor}'
        : 'desde ${_data(p.inicio)}';
    return '$fichas · $exercicios · $fim';
  }

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

/// Tag "Em uso": ícone e texto, nunca só cor.
class _TagEmUso extends StatelessWidget {
  const _TagEmUso();

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCircle, size: 14, color: cores.primaryOnTint),
          const SizedBox(width: AppSpacing.x4),
          Text('Em uso',
              style: AppText.caption.copyWith(
                  color: cores.primaryOnTint, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Chip do plano montado pelo professor: cadeado + "Do professor · só leitura".
class _ChipProfessor extends StatelessWidget {
  const _ChipProfessor();

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: cores.bgTrack,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.lock, size: 14, color: cores.textStrong),
          const SizedBox(width: AppSpacing.x4),
          Text('Do professor · só leitura',
              style: AppText.caption.copyWith(
                  color: cores.textStrong, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---- Navegação e ações ----

void _abrirPlano(BuildContext context, String planoId) =>
    context.push(rotaDoPlano(planoId));

void _avisar(BuildContext context, String msg) => avisarPlano(context, msg);

enum _AcaoPlano { definirEmUso, duplicar, copiar, renomear, excluir }

/// Folha de baixo com as ações do plano (tela 18 · menu). "Definir como em uso"
/// some no plano que já está em uso; plano do professor não tem Renomear nem
/// Excluir, e troca Duplicar por "Copiar para editar".
Future<void> _abrirMenu(
    BuildContext context, WidgetRef ref, PlanoDaLista plano) async {
  final cores = AppColors.of(context);
  final acao = await showModalBottomSheet<_AcaoPlano>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.x16, AppSpacing.x16, AppSpacing.x16, AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('PLANO',
                style: AppText.overline.copyWith(color: cores.textSecondary)),
            const SizedBox(height: AppSpacing.x4),
            Text(plano.nome.toUpperCase(), style: AppText.displayS),
            const SizedBox(height: AppSpacing.x8),
            if (!plano.emUso)
              _LinhaMenu(
                icone: LucideIcons.checkCircle,
                rotulo: 'Definir como em uso',
                aoTocar: () => Navigator.pop(ctx, _AcaoPlano.definirEmUso),
              ),
            if (plano.somenteLeitura)
              _LinhaMenu(
                icone: LucideIcons.copy,
                rotulo: 'Copiar para editar',
                aoTocar: () => Navigator.pop(ctx, _AcaoPlano.copiar),
              )
            else ...[
              _LinhaMenu(
                icone: LucideIcons.copy,
                rotulo: 'Duplicar plano',
                aoTocar: () => Navigator.pop(ctx, _AcaoPlano.duplicar),
              ),
              _LinhaMenu(
                icone: LucideIcons.pencil,
                rotulo: 'Renomear',
                aoTocar: () => Navigator.pop(ctx, _AcaoPlano.renomear),
              ),
              _LinhaMenu(
                icone: LucideIcons.trash2,
                rotulo: 'Excluir plano',
                perigo: true,
                aoTocar: () => Navigator.pop(ctx, _AcaoPlano.excluir),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    ),
  );
  if (acao == null || !context.mounted) return;

  final repo = ref.read(fichasComandosProvider);
  try {
    switch (acao) {
      case _AcaoPlano.definirEmUso:
        await repo.definirEmUso(plano.id);
        if (context.mounted) _avisar(context, '"${plano.nome}" agora está em uso.');
      case _AcaoPlano.duplicar:
        await repo.duplicarPlano(plano.id);
        if (context.mounted) _avisar(context, 'Cópia criada, fora de uso.');
      case _AcaoPlano.copiar:
        if (!await confirmarCopiaPlano(context)) return;
        await repo.duplicarPlano(plano.id);
        if (context.mounted) _avisar(context, 'Cópia criada. Agora ela é sua para editar.');
      case _AcaoPlano.renomear:
        final nome = await dialogoNomePlano(context,
            titulo: 'Renomear plano', inicial: plano.nome);
        if (nome == null) return;
        await repo.renomearPlano(planoId: plano.id, nome: nome);
      case _AcaoPlano.excluir:
        final confirmou = await confirmarPerigo(
          context,
          titulo: 'Excluir plano?',
          texto: textoExcluirPlano(emUso: plano.emUso),
          rotuloConfirmar: 'Excluir plano',
        );
        if (!confirmou) return;
        await repo.excluirPlano(plano.id);
    }
  } on FichasException catch (e) {
    if (context.mounted) _avisar(context, e.mensagem);
  }
}

/// Uma linha da folha de ações, com 54 px de altura.
class _LinhaMenu extends StatelessWidget {
  const _LinhaMenu({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.perigo = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final bool perigo;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final cor = perigo ? cores.danger : null;
    return SizedBox(
      height: 54,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icone, size: AppSizes.iconeSm, color: cor),
        title: Text(rotulo, style: AppText.body.copyWith(color: cor)),
        onTap: aoTocar,
      ),
    );
  }
}



/// Aba Planos sem nenhum plano (tela 27, PBI-68): estado vazio próprio, sem
/// boas-vindas (que ficam só na Início). "Criar plano" abre o "Novo plano"
/// direto, sem passar por outra tela (PBI-69).
class _SemPlanos extends ConsumerWidget {
  const _SemPlanos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);

    final vazio = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: AppSizes.botaoPrincipal,
            height: AppSizes.botaoPrincipal,
            decoration: BoxDecoration(
              color: cores.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: ExcludeSemantics(
              child: Icon(LucideIcons.calendarPlus,
                  size: AppSizes.iconeMd, color: cores.primaryOnTint),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x20),
        Text('MONTE SEU PRIMEIRO PLANO E COMECE A TREINAR',
            style: AppText.displayS, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.x8),
        Text(
          'Um plano reúne suas fichas, como Treino A, B e C. Você cria o '
          'plano, monta as fichas e inicia o treino por ali.',
          style: AppText.bodyS.copyWith(color: cores.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x24),
        SizedBox(
          height: AppSizes.botaoPrincipal,
          child: FilledButton.icon(
            onPressed: () => criarPlanoEAbrir(context, ref),
            icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
            label: const Text('CRIAR PLANO'),
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('SEUS TREINOS',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x4),
              Text('PLANOS', style: AppText.displayM),
              Expanded(
                child: Center(child: SingleChildScrollView(child: vazio)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
