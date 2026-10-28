import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../shared/aviso_treino_salvo.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../shared/tags/seletor_tag_serie.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/exercicio_resumo.dart';
import '../catalogo/selecionar_exercicio_screen.dart';
import '../fichas/fichas_repository.dart';
import '../fichas/fichas_comandos.dart';
import 'manter_na_ficha.dart';
import 'sessao_comandos.dart';
import 'sessao_edicao.dart';
import 'sessao_repository.dart';
import 'treino_em_andamento.dart';

/// Tela 3 do protótipo: registrar o treino de uma ficha, com as séries já
/// preenchidas pelo histórico ou pelos alvos (PBI-15) e edição das séries
/// durante o registro — adicionar, remover, recolher o resumo (PBI-16).
///
/// Em modo edição (PBI-18), [sessaoId] é informado: a tela abre com os dados da
/// sessão existente e salva via PUT em vez de criar.
class RegistrarSessaoScreen extends ConsumerWidget {
  const RegistrarSessaoScreen({
    super.key,
    required this.treinoId,
    required this.treinoNome,
    this.sessaoId,
    this.dataInicial,
    this.registroPosterior = false,
  });

  final String treinoId;
  final String treinoNome;

  /// Nulo = registrar novo; preenchido = editar a sessão existente.
  final String? sessaoId;

  /// Dia pré-selecionado ao registrar novo (faixa semanal). Nulo = hoje.
  final DateTime? dataInicial;

  /// "Registrar treino já feito" (PBI-37): não é um treino em andamento — a data
  /// é editável, a duração é digitada e não há rascunho local nem cronômetro.
  final bool registroPosterior;

  bool get _editando => sessaoId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titulo = _editando
        ? 'Editar treino'
        : (registroPosterior ? 'Registrar $treinoNome' : treinoNome);

    // Edição (PBI-18): carrega a sessão existente, sem rascunho em andamento.
    if (_editando) {
      final detalhe = ref.watch(sessaoDetalheProvider(sessaoId!));
      return Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: detalhe.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível preparar o registro.',
            aoTentar: () => ref.refresh(sessaoDetalheProvider(sessaoId!)),
          ),
          data: (dados) => _Formulario(
            treinoId: dados.treinoId,
            treinoNome: treinoNome,
            sessaoId: sessaoId,
            data: dados.data,
            duracaoMin: dados.duracaoMin,
            observacao: dados.observacao,
            exercicios: dados.exercicios.map(ExercicioEdicao.doDetalhe).toList(),
          ),
        ),
      );
    }

    // Treino em andamento (PBI-37): se já existe um rascunho desta ficha no
    // aparelho, reabre de onde parou. Caso contrário, monta do zero a partir do
    // rascunho da ficha e marca a hora de início. "Registrar já feito" pula isto.
    if (!registroPosterior) {
      // Lê o rascunho uma vez (read, não watch): o autosave invalida este
      // provider a cada tecla, e observá-lo aqui remontaria o formulário e
      // perderia o que o atleta está digitando.
      final emAndamento = ref.read(treinoEmAndamentoProvider);
      if (emAndamento != null && emAndamento.treinoId == treinoId) {
        return Scaffold(
          appBar: AppBar(title: Text(titulo)),
          body: _Formulario(
            treinoId: treinoId,
            treinoNome: treinoNome,
            sessaoId: null,
            data: emAndamento.data,
            duracaoMin: null,
            observacao: null,
            exercicios:
                emAndamento.exercicios.map((e) => e.paraEdicao()).toList(),
            emAndamento: true,
            inicio: emAndamento.inicio,
          ),
        );
      }
    }

    final rascunho = ref.watch(rascunhoSessaoProvider(treinoId));
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: rascunho.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => EstadoErro(
          mensagem: 'Não foi possível preparar o registro.',
          aoTentar: () => ref.refresh(rascunhoSessaoProvider(treinoId)),
        ),
        data: (dados) => _Formulario(
          treinoId: treinoId,
          treinoNome: treinoNome,
          sessaoId: null,
          // Dia escolhido na faixa semanal, se houver; senão o padrão (hoje).
          data: dataInicial ?? dados.data,
          duracaoMin: null,
          observacao: null,
          exercicios: dados.exercicios.map(ExercicioEdicao.doRascunho).toList(),
          emAndamento: !registroPosterior,
          inicio: registroPosterior ? null : DateTime.now(),
        ),
      ),
    );
  }
}

