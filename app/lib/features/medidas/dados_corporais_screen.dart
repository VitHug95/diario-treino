import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/relogio.dart';
import '../../shared/campo_data.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../shared/mostrar_aviso.dart';
import '../../shared/seletor_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'medidas_formato.dart';
import 'perfil_corporal_comandos.dart';
import 'perfil_corporal_models.dart';
import 'perfil_corporal_repository.dart';

/// Dados corporais e TMB (E12 / PBI-93, tela 23): sexo, nascimento, altura e
/// peso, e o cartão da taxa metabólica basal. A conta da TMB é do back; aqui só
/// se mostra o número recebido. Tudo é opcional e só o dono vê.
class DadosCorporaisScreen extends ConsumerWidget {
  const DadosCorporaisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilCorporalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dados corporais')),
      body: SafeArea(
        child: perfil.when(
          // Ao salvar, os dados são buscados de novo; o formulário não pode
          // sumir nesse meio tempo (perderia o aviso e o que está digitado).
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar seus dados corporais.',
            aoTentar: () => tentarDeNovo(ref, [perfilCorporalProvider]),
          ),
          data: (dados) => _Formulario(perfil: dados),
        ),
      ),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.perfil});

  final PerfilCorporal perfil;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _altura = TextEditingController();
  final _peso = TextEditingController();

  SexoBiologico? _sexo;
  DateTime? _nascimento;

  /// Peso que veio das medidas: só é enviado de novo se o campo mudar, para
  /// salvar a altura não criar um ponto de peso falso no histórico.
  double? _pesoOriginal;

  String? _erroAltura;
  String? _erroPeso;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _preencher(widget.perfil);
  }

  @override
  void dispose() {
    _altura.dispose();
    _peso.dispose();
    super.dispose();
  }

  void _preencher(PerfilCorporal p) {
    _sexo = p.sexo;
    _nascimento = p.nascimento;
    _altura.text = p.alturaCm?.toString() ?? '';
    _peso.text = p.pesoKg == null ? '' : formatarValor(p.pesoKg!);
    _pesoOriginal = p.pesoKg;
  }

  DateTime _hoje() {
    final agora = ref.read(relogioProvider).agora();
    return DateTime(agora.year, agora.month, agora.day);
  }

  Future<void> _escolherNascimento() async {
    final hoje = _hoje();
    // Idade entre 10 e 100 anos (a regra do back): o seletor já não deixa
    // escolher fora dela.
    final primeira = DateTime(hoje.year - 100, hoje.month, hoje.day);
    final ultima = DateTime(hoje.year - 10, hoje.month, hoje.day);
    // Onde o calendário abre quando ainda não há data: 30 anos atrás.
    final sugestao = DateTime(hoje.year - 30, hoje.month, hoje.day);

    // Abre direto na digitação (o ano fica longe no calendário); o botão do
    // diálogo alterna para o calendário.
    final escolhida = await escolherData(
      context,
      titulo: 'Data de nascimento',
      primeira: primeira,
      ultima: ultima,
      inicial: _nascimento,
      sugestao: sugestao,
      abrirDigitando: true,
    );
    if (escolhida != null) setState(() => _nascimento = escolhida);
  }

  /// Idade em anos completos, só para a ajuda do campo (a TMB usa a do back).
  int? _idade() {
    final n = _nascimento;
    if (n == null) return null;
    final hoje = _hoje();
    var idade = hoje.year - n.year;
    if (hoje.month < n.month || (hoje.month == n.month && hoje.day < n.day)) {
      idade--;
    }
    return idade;
  }

  /// Valida como o back. O valor digitado nunca entra na mensagem.
  bool _validar({required int? altura, required double? peso}) {
    String? erroAltura;
    String? erroPeso;

    if (_altura.text.trim().isNotEmpty) {
      if (altura == null) {
        erroAltura = 'Digite a altura em centímetros, sem vírgula.';
      } else if (altura < 100 || altura > 250) {
        erroAltura = 'Use um valor entre 100 e 250 cm.';
      }
    }
    if (_peso.text.trim().isNotEmpty) {
      if (peso == null) {
        erroPeso = 'Digite um número.';
      } else if (peso < 30 || peso > 300) {
        erroPeso = 'Use um valor entre 30 e 300 kg.';
      } else if (((peso * 10) - (peso * 10).round()).abs() > 1e-6) {
        erroPeso = 'Use no máximo uma casa decimal.';
      }
    }

    setState(() {
      _erroAltura = erroAltura;
      _erroPeso = erroPeso;
    });
    return erroAltura == null && erroPeso == null;
  }

  Future<void> _salvar() async {
    final altura = int.tryParse(_altura.text.trim());
    final peso = double.tryParse(_peso.text.trim().replaceAll(',', '.'));
    if (!_validar(altura: altura, peso: peso)) return;

    final pesoMudou = peso != null &&
        (_pesoOriginal == null || (peso - _pesoOriginal!).abs() > 0.001);

    setState(() => _ocupado = true);
    try {
      final salvo = await ref.read(perfilCorporalComandosProvider).salvar(
            sexo: _sexo,
            nascimento: _nascimento,
            alturaCm: altura,
            // Só manda o peso se mudou: o back grava uma medida PESO do dia.
            pesoKg: pesoMudou ? peso : null,
            dataPeso: pesoMudou ? _hoje() : null,
          );
      if (!mounted) return;
      setState(() {
        _pesoOriginal = salvo.pesoKg;
        _ocupado = false;
      });
      mostrarAviso(context, 'Dados salvos');
    } on PerfilCorporalException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarErro(context, e.mensagem);
    }
  }

  Future<void> _limpar() async {
    final confirmou = await confirmarPerigo(
      context,
      titulo: 'Limpar dados corporais?',
      texto: 'Sexo, nascimento e altura serão apagados. '
          'Seu histórico de peso continua nas medidas.',
      rotuloConfirmar: 'Limpar dados',
    );
    if (!confirmou || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await ref.read(perfilCorporalComandosProvider).limpar();
      // O peso fica (é uma medida): relê para o formulário refletir o que sobrou.
      final atual = await ref.read(perfilCorporalProvider.future);
      if (!mounted) return;
      setState(() {
        _preencher(atual);
        _erroAltura = null;
        _erroPeso = null;
        _ocupado = false;
      });
      mostrarAviso(context, 'Dados corporais limpos');
    } on PerfilCorporalException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarErro(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final idade = _idade();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        // Privacidade: o compartilhamento com o educador chega na PBI-96.
        Row(
          children: [
            Icon(LucideIcons.lock, size: AppSizes.iconeSm, color: cores.iconMuted),
            const SizedBox(width: AppSpacing.x8),
            Expanded(
              child: Text('Só você vê estes dados.',
                  style: AppText.caption.copyWith(color: cores.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x24),
        Text('SEXO, PARA O CÁLCULO',
            style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x8),
        // Grupo anunciado como um só ("Sexo, para o cálculo") com os dois botões.
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Sexo, para o cálculo',
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<SexoBiologico>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                for (final s in SexoBiologico.values)
                  ButtonSegment(value: s, label: Text(s.rotulo)),
              ],
              selected: _sexo == null ? const {} : {_sexo!},
              onSelectionChanged: (escolha) => setState(
                  () => _sexo = escolha.isEmpty ? null : escolha.first),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x20),
        CampoData(
          rotulo: 'Data de nascimento',
          texto: _nascimento == null ? null : dataCompleta(_nascimento!),
          aoTocar: _escolherNascimento,
        ),
        if (idade != null) ...[
          const SizedBox(height: AppSpacing.x4),
          Text(idade == 1 ? '1 ano' : '$idade anos',
              style: AppText.caption.copyWith(color: cores.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.x16),
        TextField(
          controller: _altura,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          style: AppText.inputValue,
          onChanged: (_) {
            if (_erroAltura != null) setState(() => _erroAltura = null);
          },
          decoration: InputDecoration(
            labelText: 'Altura',
            suffixText: 'cm',
            errorText: _erroAltura,
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        TextField(
          controller: _peso,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          textInputAction: TextInputAction.done,
          style: AppText.inputValue,
          onChanged: (_) {
            if (_erroPeso != null) setState(() => _erroPeso = null);
          },
          decoration: InputDecoration(
            labelText: 'Peso',
            suffixText: 'kg',
            helperText:
                'Ao mudar o peso, Salvar grava o peso de hoje no histórico de medidas.',
            helperMaxLines: 2,
            errorText: _erroPeso,
          ),
        ),
        const SizedBox(height: AppSpacing.x24),
        _CartaoTmb(perfil: widget.perfil),
        const SizedBox(height: AppSpacing.x24),
        SizedBox(
          height: AppSizes.botaoPrincipal,
          child: FilledButton(
            onPressed: _ocupado ? null : _salvar,
            child: const Text('Salvar'),
          ),
        ),
        const SizedBox(height: AppSpacing.x12),
        SizedBox(
          height: AppSizes.botaoSecundario,
          child: TextButton(
            onPressed: _ocupado ? null : _limpar,
            style: TextButton.styleFrom(foregroundColor: cores.danger),
            child: const Text('Limpar dados corporais'),
          ),
        ),
      ],
    );
  }
}

/// Cartão "Taxa metabólica basal" com os três estados: calculada, incompleta e
/// menor de idade. O número é o que a API devolveu; não há conta no app.
class _CartaoTmb extends StatelessWidget {
  const _CartaoTmb({required this.perfil});

  final PerfilCorporal perfil;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final kcal = perfil.tmbKcal;

    final String frase;
    final Widget corpo;
    if (kcal != null) {
      frase = '${formatarMilhar(kcal)} kcal por dia';
      corpo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(frase, style: AppText.title),
          const SizedBox(height: AppSpacing.x4),
          Text('Estimativa do que seu corpo gasta em repouso.',
              style: AppText.caption.copyWith(color: cores.textSecondary)),
        ],
      );
    } else if (perfil.motivoSemTmb == MotivoSemTmb.menorDeIdade) {
      frase = 'A estimativa vale para adultos';
      corpo = Text(frase, style: AppText.body);
    } else {
      frase = 'Preencha sexo, nascimento, altura e peso';
      corpo = Text(frase, style: AppText.body);
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Taxa metabólica basal. $frase',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: cores.lineDefault),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        padding: const EdgeInsets.all(AppSpacing.paddingCard),
        child: Row(
          children: [
            Icon(LucideIcons.flame, size: AppSizes.iconeMd, color: cores.primaryText),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TAXA METABÓLICA BASAL',
                      style: AppText.overline.copyWith(color: cores.textSecondary)),
                  const SizedBox(height: AppSpacing.x4),
                  corpo,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
