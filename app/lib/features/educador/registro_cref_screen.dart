import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../shared/estado_erro.dart';
import '../../shared/formato_data.dart';
import '../../shared/mascara_cpf.dart';
import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'cref_models.dart';
import 'educador_comandos.dart';
import 'educador_repository.dart';

/// "Registro profissional (CREF)" (PBI-106): o educador informa UF, número e
/// CPF e, com o registro ativo, o modo educador é liberado na hora. Quem já foi
/// habilitado vê o registro guardado. O CPF só vive no campo enquanto a tela
/// está aberta: não há rascunho e ele é apagado ao habilitar.
class RegistroCrefScreen extends ConsumerWidget {
  const RegistroCrefScreen({super.key, this.travado = false});

  /// Educador antigo sem habilitação, vindo de "Meus alunos" ou "Convidar aluno".
  final bool travado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final situacao = ref.watch(situacaoCrefProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Registro profissional (CREF)')),
      body: SafeArea(
        child: situacao.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar seu registro.',
            aoTentar: () => tentarDeNovo(ref, [situacaoCrefProvider]),
          ),
          data: (s) => s.registro != null
              ? _RegistroConfirmado(registro: s.registro!)
              : _Formulario(travado: travado),
        ),
      ),
    );
  }
}

class _RegistroConfirmado extends StatelessWidget {
  const _RegistroConfirmado({required this.registro});