/// Tela 7 do protótipo: registrar um treino livre (sem ficha, PBI-19). Começa
/// vazio; cada exercício adicionado traz a última execução como referência e a
/// sessão é gravada com `treinoId` nulo. Opção de também salvar como ficha.
class TreinoLivreScreen extends StatelessWidget {
  const TreinoLivreScreen({super.key, this.dataInicial});

  /// Dia escolhido na folha do dia da Início ("Sem ficha", PBI-59). Nulo = hoje.
  final DateTime? dataInicial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Treino livre')),
      body: _Formulario(
        treinoId: null,
        treinoNome: 'Treino livre',
        sessaoId: null,
        data: dataInicial ?? DateTime.now(),
        duracaoMin: null,
        observacao: null,
        exercicios: [],
        treinoLivre: true,
      ),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({
    required this.treinoId,
    required this.treinoNome,
    required this.sessaoId,
    required this.data,
    required this.duracaoMin,
    required this.observacao,
    required this.exercicios,
    this.treinoLivre = false,
    this.emAndamento = false,
    this.inicio,
  });

  final String? treinoId;
  final String treinoNome;
  final String? sessaoId;
  final DateTime data;
  final int? duracaoMin;
  final String? observacao;
  final List<ExercicioEdicao> exercicios;

  /// Treino livre (PBI-19): começa vazio, cada exercício adicionado traz a
  /// última execução como referência e há a opção "Salvar também como ficha".
  final bool treinoLivre;

  /// Treino em andamento (PBI-37): autosalva o rascunho no aparelho a cada
  /// alteração, calcula a duração a partir de [inicio] e finaliza com aviso se
  /// houver exercício sem marcar. Falso = editar sessão ou "registrar já feito".
  final bool emAndamento;

  /// Instante de início do treino (para a duração automática em andamento).
  final DateTime? inicio;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  late DateTime _data;
  late final List<ExercicioEdicao> _exercicios;
  final _duracao = TextEditingController();
  final _observacao = TextEditingController();
  bool _salvando = false;

  /// Treino livre (PBI-19): marcar para também salvar o treino como ficha nova.
  bool _salvarComoFicha = false;

  /// Finalizado/descartado: libera a saída sem o diálogo de treino em andamento.
  bool _encerrado = false;

  bool get _editando => widget.sessaoId != null;
  bool get _treinoLivre => widget.treinoLivre;
  bool get _emAndamento => widget.emAndamento;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _exercicios = widget.exercicios;
    if (widget.duracaoMin != null) _duracao.text = widget.duracaoMin.toString();
    if (widget.observacao != null) _observacao.text = widget.observacao!;

