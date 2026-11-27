import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../shared/estado_erro.dart';
import '../../shared/formato_data.dart';
import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'cref_models.dart';
import 'educador_comandos.dart';
import 'educador_repository.dart';

/// Escolhe a foto da carteira do CREF (galeria ou câmera, conforme o aparelho).
/// O app já reduz a foto (no máximo 1600 px de lado, qualidade 80), para ela
/// ficar perto de 1 MB. Nulo = desistiu. Trocável nos testes.
final escolherFotoCrefProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => () async {
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    return arquivo?.readAsBytes();
  },
);

/// "Registro profissional (CREF)" (PBI-106; decisão do PO em 27/11): o educador
/// informa a UF, o número do CREF e a foto da carteira, permite o uso desses
/// dados e o modo educador é liberado na hora. A foto fica guardada para
/// conferência; ninguém a vê pelo app. Quem já foi habilitado vê o registro.
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
    final consultado = registro.consultadoEm;
    final declarado = registro.declaradoEm;
    final linhas = <(String, String)>[
      if (registro.uf != null) ('UF', registro.uf!),
      if (registro.numero != null) ('Número', registro.numero!),
      if (registro.situacao != null) ('Situação', registro.situacao!),
      if (consultado != null) ('Consultado em', formatarDataCompleta(consultado)),
      if (declarado != null) ('Enviado em', formatarDataCompleta(declarado)),
    ];
    final titulo = registro.declarada ? 'Registro enviado' : 'Registro confirmado';
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
                  Expanded(child: Text(titulo, style: AppText.title)),
                ],
              ),
              const SizedBox(height: AppSpacing.x12),
              if (registro.legado)
                Text('Modo educador liberado antes da verificação pelo CREF.',
                    style: AppText.body.copyWith(color: cores.textSecondary))
              else ...[
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
                if (registro.declarada) ...[
                  const SizedBox(height: AppSpacing.x6),
                  Text(
                    'Enviado com a foto da carteira. O registro pode ser conferido e, '
                    'se não bater, o modo educador é revogado.',
                    style: AppText.bodyS.copyWith(color: cores.textSecondary),
                  ),
                ],
              ],
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
  String? _uf;

  /// Foto escolhida (já reduzida) e o tipo pelo conteúdo. Só vive na tela.
  Uint8List? _foto;
  String? _tipoFoto;
  String? _erroFoto;

  /// "Eu permito" (true), "Eu não permito" (false) ou nada marcado (null).
  /// Só com true o botão envia; o servidor também exige.
  bool? _permite;
  bool _enviando = false;
  String? _mensagem;

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    final bytes = await ref.read(escolherFotoCrefProvider)();
    if (bytes == null || !mounted) return;
    final tipo = tipoDaFotoCref(bytes);
    setState(() {
      if (tipo == null || bytes.length > tamanhoMaximoFotoCref) {
        _foto = null;
        _tipoFoto = null;
        _erroFoto = 'Escolha uma foto JPG ou PNG de até 5 MB.';
      } else {
        _foto = bytes;
        _tipoFoto = tipo;
        _erroFoto = null;
      }
      _mensagem = null;
    });
  }

  Future<void> _enviar() async {
    if (_enviando || _permite != true) return;
    final formularioOk = _form.currentState?.validate() ?? false;
    if (_foto == null) setState(() => _erroFoto ??= 'Escolha a foto da carteira do CREF.');
    if (!formularioOk || _foto == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final cores = AppColors.of(context);
    setState(() {
      _enviando = true;
      _mensagem = null;
    });
    try {
      await ref.read(educadorComandosProvider).declararCref(
            uf: _uf!,
            numero: _numero.text.trim(),
            foto: _foto!,
            tipoFoto: _tipoFoto!,
          );
      // A tela troca para o registro enviado (Mudanca.vinculos).
      mostrarAvisoNoMessenger(messenger, cores, 'Registro enviado. Modo educador liberado.');
    } on EducadorException catch (e) {
      if (mounted) setState(() => _mensagem = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
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
            'Informe o seu registro no CREF e envie uma foto da sua carteira. O modo '
            'educador é liberado na hora.',
            style: AppText.body.copyWith(color: cores.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x16),
          DropdownButtonFormField<String>(
            value: _uf,
            decoration: const InputDecoration(labelText: 'UF do CREF'),
            items: [
              for (final uf in ufsBrasil) DropdownMenuItem(value: uf, child: Text(uf)),
            ],
            onChanged: _enviando ? null : (v) => setState(() => _uf = v),
            validator: (v) => v == null ? 'Escolha a UF do seu CREF.' : null,
          ),
          const SizedBox(height: AppSpacing.x12),
          TextFormField(
            controller: _numero,
            enabled: !_enviando,
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
          const SizedBox(height: AppSpacing.x16),
          Text('Foto da carteira do CREF', style: AppText.label),
          const SizedBox(height: AppSpacing.x8),
          if (_foto != null) ...[
            Semantics(
              image: true,
              label: 'Foto da carteira escolhida',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.campoForm),
                child: Image.memory(
                  _foto!,
                  height: 160,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => SizedBox(
                    height: AppSizes.touchMin,
                    child: Center(child: Text('Foto escolhida', style: AppText.bodyS)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x8),
          ],
          SizedBox(
            width: double.infinity,
            height: AppSizes.botaoSecundario,
            child: OutlinedButton.icon(
              onPressed: _enviando ? null : _escolherFoto,
              icon: const Icon(LucideIcons.camera, size: AppSizes.iconeSm),
              label: Text(_foto == null ? 'Escolher foto da carteira' : 'Trocar foto'),
            ),
          ),
          if (_erroFoto != null) ...[
            const SizedBox(height: AppSpacing.x6),
            Semantics(
              liveRegion: true,
              child: Text(_erroFoto!, style: AppText.bodyS.copyWith(color: cores.danger)),
            ),
          ],
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
              onSelectionChanged: _enviando
                  ? null
                  : (s) => setState(() {
                        _permite = s.isEmpty ? null : s.first;
                        _mensagem = null;
                        // Sem permissão, a foto escolhida sai da tela.
                        if (_permite == false) {
                          _foto = null;
                          _tipoFoto = null;
                        }
                      }),
            ),
          ),
          if (_permite == false) ...[
            const SizedBox(height: AppSpacing.x8),
            Semantics(
              liveRegion: true,
              child: Text(
                'Sem a sua permissão, o registro não é guardado e o modo educador não é habilitado.',
                style: AppText.bodyS.copyWith(color: cores.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x16),
          SizedBox(
            width: double.infinity,
            height: AppSizes.botaoPrincipal,
            child: FilledButton(
              onPressed: _enviando || _permite != true ? null : _enviar,
              child: _enviando
                  ? Semantics(
                      label: 'Enviando o registro',
                      child: SizedBox(
                        width: AppSizes.iconeMd,
                        height: AppSizes.iconeMd,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cores.textSecondary),
                      ),
                    )
                  : const Text('ENVIAR REGISTRO'),
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

/// Aviso antes da permissão (PBI-106; texto do envio com foto, 27/11).
const textoPermissaoCref =
    'Ao se cadastrar como educador, o número do seu CREF, a UF e a foto da sua '
    'carteira do CREF ficam guardados para validar o seu registro. Eles só são '
    'apagados se você excluir a conta ou se o registro for revogado.';
