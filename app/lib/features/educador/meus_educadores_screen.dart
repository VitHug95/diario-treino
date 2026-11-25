import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../shared/formato_data.dart';
import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'educador_comandos.dart';
import 'educador_models.dart';
import 'educador_repository.dart';

/// "Meus educadores" (PBI-104): quem acompanha o atleta hoje (vínculos ATIVOS)
/// e o botão para encerrar cada acompanhamento. Empilhada do Perfil.
class MeusEducadoresScreen extends ConsumerWidget {
  const MeusEducadoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final educadores = ref.watch(educadoresDoAlunoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meus educadores')),
      body: SafeArea(
        child: educadores.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar seus educadores.',
            aoTentar: () => tentarDeNovo(ref, [educadoresDoAlunoProvider]),
          ),
          data: (lista) => lista.isEmpty ? const _Vazio() : _Lista(educadores: lista),
        ),
      ),
    );
  }
}

const _nota = 'Educadores só veem o que você libera. Ao encerrar, o acesso some '
    'na hora e seus dados continuam com você.';

class _Nota extends StatelessWidget {
  const _Nota();

  @override
  Widget build(BuildContext context) => Text(
        _nota,
        style: AppText.caption.copyWith(color: AppColors.of(context).textSecondary),
      );
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: EstadoVazio(
              icone: LucideIcons.userX,
              titulo: 'Ninguém acompanha você agora',
              texto: 'Quando você aceitar o convite de um educador, ele aparece aqui.',
              acao: SizedBox(
                height: AppSizes.botaoSecundario,
                child: OutlinedButton(
                  onPressed: () => context.push(Rotas.convites),
                  child: const Text('Ver convites'),
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.margemTela),
          child: _Nota(),
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.educadores});

  final List<EducadorVinculado> educadores;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        for (final e in educadores) ...[
          _CartaoEducador(educador: e),
          const SizedBox(height: AppSpacing.entreCards),
        ],
        const SizedBox(height: AppSpacing.x4),
        const _Nota(),
      ],
    );
  }
}

class _CartaoEducador extends ConsumerStatefulWidget {
  const _CartaoEducador({required this.educador});

  final EducadorVinculado educador;

  @override
  ConsumerState<_CartaoEducador> createState() => _CartaoEducadorState();
}

class _CartaoEducadorState extends ConsumerState<_CartaoEducador> {
  bool _encerrando = false;

  Future<void> _encerrar() async {
    final e = widget.educador;
    final confirmou = await confirmarPerigo(
      context,
      titulo: 'Encerrar acompanhamento?',
      texto: '${e.educadorNome} deixa de ver seus treinos e sua evolução agora. '
          'Seus dados continuam com você. Para voltar a ser acompanhado, o '
          'educador precisa convidar você de novo.',
      rotuloConfirmar: 'Encerrar',
    );
    if (!confirmou || !mounted) return;
    // O cartão some quando a lista recarrega: o aviso vai pelo messenger da
    // tela, pego antes da escrita.
    final messenger = ScaffoldMessenger.of(context);
    final cores = AppColors.of(context);
    setState(() => _encerrando = true);
    try {
      await ref.read(educadorComandosProvider).encerrar(e.vinculoId);
      mostrarAvisoNoMessenger(messenger, cores, 'Acompanhamento encerrado');
    } on EducadorException catch (erro) {
      // 409: já não estava ativo. O comando já recarregou a lista.
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(erro.mensagem)));
    } finally {
      if (mounted) setState(() => _encerrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final e = widget.educador;
    final desde = e.desde;
    final textoDesde = desde == null ? null : 'Acompanha você desde ${formatarDataCompleta(desde)}';
    final falado = [
      'Educador ${e.educadorNome}',
      if (desde != null) 'acompanha você desde ${formatarDataPorExtenso(desde)}',
    ].join(', ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: falado,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.educadorNome, style: AppText.title),
                const SizedBox(height: AppSpacing.x4),
                Text(e.educadorEmail,
                    style: AppText.bodyS.copyWith(color: cores.textSecondary)),
                if (textoDesde != null) ...[
                  const SizedBox(height: AppSpacing.x4),
                  Text(textoDesde, style: AppText.body.copyWith(color: cores.textStrong)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Encerrar acompanhamento de ${e.educadorNome}',
              excludeSemantics: true,
              child: TextButton.icon(
                onPressed: _encerrando ? null : _encerrar,
                style: TextButton.styleFrom(
                  foregroundColor: cores.danger,
                  minimumSize: const Size(AppSizes.touchMin, AppSizes.touchMin),
                ),
                icon: const Icon(LucideIcons.userMinus, size: AppSizes.iconeSm),
                label: const Text('Encerrar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
