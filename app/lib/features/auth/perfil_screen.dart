import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:go_router/go_router.dart';

import '../../core/rotas/app_router.dart';
import '../../core/tema/tema_controller.dart';
import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../educador/dialogo_convidar_aluno.dart';
import '../educador/educador_comandos.dart';
import '../educador/educador_repository.dart';
import 'auth_service.dart';
import 'perfil_api.dart';

/// Tela de Perfil e conta (PBI-25): mostra nome e e-mail (GET /me), a escolha de
/// tema (Sistema/Claro/Escuro, ADR-08 / PBI-24), "Sair" e "Excluir conta" com
/// confirmação digitada. O router redireciona para o login quando a sessão cai.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final perfilAsync = ref.watch(perfilProvider);
    final modo = ref.watch(temaControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          children: [
            Text('CONTA',
                style: AppText.overline.copyWith(color: cores.textSecondary)),
            const SizedBox(height: AppSpacing.x8),
            perfilAsync.when(
              loading: () => const _CartaoDados.carregando(),
              error: (_, __) => _CartaoErro(
                aoTentar: () => ref.refresh(perfilProvider),
              ),
              data: (perfil) =>
                  _CartaoDados(nome: perfil.nome, email: perfil.email),
            ),
            const SizedBox(height: AppSpacing.x28),
            // Modo educador (PBI-88): só com o perfil carregado, para o gate de
            // papel (ATLETA/EDUCADOR) decidir o que mostrar.
            perfilAsync.maybeWhen(
              data: (perfil) => _SecaoEducador(perfil: perfil),
              orElse: () => const SizedBox.shrink(),
            ),
            Text('TEMA',
                style: AppText.overline.copyWith(color: cores.textSecondary)),
            const SizedBox(height: AppSpacing.x8),
            _SeletorTema(
              modo: modo,
              aoSelecionar: (m) =>
                  ref.read(temaControllerProvider.notifier).definir(m),
            ),
            const SizedBox(height: AppSpacing.x28),
            _BotaoSair(aoSair: () => ref.read(authServiceProvider).sair()),
            const SizedBox(height: AppSpacing.x12),
            _BotaoExcluirConta(
              aoConfirmar: () => _excluirConta(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// Fluxo de exclusão (decisão 1A + 2A): o back apaga os dados no Postgres
  /// (DELETE /me) e, em seguida, o app remove o usuário no Firebase. Se o
  /// Firebase pedir login recente, orienta a entrar de novo.
  Future<void> _excluirConta(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(perfilApiProvider).excluirConta();
      await ref.read(authServiceProvider).excluirUsuarioFirebase();
      // Garante que a sessão caiu (o router redireciona para o login).
      await ref.read(authServiceProvider).sair();
    } on AuthException catch (e) {
      // Dados já foram apagados no back; só a remoção no Firebase falhou.
      // Desloga assim mesmo e avisa o usuário.
      await ref.read(authServiceProvider).sair();
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Não foi possível excluir a conta. Tente de novo.')));
    }
  }
}

class _CartaoDados extends StatelessWidget {
  const _CartaoDados({required this.nome, required this.email})
      : carregandoFlag = false;
  const _CartaoDados.carregando()
      : nome = '',
        email = '',
        carregandoFlag = true;

  final String nome;
  final String email;
  final bool carregandoFlag;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: carregandoFlag
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.x12),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nome',
                    style: AppText.caption.copyWith(color: cores.textSecondary)),
                const SizedBox(height: AppSpacing.x4),
                Text(nome, style: AppText.title),
                const SizedBox(height: AppSpacing.x12),
                Text('E-mail',
                    style: AppText.caption.copyWith(color: cores.textSecondary)),
                const SizedBox(height: AppSpacing.x4),
                Text(email,
                    style: AppText.body.copyWith(color: cores.textStrong)),
              ],
            ),
    );
  }
}

class _CartaoErro extends StatelessWidget {
  const _CartaoErro({required this.aoTentar});
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: Column(
        children: [
          Text('Não foi possível carregar seus dados.',
              style: AppText.body.copyWith(color: cores.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x12),
          FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}

/// Três opções de tema (ADR-08): Sistema, Claro, Escuro.
class _SeletorTema extends StatelessWidget {
  const _SeletorTema({required this.modo, required this.aoSelecionar});

  final ThemeMode modo;
  final ValueChanged<ThemeMode> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('Sistema'),
          icon: Icon(LucideIcons.smartphone, size: AppSizes.iconeSm),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Claro'),
          icon: Icon(LucideIcons.sun, size: AppSizes.iconeSm),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Escuro'),
          icon: Icon(LucideIcons.moon, size: AppSizes.iconeSm),
        ),
      ],
      selected: {modo},
      showSelectedIcon: false,
      onSelectionChanged: (s) => aoSelecionar(s.first),
    );
  }
}

class _BotaoSair extends StatelessWidget {
  const _BotaoSair({required this.aoSair});
  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: AppSizes.botaoSecundario,
      child: OutlinedButton.icon(
        onPressed: aoSair,
        icon: const Icon(LucideIcons.logOut, size: AppSizes.iconeSm),
        label: Text('Sair', style: AppText.titleS.copyWith(color: cores.textStrong)),
      ),
    );
  }
}