    if (_emAndamento) {
      // Autosalva o rascunho quando o atleta digita em qualquer série (os
      // toggles de "realizado" já chamam _aoMudar). Observa cada controller.
      for (final ex in _exercicios) {
        for (final s in ex.series) {
          _ouvirSerie(s);
        }
      }
      // Grava o estado inicial para "Continuar treino" já valer de cara.
      WidgetsBinding.instance.addPostFrameCallback((_) => _salvarRascunho());
    }
  }

  void _ouvirSerie(SerieEdicao s) {
    s.intensidade.addListener(_salvarRascunho);
    s.volume.addListener(_salvarRascunho);
    s.descanso.addListener(_salvarRascunho);
  }

  @override
  void dispose() {
    _duracao.dispose();
    _observacao.dispose();
    for (final ex in _exercicios) {
      for (final s in ex.series) {
        s.dispose();
      }
    }
    super.dispose();
  }

  /// Chamado a cada mudança estrutural (marcar realizado, add/remover série).
  /// Redesenha e, em andamento, persiste o rascunho.
  void _aoMudar() {
    setState(() {});
    if (_emAndamento) _salvarRascunho();
  }

  /// Persiste o rascunho atual no aparelho (PBI-37). Só em andamento.
  void _salvarRascunho() {
    if (!_emAndamento || _encerrado) return;
    final treino = TreinoEmAndamento(
      treinoId: widget.treinoId,
      treinoNome: widget.treinoNome,
      treinoLivre: _treinoLivre,
      dataIso: _soDataIso(_data),
      inicioMillis:
          (widget.inicio ?? DateTime.now()).millisecondsSinceEpoch,
      exercicios: _exercicios.map(exercicioParaRascunho).toList(),
    );
    ref.read(rascunhoTreinoServiceProvider).salvar(treino);
  }

  static String _soDataIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Marca o treino como encerrado e apaga o rascunho local (finalizar/descartar).
  void _encerrarRascunho() {
    _encerrado = true;
    if (_emAndamento) {
      ref.read(rascunhoTreinoServiceProvider).limpar();
    }
  }

  /// Diálogo ao tentar sair com um treino em andamento (PBI-37): finalizar,
  /// continuar depois (mantém o rascunho) ou descartar. Devolve true quando a
  /// saída pode prosseguir.
  Future<bool> _aoTentarSair() async {
    if (!_emAndamento || _encerrado) return true;

    final acao = await dialogoSairDoTreino(context);

    switch (acao) {
      case SaidaTreino.finalizar:
        if (!mounted) return false;
        await _finalizar();
        return false; // _finalizar navega/mostra diálogo; não deixa o pop seguir.
      case SaidaTreino.continuarDepois:
        // Mantém o rascunho (já salvo) e sai.
        return true;
      case SaidaTreino.descartar:
        if (!mounted) return false;
        final confirmar = await confirmarPerigo(
          context,
          titulo: 'Descartar treino?',
          texto: 'O que você preencheu neste treino será perdido.',
          rotuloConfirmar: 'Descartar',
          rotuloCancelar: 'Voltar',
        );
        if (confirmar) {
          _encerrarRascunho();
          return true;
        }
        return false;
      case null:
        return false;
    }
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(hoje.year - 2),
      // Aceita até amanhã (igual à regra do servidor), não além.
      lastDate: DateTime(hoje.year, hoje.month, hoje.day).add(const Duration(days: 1)),
      helpText: 'Dia em que você treinou',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  /// Seletor com vários exercícios (PBI-49): entram na ordem escolhida.
  Future<void> _adicionarForaDaFicha() async {
    final escolhidos = await Navigator.of(context).push<List<ExercicioResumo>>(
      MaterialPageRoute(
        builder: (_) => SelecionarExercicioScreen(
          destino: widget.treinoNome,
          // PBI-74: o que já está no treino não pode entrar de novo.
          idsIndisponiveis: {for (final e in _exercicios) e.exercicioId},
          rotuloIndisponivel: 'Já está no treino',
        ),
      ),
    );
    if (escolhidos == null || !mounted) return;
    for (final e in escolhidos) {
      await _adicionarEscolhido(e);
      if (!mounted) return;
    }
  }

  Future<void> _adicionarEscolhido(ExercicioResumo escolhido) async {
    // Treino livre: traz a última execução como referência (PBI-19). Se falhar
    // (ex.: offline), cai no modo "série em branco" para não travar o registro.
    if (_treinoLivre) {
      try {
        final rascunho = await ref
            .read(sessaoRepositoryProvider)
            .obterUltimaExecucao(escolhido.id);
        if (!mounted) return;
        _adicionarExercicio(ExercicioEdicao.doRascunhoAvulso(rascunho));
        return;
      } on SessaoException {
        // Segue para o fallback abaixo.
      }
      if (!mounted) return;
    }

    // Resolve as métricas (código -> id/nome) para montar a série.
    final porCodigo = await ref.read(metricasPorCodigoProvider.future);
    if (!mounted) return;

    _adicionarExercicio(ExercicioEdicao.foraDaFichaDoCatalogo(escolhido, porCodigo));
  }

  /// Adiciona um exercício à lista, liga o autosave das séries (em andamento) e
  /// persiste o rascunho.
  void _adicionarExercicio(ExercicioEdicao ex) {
    if (_emAndamento) {
      for (final s in ex.series) {
        _ouvirSerie(s);
      }
    }
    _exercicios.add(ex);
    _aoMudar();
  }

  /// Ação do botão principal. Em treino novo (andamento ou já feito), avisa se
  /// há exercício sem marcar antes de finalizar (PBI-37); edição salva direto.
  Future<void> _finalizar() async {
    if (!_editando) {
      final naoMarcados = _exercicios.where((e) => !e.realizado).length;
      if (naoMarcados > 0) {
        final plural = naoMarcados == 1 ? 'exercício' : 'exercícios';
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Finalizar treino?'),
            content: Text(
                'Ainda tem $naoMarcados $plural sem marcar. Finalizar mesmo '
                'assim? Eles ficam como não realizados.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Finalizar'),
              ),
            ],
          ),
        );
        if (confirmar != true) return;
      }

      // Duração automática a partir do início (editável antes de confirmar):
      // só preenche se o atleta não digitou nada.
      if (_emAndamento && _duracao.text.trim().isEmpty && widget.inicio != null) {
        final min = DateTime.now().difference(widget.inicio!).inMinutes;
        if (min > 0) _duracao.text = min.toString();
      }
    }

    await _salvar();
  }

  Future<void> _salvar() async {
    // Barra sessão totalmente vazia: sem isso o back grava uma sessão sem
    // séries e o app ainda mostraria "Treino registrado" (bug PBI-33).
    if (!_exercicios.any((e) => e.temSerieFeita)) {
      _erro('Preencha ao menos uma série para registrar o treino.');
      return;
    }

    // PBI-72: "Manter na ficha?" ao registrar treino de ficha. Não pergunta
    // em treino livre nem ao editar uma sessão antiga.
    var manterNaFicha = const <String>[];
    var fichaNaoConferida = false;
    if (!_editando && !_treinoLivre) {
      final escolha = await perguntarManterNaFicha(
        context,
        ref,
        treinoId: widget.treinoId,
        treinoNome: widget.treinoNome,
        exercicios: _exercicios,
        rotuloVoltar: 'Voltar ao registro',
      );
      if (escolha.ids == null || !mounted) return;
      manterNaFicha = escolha.ids!;
      fichaNaoConferida = escolha.leituraFalhou;
    }

    setState(() => _salvando = true);
    try {
      final repo = ref.read(sessaoComandosProvider);
      final duracao = int.tryParse(_duracao.text.trim());
      final obs = _observacao.text.trim().isEmpty ? null : _observacao.text.trim();

      if (_editando) {
        await repo.editarSessao(
          sessaoId: widget.sessaoId!,
          treinoId: widget.treinoId,
          data: _data,
          duracaoMin: duracao,
          observacao: obs,
          exercicios: _exercicios,
        );
        // O comando já atualizou o detalhe, a semana e o progresso (PBI-70).
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        await repo.criarSessao(
          treinoId: widget.treinoId,
          data: _data,
          duracaoMin: duracao,
          observacao: obs,
          exercicios: _exercicios,
          manterNaFicha: manterNaFicha,
        );

        // Treino em andamento finalizado: apaga o rascunho local (PBI-37).
        _encerrarRascunho();

        // Treino livre com "Salvar também como ficha": cria a ficha com os
        // exercícios realizados. Falha aqui não derruba o registro da sessão,
        // que já foi salva — avisa e segue.
        if (_treinoLivre && _salvarComoFicha) {
          await _criarFichaDoTreino();
        }

        if (mounted) {
          _confirmarRegistro(
            mensagem: fichaNaoConferida
                ? 'Treino salvo. Não deu para conferir a ficha.'
                : 'Treino salvo',
          );
        }
      }
    } on SessaoException catch (e) {
      _erro(e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Cria uma ficha com os exercícios realizados do treino livre (PBI-19).
  /// Pede o nome da ficha; se o atleta cancelar, não cria. Erros aqui não
  /// desfazem a sessão já salva — apenas avisam.
  Future<void> _criarFichaDoTreino() async {
    final ids = _exercicios
        .where((e) => e.temSerieFeita)
        .map((e) => e.exercicioId)
        .toList();
    if (ids.isEmpty) return;

    final nome = await _pedirNomeDaFicha();
    if (nome == null || !mounted) return;

    try {
      await ref.read(fichasComandosProvider).salvarComoFicha(
            nome: nome,
            exercicioIds: ids,
          );
    } on FichasException catch (e) {
      _erro('Treino salvo, mas não deu para criar a ficha: ${e.mensagem}');
    }
  }

  /// Diálogo simples para o nome da nova ficha. Nulo = cancelou.
  Future<String?> _pedirNomeDaFicha() async {
    final controlador = TextEditingController(text: 'Treino livre');
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar como ficha'),
        // Largura explícita: sem ela, no AlertDialog web (CanvasKit) o campo
        // fica estreito e clicar fora dele cai no barrier e fecha o diálogo.
        content: SizedBox(
          width: AppSizes.larguraDialogo,
          child: TextField(
            controller: controlador,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Nome da ficha'),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controlador.text.trim()),
            child: const Text('Salvar ficha'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (nome == null || nome.isEmpty) return null;
    return nome;
  }

  /// Salvou (PBI-64): Início com o aviso "Treino salvo", sem diálogo.
  void _confirmarRegistro({String mensagem = 'Treino salvo'}) =>
      irParaInicioComTreinoSalvo(context, mensagem: mensagem);

  void _erro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);

    return PopScope(
      // Em andamento, intercepta a saída para oferecer finalizar/continuar/
      // descartar (PBI-37). Fora de andamento, deixa sair direto.
      canPop: !_emAndamento || _encerrado,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final podeSair = await _aoTentarSair();
        if (!podeSair || !mounted) return;
        // Libera o PopScope (canPop passa a true) e sai de fato pelo go_router.
        setState(() => _encerrado = true);
        if (context.mounted && context.canPop()) context.pop();
      },
      child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            children: [
              _CampoData(data: _data, aoTocar: _escolherData),
              const SizedBox(height: AppSpacing.x16),
              _CampoDuracao(controlador: _duracao),
              const SizedBox(height: AppSpacing.x24),
              Text('EXERCÍCIOS',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x8),
              if (_exercicios.isEmpty)
                _SemExercicios(
                  cores: cores,
                  mensagem: _treinoLivre
                      ? 'Nenhum exercício ainda. Toque em "Adicionar exercício" para montar o treino.'
                      : 'Esta ficha ainda não tem exercícios. Adicione exercícios à ficha para registrar o treino.',
                )
              else
                for (var i = 0; i < _exercicios.length; i++)
                  _CardExercicio(
                    key: ValueKey(
                        _exercicios[i].treinoExercicioId ?? 'avulso-$i-${_exercicios[i].exercicioId}'),
                    exercicio: _exercicios[i],
                    aoMudar: _aoMudar,
                  ),
              const SizedBox(height: AppSpacing.x4),
              SizedBox(
                height: AppSizes.touchMin,
                child: OutlinedButton.icon(
                  onPressed: _adicionarForaDaFicha,
                  icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
                  label: Text(_treinoLivre
                      ? 'Adicionar exercício'
                      : 'Adicionar exercício fora da ficha'),
                ),
              ),
              const SizedBox(height: AppSpacing.x16),
              TextField(
                controller: _observacao,
                maxLines: 4,
                minLines: 2,
                style: AppText.body,
                decoration: const InputDecoration(
                  labelText: 'Observação do dia (opcional)',
                  hintText: 'Ex.: dormi mal, ombro incomodou no supino',
                  alignLabelWithHint: true,
                ),
              ),
              if (_treinoLivre) ...[
                const SizedBox(height: AppSpacing.x8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _salvarComoFicha,
                  onChanged: (v) => setState(() => _salvarComoFicha = v ?? false),
                  title: const Text('Salvar também como ficha'),
                  subtitle: const Text(
                      'Cria uma ficha nova com os exercícios deste treino.'),
                ),
              ],
            ],
          ),
        ),
        _BarraSalvar(
          salvando: _salvando,
          aoSalvar: _finalizar,
          rotulo: _editando ? 'SALVAR ALTERAÇÕES' : 'FINALIZAR TREINO',
        ),
      ],
      ),
    );
  }
}

