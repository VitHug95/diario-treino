import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rotas/app_router.dart';
import 'auth_service.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      semanticCounterText: 'Campo de e-mail',
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senha,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Senha'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _carregando ? null : _esqueciSenha,
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _carregando ? null : _entrarComEmail,
                    child: _carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _carregando ? null : _entrarComGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Entrar com Google'),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Não tem conta?'),
                      TextButton(
                        onPressed: _carregando
                            ? null
                            : () => context.go(Rotas.cadastro),
                        child: const Text('Cadastre-se'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
