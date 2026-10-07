import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'auth_service.dart';
import 'widgets_auth.dart';

/// Tela de login (tela 1 do protótipo): e-mail/senha, Google e esqueci a senha.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _executar(Future<void> Function() acao) async {
    if (_carregando) return;
    setState(() => _carregando = true);
    try {
      await acao();
    } on AuthException catch (e) {
      _mostrarErro(e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _entrarComEmail() async {
    if (!_formKey.currentState!.validate()) return;
    await _executar(() => ref.read(authServiceProvider).entrarComEmail(
          email: _email.text,
          senha: _senha.text,
        ));
  }

  Future<void> _entrarComGoogle() =>
      _executar(() => ref.read(authServiceProvider).entrarComGoogle());

  Future<void> _esqueciSenha() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _mostrarErro('Digite seu e-mail para redefinir a senha.');
      return;
    }
    await _executar(() async {
      await ref.read(authServiceProvider).enviarRedefinicaoSenha(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enviamos um e-mail de redefinição.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);

    // O login abre sempre sobre o cabeçalho escuro (guia: cabeçalho de registro).
    return Scaffold(
      backgroundColor: cores.bgHeader,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.margemLogin),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LogoMarca(cores: cores),
                    const SizedBox(height: AppSpacing.x20),
                    Text(
                      'DIÁRIO\nDE TREINO',
                      style: AppText.displayXl.copyWith(color: cores.textOnHeader),
                    ),
                    const SizedBox(height: AppSpacing.x16),
                    Text(
                      'Anota na academia, alimenta quando der e acompanha a '
                      'evolução sem perder o porquê de cada dia.',
                      style: AppText.body.copyWith(color: cores.textOnHeaderMuted),
                    ),
                    const SizedBox(height: AppSpacing.x28),
                    const RotuloCampoHeader('E-mail'),
                    const SizedBox(height: AppSpacing.x6),
                    CampoHeader(
                      controller: _email,
                      hint: 'seu@email.com',
                      keyboardType: TextInputType.emailAddress,
                      autofill: const [AutofillHints.email],
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Informe um e-mail válido'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x16),
                    const RotuloCampoHeader('Senha'),
                    const SizedBox(height: AppSpacing.x6),
                    CampoHeader(
                      controller: _senha,
                      hint: 'Sua senha',
                      obscure: true,
                      autofill: const [AutofillHints.password],
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                    ),
                    const SizedBox(height: AppSpacing.x20),
                    FilledButton(
                      onPressed: _carregando ? null : _entrarComEmail,
                      child: _carregando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ENTRAR'),
                    ),
                    const SizedBox(height: AppSpacing.x20),
                    _DivisorOu(cores: cores),
                    const SizedBox(height: AppSpacing.x20),
                    _BotaoGoogle(
                      cores: cores,
                      onPressed: _carregando ? null : _entrarComGoogle,
                    ),
                    const SizedBox(height: AppSpacing.x24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Ainda não tem conta? ',
                            style: AppText.body
                                .copyWith(color: cores.textOnHeaderMuted)),
                        GestureDetector(
                          onTap: _carregando ? null : () => context.go(Rotas.cadastro),
                          child: Text('Criar conta',
                              style: AppText.body.copyWith(
                                color: cores.linkOnHeader,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x12),
                    Center(
                      child: GestureDetector(
                        onTap: _carregando ? null : _esqueciSenha,
                        child: Text('Esqueci minha senha',
                            style: AppText.bodyS.copyWith(
                              color: cores.linkOnHeader,
                              decoration: TextDecoration.underline,
                              decorationColor: cores.linkOnHeader,
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoMarca extends StatelessWidget {
  const _LogoMarca({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Logo do Diário de Treino',
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Icon(LucideIcons.dumbbell,
            color: cores.textOnHeader, size: AppSizes.iconeMd),
      ),
    );
  }
}

class _DivisorOu extends StatelessWidget {
  const _DivisorOu({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    final linha = Expanded(child: Divider(color: cores.lineHeader));
    return Row(
      children: [
        linha,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12),
          child: Text('ou',
              style: AppText.bodyS.copyWith(color: cores.textOnHeaderMuted)),
        ),
        linha,
      ],
    );
  }
}

class _BotaoGoogle extends StatelessWidget {
  const _BotaoGoogle({required this.cores, required this.onPressed});
  final AppColors cores;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: cores.textOnHeader,
        backgroundColor: cores.bgHeaderInput,
        side: BorderSide(color: cores.lineHeader),
        minimumSize: const Size.fromHeight(AppSizes.botaoSecundario),
      ),
      icon: const Icon(LucideIcons.chrome, size: AppSizes.iconeSm),
      label: const Text('Entrar com Google'),
    );
  }
}