class _CampoData extends StatelessWidget {
  const _CampoData({required this.data, required this.aoTocar});

  final DateTime data;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final texto =
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(AppRadius.campoForm),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Dia em que treinou'),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: AppSizes.iconeSm, color: cores.iconMuted),
            const SizedBox(width: AppSpacing.x8),
            Text(texto, style: AppText.inputValue),
          ],
        ),
      ),
    );
  }
}

class _CampoDuracao extends StatelessWidget {
  const _CampoDuracao({required this.controlador});
  final TextEditingController controlador;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppText.inputValue,
      decoration: const InputDecoration(
        labelText: 'Duração (opcional)',
        suffixText: 'min',
      ),
    );
  }
}

/// Card de um exercício no registro: recolhe para mostrar o resumo, ou expande
/// para editar as séries (adicionar, remover, ajustar valores). PBI-16.
class _CardExercicio extends StatelessWidget {
  const _CardExercicio({
    super.key,
    required this.exercicio,
    required this.aoMudar,
  });

  final ExercicioEdicao exercicio;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final subtitulo = [
      if (exercicio.grupoMuscular != null && exercicio.grupoMuscular!.isNotEmpty)
        exercicio.grupoMuscular!,
      exercicio.modalidade,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.entreCards),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho tocável: recolhe/expande.
          InkWell(
            onTap: () {
              exercicio.recolhido = !exercicio.recolhido;
              aoMudar();
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(exercicio.nome, style: AppText.title)),
                          if (exercicio.foraDaFicha) ...[
                            const SizedBox(width: AppSpacing.x8),
                            _ChipForaDaFicha(cores: cores),
                          ],
                        ],
                      ),
                      if (subtitulo.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x4),
                        Text(subtitulo,
                            style: AppText.caption.copyWith(color: cores.textSecondary)),
                      ],
                    ],
                  ),
                ),
                Icon(
                  exercicio.recolhido ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  size: AppSizes.iconeSm,
                  color: cores.iconMuted,
                ),
              ],
            ),
          ),
          if (exercicio.recolhido) ...[
            const SizedBox(height: AppSpacing.x8),
            Text(exercicio.resumo,
                style: AppText.bodyS.copyWith(color: cores.textSecondary)),
          ] else ...[
            if (exercicio.origemPreenchimento != null) ...[
              const SizedBox(height: AppSpacing.x8),
              _AvisoOrigem(texto: exercicio.origemPreenchimento!, cores: cores),
            ],
            const SizedBox(height: AppSpacing.x12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercicio.realizado ? 'Realizado' : 'Marcar como feito',
                    style: AppText.label.copyWith(
                      color: exercicio.realizado ? cores.textStrong : cores.textSecondary,
                    ),
                  ),
                ),
                Semantics(
                  label: exercicio.realizado
                      ? 'Marcar ${exercicio.nome} como não realizado'
                      : 'Marcar ${exercicio.nome} como realizado',
                  child: Switch(
                    value: exercicio.realizado,
                    onChanged: (v) {
                      exercicio.realizado = v;
                      aoMudar();
                    },
                  ),
                ),
              ],
            ),
            if (exercicio.realizado)
              _CorpoSeries(exercicio: exercicio, aoMudar: aoMudar)
            else
              // PBI-37: séries da última execução/alvos como sugestão em tom
              // secundário. Tocar aqui marca o exercício como realizado e abre
              // os campos para editar.
              _SugestaoSeries(
                exercicio: exercicio,
                aoTocar: () {
                  exercicio.realizado = true;
                  aoMudar();
                },
              ),
          ],
        ],
      ),
    );
  }
}