  final RegistroCref registro;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final em = registro.consultadoEm;
    final linhas = <(String, String)>[
      if (registro.uf != null) ('UF', registro.uf!),
      if (registro.numero != null) ('Número', registro.numero!),
      if (registro.situacao != null) ('Situação', registro.situacao!),
      if (em != null) ('Consultado em', formatarDataCompleta(em)),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.badgeCheck, size: AppSizes.iconeMd, color: cores.primaryText),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(child: Text('Registro confirmado', style: AppText.title)),
                ],
              ),
              const SizedBox(height: AppSpacing.x12),
              if (registro.legado)
                Text('Modo educador liberado antes da verificação pelo CREF.',
                    style: AppText.body.copyWith(color: cores.textSecondary))
              else
                for (final (rotulo, valor) in linhas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x6),
                    child: Semantics(
                      container: true,
                      label: '$rotulo: $valor',
                      excludeSemantics: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(rotulo, style: AppText.body.copyWith(color: cores.textSecondary)),
                          ),
                          Flexible(child: Text(valor, style: AppText.label, textAlign: TextAlign.end)),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.travado});

  final bool travado;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _form = GlobalKey<FormState>();
  final _numero = TextEditingController();
  final _cpf = TextEditingController();
  String? _uf;

  /// "Eu permito" (true), "Eu não permito" (false) ou nada marcado (null).
  /// Só com true o botão consulta; o servidor também exige.
  bool? _permite;
  bool _consultando = false;
  String? _mensagem;

  @override
  void dispose() {
    _cpf.clear();
    _cpf.dispose();
    _numero.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    if (_consultando || _permite != true || !(_form.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final cores = AppColors.of(context);
    setState(() {
      _consultando = true;
      _mensagem = null;
    });
    try {
      final r = await ref.read(educadorComandosProvider).verificarCref(
            uf: _uf!,
            numero: _numero.text.trim(),
            cpf: _cpf.text,
          );
      if (r.habilitado) {
        // Terminou: o CPF sai do campo. A tela troca para o registro confirmado.
        _cpf.clear();
        mostrarAvisoNoMessenger(messenger, cores, r.mensagem);
      }
      if (mounted) setState(() => _mensagem = r.habilitado ? null : r.mensagem);
    } on EducadorException catch (e) {
      if (mounted) setState(() => _mensagem = e.mensagem);
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.margemTela),
        children: [
          if (widget.travado) ...[
            Container(
              decoration: BoxDecoration(
                color: cores.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.avisos),
              ),
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Text(
                'Para continuar acompanhando alunos, confirme seu registro no CREF.',
                style: AppText.body.copyWith(color: cores.primaryOnTint),
              ),
            ),
            const SizedBox(height: AppSpacing.x16),
          ],
          Text(
            'Informe o seu registro no CREF. Com o registro ativo, o modo educador '
            'é liberado na hora.',
            style: AppText.body.copyWith(color: cores.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x16),
          DropdownButtonFormField<String>(
            value: _uf,
            decoration: const InputDecoration(labelText: 'UF do CREF'),
            items: [
              for (final uf in ufsBrasil) DropdownMenuItem(value: uf, child: Text(uf)),
            ],
            onChanged: _consultando ? null : (v) => setState(() => _uf = v),
            validator: (v) => v == null ? 'Escolha a UF do seu CREF.' : null,
          ),
          const SizedBox(height: AppSpacing.x12),
          TextFormField(
            controller: _numero,
            enabled: !_consultando,
            decoration: const InputDecoration(labelText: 'Número do CREF', hintText: 'Só os números'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v) == 0)
                ? 'Informe o número do CREF.'
                : null,
          ),
          const SizedBox(height: AppSpacing.x12),
          TextFormField(
            controller: _cpf,
            enabled: !_consultando,
            decoration: const InputDecoration(labelText: 'CPF', hintText: '000.000.000-00'),
            keyboardType: TextInputType.number,
            inputFormatters: const [MascaraCpfFormatter()],
            // Nada de preenchimento automático nem sugestões guardadas pelo teclado.
            autofillHints: const <String>[],
            enableSuggestions: false,
            autocorrect: false,
            enableIMEPersonalizedLearning: false,
            validator: (v) => cpfValido(v) ? null : 'Confira o CPF.',
          ),
          const SizedBox(height: AppSpacing.x16),
          Text(textoPermissaoCref, style: AppText.body.copyWith(color: cores.textStrong)),
          const SizedBox(height: AppSpacing.x8),
          // Nada marcado no começo: a escolha é sempre do usuário.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Eu permito')),
                ButtonSegment(value: false, label: Text('Eu não permito')),
              ],
              selected: {if (_permite != null) _permite!},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: _consultando
                  ? null
                  : (s) => setState(() {
                        _permite = s.isEmpty ? null : s.first;
                        _mensagem = null;
                        // Sem permissão, o CPF digitado sai da tela.
                        if (_permite == false) _cpf.clear();
                      }),
            ),
          ),
          if (_permite == false) ...[
            const SizedBox(height: AppSpacing.x8),
            Semantics(
              liveRegion: true,
              child: Text(
                'Sem a sua permissão, o CREF não é consultado e o modo educador não é habilitado.',
                style: AppText.bodyS.copyWith(color: cores.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x16),
          SizedBox(
            width: double.infinity,
            height: AppSizes.botaoPrincipal,
            child: FilledButton(
              onPressed: _consultando || _permite != true ? null : _verificar,
              child: _consultando
                  ? Semantics(
                      label: 'Consultando o CREF',
                      child: SizedBox(
                        width: AppSizes.iconeMd,
                        height: AppSizes.iconeMd,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cores.textSecondary),
                      ),
                    )
                  : const Text('VERIFICAR REGISTRO'),
            ),
          ),
          if (_mensagem != null) ...[
            const SizedBox(height: AppSpacing.x16),
            Semantics(
              liveRegion: true,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: cores.lineDefault),
                  borderRadius: BorderRadius.circular(AppRadius.avisos),
                ),
                padding: const EdgeInsets.all(AppSpacing.x12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.info, size: AppSizes.iconeSm, color: cores.iconMuted),
                    const SizedBox(width: AppSpacing.x8),
                    Expanded(child: Text(_mensagem!, style: AppText.body)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Aviso antes da permissão (PBI-106, pedido do PO em 26/11).
const textoPermissaoCref =
    'Ao se cadastrar como educador, suas informações pessoais (CPF, UF e número do '
    'CREF) serão utilizadas para validar o seu registro no CREF. O CPF é enviado '
    'só para essa consulta e não fica guardado no app.';

/// CPF com 11 dígitos e os verificadores certos (a mesma conta do servidor),
/// para não gastar consulta com um CPF que não existe.
bool cpfValido(String? texto) {
  final d = (texto ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length != 11 || d.split('').toSet().length == 1) return false;
  int verificador(int quantos) {
    var soma = 0;
    for (var i = 0; i < quantos; i++) {
      soma += int.parse(d[i]) * (quantos + 1 - i);
    }
    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  return verificador(9) == int.parse(d[9]) && verificador(10) == int.parse(d[10]);
}