/// Botão "Excluir conta" que abre um diálogo exigindo digitar EXCLUIR para
/// confirmar — ação destrutiva e irreversível.
class _BotaoExcluirConta extends StatelessWidget {
  const _BotaoExcluirConta({required this.aoConfirmar});
  final Future<void> Function() aoConfirmar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: AppSizes.botaoSecundario,
      child: TextButton.icon(
        onPressed: () => _abrirDialogo(context),
        icon: Icon(LucideIcons.trash2, size: AppSizes.iconeSm, color: cores.danger),
        label: Text('Excluir conta',
            style: AppText.titleS.copyWith(color: cores.danger)),
      ),
    );
  }

  Future<void> _abrirDialogo(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogoExcluir(),
    );
    if (confirmou == true) {
      await aoConfirmar();
    }
  }
}

class _DialogoExcluir extends StatefulWidget {
  const _DialogoExcluir();

  @override
  State<_DialogoExcluir> createState() => _DialogoExcluirState();
}

class _DialogoExcluirState extends State<_DialogoExcluir> {
  static const _palavra = 'EXCLUIR';
  final _controller = TextEditingController();
  bool _liberado = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = _controller.text.trim().toUpperCase() == _palavra;
      if (ok != _liberado) setState(() => _liberado = ok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return AlertDialog(
      title: const Text('Excluir conta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Isso apaga para sempre suas fichas, treinos registrados e '
            'exercícios criados. Não dá para desfazer.',
            style: AppText.body.copyWith(color: cores.textStrong),
          ),
          const SizedBox(height: AppSpacing.x16),
          Text('Digite $_palavra para confirmar.',
              style: AppText.caption.copyWith(color: cores.textSecondary)),
          const SizedBox(height: AppSpacing.x8),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: _palavra),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _liberado ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: cores.dangerFill,
            foregroundColor: cores.dangerOn,
          ),
          child: const Text('Excluir conta'),
        ),
      ],
    );
  }
}

/// Seção do modo educador no Perfil (PBI-88). Gate por papel: quem não é
/// educador vê "Ativar modo educador"; quem é vê "Meus alunos" e "Convidar
/// aluno". "Convites recebidos" aparece para todos (qualquer um pode ser
/// convidado), com selo quando há convites pendentes.
class _SecaoEducador extends ConsumerWidget {
  const _SecaoEducador({required this.perfil});
  final Perfil perfil;

  static const _papelEducador = 'EDUCADOR';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final ehEducador = perfil.papeis.contains(_papelEducador);
    final pendentes = ref.watch(convitesPendentesProvider);
    final qtdPendentes = pendentes.maybeWhen(
      data: (lista) => lista.length,
      orElse: () => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EDUCADOR',
            style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x8),
        if (!ehEducador)
          _LinhaAcao(
            icone: LucideIcons.graduationCap,
            titulo: 'Ativar modo educador',
            subtitulo: 'Convide alunos e acompanhe os treinos deles.',
            aoTocar: () => _ativar(context, ref),
          )
        else ...[
          _LinhaAcao(
            icone: LucideIcons.users,
            titulo: 'Meus alunos',
            subtitulo: 'Veja e convide seus alunos.',
            aoTocar: () => context.push(Rotas.alunos),
          ),
          const SizedBox(height: AppSpacing.x8),
          _LinhaAcao(
            icone: LucideIcons.userPlus,
            titulo: 'Convidar aluno',
            subtitulo: 'Envie um convite por e-mail.',
            aoTocar: () => _convidar(context, ref),
          ),
        ],
        const SizedBox(height: AppSpacing.x8),
        _LinhaAcao(
          icone: LucideIcons.mail,
          titulo: 'Convites recebidos',
          subtitulo: qtdPendentes > 0
              ? '$qtdPendentes convite(s) aguardando'
              : 'Convites de educadores aparecem aqui.',
          destaque: qtdPendentes > 0,
          aoTocar: () => context.push(Rotas.convites),
        ),
        const SizedBox(height: AppSpacing.x28),
      ],
    );
  }

  Future<void> _ativar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(educadorComandosProvider).ativarEducador();
      if (context.mounted) mostrarAviso(context, 'Modo educador ativado');
    } on EducadorException catch (e) {
      if (context.mounted) mostrarAviso(context, e.mensagem);
    }
  }

  Future<void> _convidar(BuildContext context, WidgetRef ref) async {
    final email = await dialogoConvidarAluno(context);
    if (email == null || email.isEmpty) return;
    try {
      await ref.read(educadorComandosProvider).convidar(email);
      if (context.mounted) mostrarAviso(context, 'Convite enviado');
    } on EducadorException catch (e) {
      if (context.mounted) mostrarAviso(context, e.mensagem);
    }
  }
}

/// Linha de ação da seção educador: ícone + título + subtítulo, tocável.
class _LinhaAcao extends StatelessWidget {
  const _LinhaAcao({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.aoTocar,
    this.destaque = false,
  });

  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback aoTocar;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      button: true,
      label: titulo,
      excludeSemantics: true,
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
                color: destaque ? cores.primaryText : cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Row(
            children: [
              Icon(icone, size: AppSizes.iconeMd, color: cores.primaryText),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: AppText.titleS),
                    const SizedBox(height: AppSpacing.x4),
                    Text(subtitulo,
                        style: AppText.caption
                            .copyWith(color: cores.textSecondary)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: AppSizes.iconeSm, color: cores.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}