/// Lista editável de séries + botão "adicionar série".
class _CorpoSeries extends StatelessWidget {
  const _CorpoSeries({required this.exercicio, required this.aoMudar});

  final ExercicioEdicao exercicio;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    if (exercicio.series.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x8),
        child: Text('Sem séries sugeridas. Marque como não realizado se não fez.',
            style: AppText.bodyS.copyWith(color: cores.textSecondary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.x8),
        for (var i = 0; i < exercicio.series.length; i++)
          _LinhaSerie(
            key: ValueKey(exercicio.series[i].id),
            serie: exercicio.series[i],
            podeRemover: exercicio.series.length > 1,
            aoMudar: aoMudar,
            aoRemover: () {
              exercicio.removerSerie(i);
              aoMudar();
            },
          ),
        const SizedBox(height: AppSpacing.x4),
        SizedBox(
          height: AppSizes.touchMin,
          child: OutlinedButton.icon(
            onPressed: () {
              exercicio.adicionarSerie();
              aoMudar();
            },
            icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
            label: const Text('Adicionar série'),
          ),
        ),
      ],
    );
  }
}

/// Séries sugeridas (última execução ou alvos) em tom secundário, antes de o
/// exercício ser marcado como feito (PBI-37). Tocar marca como realizado.
class _SugestaoSeries extends StatelessWidget {
  const _SugestaoSeries({required this.exercicio, required this.aoTocar});

