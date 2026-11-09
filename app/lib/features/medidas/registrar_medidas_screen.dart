import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/relogio.dart';
import '../../shared/campo_data.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'medidas_comandos.dart';
import 'medidas_formato.dart';
import 'medidas_models.dart';
import 'medidas_repository.dart';

/// Registrar medidas (E12 / PBI-92, tela 25). Todas as medidas são opcionais:
/// o atleta preenche só o que mediu e basta um valor para salvar o dia. Os
/// campos abrem VAZIOS; "última: 84,0" é só ajuda e nunca é gravada.
///
/// Com [dia] (aberto pelo histórico) a tela vem preenchida com os valores do
/// dia, o dia não muda e aparece "Excluir medição". Salvar de novo no mesmo dia
/// atualiza o dia (uma medição por dia).
class RegistrarMedidasScreen extends ConsumerStatefulWidget {
  const RegistrarMedidasScreen({super.key, this.dia});

  final DateTime? dia;

  @override
  ConsumerState<RegistrarMedidasScreen> createState() =>
      _RegistrarMedidasScreenState();
}

class _RegistrarMedidasScreenState
    extends ConsumerState<RegistrarMedidasScreen> {
  final _controllers = {
    for (final tipo in TipoMedida.values) tipo: TextEditingController(),
  };
  final _erros = <TipoMedida, String>{};

  /// Tipos que já tinham valor no dia aberto: se o campo for esvaziado, a
  /// medida é removida do dia (valor nulo na API).
  final _originais = <TipoMedida>{};

  late DateTime _data;
  bool _carregando = false;
  bool _erroCarga = false;
  bool _salvando = false;

  bool get _editando => widget.dia != null;

  @override
  void initState() {
    super.initState();
    final base = widget.dia ?? ref.read(relogioProvider).agora();
    _data = DateTime(base.year, base.month, base.day);
    if (_editando) _carregarDia();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarDia() async {
    setState(() {
      _carregando = true;
      _erroCarga = false;
    });
    try {
      final dia = await ref.read(diaMedidasProvider(_data).future);
      if (!mounted) return;
      setState(() {
        _originais
          ..clear()
          ..addAll(dia.valores.keys);
        for (final e in dia.valores.entries) {
          _controllers[e.key]!.text = formatarValor(e.value);
        }
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroCarga = true;
      });
    }
  }

  Future<void> _escolherData() async {
    final hoje = ref.read(relogioProvider).agora();
    final fimDeHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data.isAfter(fimDeHoje) ? fimDeHoje : _data,
      firstDate: DateTime(hoje.year - 5),
      // Medida é do que já aconteceu: hoje é o limite (a API recusa o futuro).
      lastDate: fimDeHoje,
      helpText: 'Dia da medição',
    );
    if (escolhida != null) {
      setState(() => _data = DateTime(escolhida.year, escolhida.month, escolhida.day));
    }
  }

  /// Lê os campos. Devolve nulo se algum estiver inválido (os erros vão para o
  /// próprio campo). O valor digitado nunca entra na mensagem.
  Map<TipoMedida, double?>? _ler() {
    final valores = <TipoMedida, double?>{};
    final erros = <TipoMedida, String>{};

    for (final tipo in TipoMedida.values) {
      final texto = _controllers[tipo]!.text.trim();
      if (texto.isEmpty) {
        if (_originais.contains(tipo)) valores[tipo] = null; // remove do dia
        continue;
      }
      final v = double.tryParse(texto.replaceAll(',', '.'));
      if (v == null) {
        erros[tipo] = 'Digite um número.';
      } else if (v < tipo.minimo || v > tipo.maximo) {
        erros[tipo] =
            'Use um valor entre ${tipo.minimo.toStringAsFixed(0)} e ${tipo.maximo.toStringAsFixed(0)} ${tipo.unidade}.';
      } else if (((v * 10) - (v * 10).round()).abs() > 1e-6) {
        erros[tipo] = 'Use no máximo uma casa decimal.';
      } else {
        valores[tipo] = v;
      }
    }

    setState(() {
      _erros
        ..clear()
        ..addAll(erros);
    });
    return erros.isEmpty ? valores : null;
  }

  Future<void> _salvar() async {
    final valores = _ler();
    if (valores == null) return;

    // O dia precisa ficar com ao menos uma medida; senão não grava nada.
    if (!valores.values.any((v) => v != null)) {
      mostrarErro(context, 'Preencha ao menos uma medida');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final cores = AppColors.of(context);
    setState(() => _salvando = true);
    try {
      await ref.read(medidasComandosProvider).salvar(_data, valores);
      if (!mounted) return;
      context.pop();
      mostrarAvisoNoMessenger(messenger, cores, 'Medidas salvas');
    } on MedidasException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarErro(context, e.mensagem);
    }
  }

  Future<void> _excluir() async {
    final confirmou = await confirmarPerigo(
      context,
      titulo: 'Excluir medição?',
      texto:
          'As medidas de ${dataCompleta(_data)} serão apagadas. Isso não pode ser desfeito.',
      rotuloConfirmar: 'Excluir medição',
    );
    if (!confirmou || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final cores = AppColors.of(context);
    setState(() => _salvando = true);
    try {
      await ref.read(medidasComandosProvider).excluir(_data);
      if (!mounted) return;
      context.pop();
      mostrarAvisoNoMessenger(messenger, cores, 'Medição excluída');
    } on MedidasException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarErro(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar medidas' : 'Registrar medidas'),
      ),
      body: SafeArea(child: _corpo(context)),
    );
  }

  Widget _corpo(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erroCarga) {
      return EstadoErro(
        mensagem: 'Não foi possível carregar essa medição.',
        aoTentar: _carregarDia,
      );
    }

    final cores = AppColors.of(context);
    // A última medida de cada tipo, só como ajuda no campo.
    final resumo = ref.watch(resumoMedidasProvider).value;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        CampoData(
          rotulo: 'Dia da medição',
          texto: dataCompleta(_data),
          // O dia de uma medição já gravada não muda; para outro dia, registre de novo.
          aoTocar: _editando ? null : _escolherData,
        ),
        for (final grupo in GrupoMedida.values) ...[
          const SizedBox(height: AppSpacing.x24),
          Text(grupo.rotulo.toUpperCase(),
              style: AppText.overline.copyWith(color: cores.textSecondary)),
          const SizedBox(height: AppSpacing.x8),
          for (final tipo in grupo.tipos) ...[
            _CampoMedida(
              tipo: tipo,
              controller: _controllers[tipo]!,
              ajuda: _ajuda(resumo, tipo),
              erro: _erros[tipo],
              aoMudar: () {
                if (_erros.containsKey(tipo)) {
                  setState(() => _erros.remove(tipo));
                }
              },
            ),
            const SizedBox(height: AppSpacing.x12),
          ],
        ],
        const SizedBox(height: AppSpacing.x12),
        SizedBox(
          height: AppSizes.botaoPrincipal,
          child: FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: const Text('Salvar medidas'),
          ),
        ),
        const SizedBox(height: AppSpacing.x12),
        SizedBox(
          height: AppSizes.botaoSecundario,
          child: OutlinedButton(
            onPressed: _salvando ? null : () => context.pop(),
            child: const Text('Cancelar'),
          ),
        ),
        if (_editando) ...[
          const SizedBox(height: AppSpacing.x12),
          SizedBox(
            height: AppSizes.botaoSecundario,
            child: TextButton(
              onPressed: _salvando ? null : _excluir,
              style: TextButton.styleFrom(foregroundColor: cores.danger),
              child: const Text('Excluir medição'),
            ),
          ),
        ],
      ],
    );
  }

  String? _ajuda(ResumoMedidas? resumo, TipoMedida tipo) {
    final ultima = resumo?.ultimaDe(tipo);
    return ultima == null ? null : 'última: ${formatarValor(ultima.valor)}';
  }
}

class _CampoMedida extends StatelessWidget {
  const _CampoMedida({
    required this.tipo,
    required this.controller,
    required this.ajuda,
    required this.erro,
    required this.aoMudar,
  });

  final TipoMedida tipo;
  final TextEditingController controller;
  final String? ajuda;
  final String? erro;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Vírgula ou ponto; o parse troca a vírgula por ponto.
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: TextInputAction.next,
      style: AppText.inputValue,
      onChanged: (_) => aoMudar(),
      decoration: InputDecoration(
        labelText: tipo.rotulo,
        suffixText: tipo.unidade,
        helperText: ajuda,
        errorText: erro,
      ),
    );
  }
}
