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

/// Cadastro com nome, e-mail e senha (PBI-08).
class CadastroScreen extends ConsumerStatefulWidget {
  const CadastroScreen({super.key});

  @override
  ConsumerState<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends ConsumerState<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (_carregando || !_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await ref.read(authServiceProvider).cadastrar(
            nome: _nome.text,
            email: _email.text,
            senha: _senha.text,
          );
      // O authStateProvider detecta o login e o roteador redireciona.
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);

    return Scaffold(
      backgroundColor: cores.bgHeader,
      appBar: AppBar(
        backgroundColor: cores.bgHeader,
        foregroundColor: cores.textOnHeader,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go(Rotas.login),
          tooltip: 'Voltar',
        ),
      ),
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
                    Text('CRIAR CONTA',
                        style: AppText.displayM.copyWith(color: cores.textOnHeader)),
                    const SizedBox(height: AppSpacing.x24),
                    const RotuloCampoHeader('Nome'),
                    const SizedBox(height: AppSpacing.x6),
                    CampoHeader(
                      controller: _nome,
                      hint: 'Seu nome',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                    ),
                    const SizedBox(height: AppSpacing.x16),
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
                      hint: 'Pelo menos 6 caracteres',
                      obscure: true,
                      autofill: const [AutofillHints.newPassword],
                      validator: (v) => (v == null || v.length < 6)
                          ? 'A senha precisa ter ao menos 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x24),
                    FilledButton(
                      onPressed: _carregando ? null : _cadastrar,
                      child: _carregando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('CRIAR CONTA'),
                    ),
                    const SizedBox(height: AppSpacing.x16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Já tem conta? ',
                            style: AppText.body.copyWith(color: cores.textOnHeaderMuted)),
                        GestureDetector(
                          onTap: _carregando ? null : () => context.go(Rotas.login),
                          child: Text('Entrar',
                              style: AppText.body.copyWith(
                                color: cores.linkOnHeader,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ],
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