  final ExercicioEdicao exercicio;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);

    final linhas = <String>[];
    for (final s in exercicio.series) {
      final vol = s.volume.text.trim();
      final intens = s.intensidade.text.trim();
      if (s.intensidadePorPesoCorporal) {
        linhas.add(vol.isEmpty ? '—' : vol);
      } else if (intens.isEmpty && vol.isEmpty) {
        linhas.add('—');
      } else {
        linhas.add('${intens.isEmpty ? '—' : intens} × ${vol.isEmpty ? '—' : vol}');
      }
    }
    final resumo = linhas.isEmpty ? 'Toque para registrar' : linhas.join(',  ');

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x8),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.x12),
          decoration: BoxDecoration(
            color: cores.bgInput,
            borderRadius: BorderRadius.circular(AppRadius.campoForm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  linhas.isEmpty ? resumo : 'Sugestão: $resumo',
                  style: AppText.bodyS.copyWith(color: cores.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              Text('Marcar',
                  style: AppText.label.copyWith(color: cores.primaryText)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selo "Fora da ficha" para exercícios adicionados na hora (PBI-17).
class _ChipForaDaFicha extends StatelessWidget {
  const _ChipForaDaFicha({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: cores.bgInput,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: cores.lineDefault),
      ),
      child: Text('Fora da ficha',
          style: AppText.caption.copyWith(color: cores.textSecondary)),
    );
  }
}

/// Aviso de pré-preenchimento (fundo primaryTint, raio de avisos).
class _AvisoOrigem extends StatelessWidget {
  const _AvisoOrigem({required this.texto, required this.cores});

  final String texto;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.avisos),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: AppSizes.iconeSm, color: cores.primaryOnTint),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: Text(texto,
                style: AppText.caption.copyWith(color: cores.primaryOnTint)),
          ),
        ],
      ),
    );
  }
}

/// Uma linha de série editável. Peso corporal mostra o selo "Intensidade: peso
/// corporal" no lugar do campo de carga (MER 3.11, critério do PBI-16).
class _LinhaSerie extends StatelessWidget {
  const _LinhaSerie({
    super.key,
    required this.serie,
    required this.podeRemover,
    required this.aoRemover,
    required this.aoMudar,
  });

  final SerieEdicao serie;
  final bool podeRemover;
  final VoidCallback aoRemover;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.entreItens),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 24,
            child: Text('${serie.rodada}',
                style: AppText.numeralS.copyWith(color: cores.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.x6),
          // Tag da série (TV-1), modo edição: toca para trocar.
          ChipTagSerie(
            marcador: serie.marcador,
            rodada: serie.rodada,
            aoTocar: (novo) {
              serie.marcador = novo;
              aoMudar();
            },
          ),
          const SizedBox(width: AppSpacing.x6),
          if (serie.intensidadePorPesoCorporal)
            Expanded(child: _SeloPesoCorporal(cores: cores))
          else
            Expanded(
              child: _CampoNumero(
                rotulo: serie.intensidadeMetricaNome,
                controlador: serie.intensidade,
              ),
            ),
          const SizedBox(width: AppSpacing.x6),
          Expanded(
            child: _CampoNumero(
              rotulo: serie.volumeMetricaNome,
              controlador: serie.volume,
            ),
          ),
          const SizedBox(width: AppSpacing.x6),
          SizedBox(
            width: 64,
            child: _CampoNumero(
              rotulo: 'Desc.',
              controlador: serie.descanso,
              somenteInteiro: true,
            ),
          ),
          IconButton(
            onPressed: podeRemover ? aoRemover : null,
            icon: Icon(LucideIcons.x, size: AppSizes.iconeSm, color: cores.danger),
            tooltip: 'Remover série',
          ),
        ],
      ),
    );
  }
}

class _SeloPesoCorporal extends StatelessWidget {
  const _SeloPesoCorporal({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Intensidade: peso corporal',
      child: Container(
        height: AppSizes.campoSerie,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
        decoration: BoxDecoration(
          color: cores.bgInput,
          borderRadius: BorderRadius.circular(AppRadius.campoSerie),
          border: Border.all(color: cores.lineDefault),
        ),
        child: Text('Peso corporal',
            style: AppText.caption.copyWith(color: cores.textSecondary)),
      ),
    );
  }
}

class _CampoNumero extends StatelessWidget {
  const _CampoNumero({
    required this.rotulo,
    required this.controlador,
    this.somenteInteiro = false,
  });

  final String rotulo;
  final TextEditingController controlador;
  final bool somenteInteiro;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: TextInputType.numberWithOptions(decimal: !somenteInteiro),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          somenteInteiro ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
        ),
      ],
      style: AppText.inputValue,
      decoration: InputDecoration(
        labelText: rotulo,
        isDense: true,
      ),
    );
  }
}

class _BarraSalvar extends StatelessWidget {
  const _BarraSalvar({
    required this.salvando,
    required this.aoSalvar,
    required this.rotulo,
  });

  final String rotulo;
  final bool salvando;
  final VoidCallback aoSalvar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.margemTela),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: cores.lineDivider)),
        ),
        child: SizedBox(
          height: AppSizes.botaoPrincipal,
          child: FilledButton(
            onPressed: salvando ? null : aoSalvar,
            child: salvando
                ? const SizedBox(
                    height: AppSizes.iconeSm,
                    width: AppSizes.iconeSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(rotulo),
          ),
        ),
      ),
    );
  }
}

class _SemExercicios extends StatelessWidget {
  const _SemExercicios({required this.cores, required this.mensagem});
  final AppColors cores;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: cores.bgInput,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        mensagem,
        style: AppText.body.copyWith(color: cores.textSecondary),
      ),
    );
  }
}

// _ErroCarregar extraído para shared/estado_erro.dart (PBI-51).
