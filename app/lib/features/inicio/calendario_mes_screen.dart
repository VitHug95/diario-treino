import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/relogio.dart';
import '../../shared/calendario/calendario_mes.dart';
import '../../shared/calendario/marca_dia.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/fichas_repository.dart';
import '../fichas/plano_models.dart';
import '../sessao/sessao_models.dart';
import '../sessao/sessao_repository.dart';
import 'inicio_logica.dart';
import 'inicio_screen.dart' show abrirFolhaDoDia;

/// Tela "Calendário" (PBI-82): o mês inteiro a partir do cartão "Esta semana".
/// Navega mês a mês para trás sem limite; a seta de avançar para no mês atual.
/// Cada dia com sessão abre a mesma folha do dia da Início.
class CalendarioMesScreen extends ConsumerStatefulWidget {
  const CalendarioMesScreen({super.key});

  @override
  ConsumerState<CalendarioMesScreen> createState() => _CalendarioMesScreenState();
}

class _CalendarioMesScreenState extends ConsumerState<CalendarioMesScreen> {
  late int _ano;
  late int _mes;

  @override
  void initState() {
    super.initState();
    final hoje = ref.read(relogioProvider).agora();
    _ano = hoje.year;
    _mes = hoje.month;
  }

  void _irMesAnterior() {
    final (ano, mes) = CalendarioMes.mesAnterior(_ano, _mes);
    setState(() {
      _ano = ano;
      _mes = mes;
    });
  }

  void _irMesSeguinte() {
    final (ano, mes) = CalendarioMes.mesSeguinte(_ano, _mes);
    setState(() {
      _ano = ano;
      _mes = mes;
    });
  }

  void _irParaHoje() {
    final hoje = ref.read(relogioProvider).agora();
    setState(() {
      _ano = hoje.year;
      _mes = hoje.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hoje = ref.watch(relogioProvider).agora();
    final mesChave = DateTime(_ano, _mes);
    final sessoesAsync = ref.watch(sessoesDoMesProvider(mesChave));
    final planoAsync = ref.watch(planoAtivoProvider);
    final ehMesAtual = CalendarioMes.ehMesAtual(_ano, _mes, hoje);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarraMes(
                  titulo: CalendarioMes.titulo(_ano, _mes),
                  ehMesAtual: ehMesAtual,
                  aoAnterior: _irMesAnterior,
                  aoSeguinte: ehMesAtual ? null : _irMesSeguinte,
                  aoHoje: ehMesAtual ? null : _irParaHoje,
                ),
                const SizedBox(height: AppSpacing.x16),
                Expanded(
                  child: sessoesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _ErroHistorico(
                      aoTentar: () => ref.refresh(sessoesDoMesProvider(mesChave)),
                    ),
                    data: (sessoes) => _GradeMes(
                      ano: _ano,
                      mes: _mes,
                      hoje: hoje,
                      sessoes: sessoes,
                      plano: planoAsync.value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de navegação do mês: ‹ Nome do mês e ano › e, fora do mês atual, "Hoje".
class _BarraMes extends StatelessWidget {
  const _BarraMes({
    required this.titulo,
    required this.ehMesAtual,
    required this.aoAnterior,
    required this.aoSeguinte,
    required this.aoHoje,
  });

  final String titulo;
  final bool ehMesAtual;
  final VoidCallback aoAnterior;
  final VoidCallback? aoSeguinte;
  final VoidCallback? aoHoje;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: aoAnterior,
          icon: const Icon(LucideIcons.chevronLeft, size: AppSizes.iconeMd),
          tooltip: 'Mês anterior',
          constraints: const BoxConstraints(
              minWidth: AppSizes.touchMin, minHeight: AppSizes.touchMin),
        ),
        Expanded(
          child: Column(
            children: [
              Semantics(
                header: true,
                child: Text(titulo,
                    style: AppText.titleS, textAlign: TextAlign.center),
              ),
              if (aoHoje != null)
                SizedBox(
                  height: 28,
                  child: TextButton(
                    onPressed: aoHoje,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Hoje'),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: aoSeguinte,
          icon: Icon(LucideIcons.chevronRight,
              size: AppSizes.iconeMd,
              color: aoSeguinte == null ? cores.iconMuted : null),
          tooltip: 'Mês seguinte',
          constraints: const BoxConstraints(
              minWidth: AppSizes.touchMin, minHeight: AppSizes.touchMin),
        ),
      ],
    );
  }
}

/// Contagem + cabeçalho das colunas + a grade de dias.
class _GradeMes extends StatelessWidget {
  const _GradeMes({
    required this.ano,
    required this.mes,
    required this.hoje,
    required this.sessoes,
    required this.plano,
  });

  final int ano;
  final int mes;
  final DateTime hoje;
  final List<SessaoResumo> sessoes;
  final PlanoAtivo? plano;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final semanas = CalendarioMes.semanasDoMes(
      ano,
      mes,
      hoje: hoje,
      datasComTreino: CalendarioMes.datasComTreino(sessoes),
    );
    final treinados = CalendarioMes.diasTreinados(semanas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$treinados ${treinados == 1 ? 'dia treinado' : 'dias treinados'}',
          style: AppText.caption.copyWith(color: cores.textStrong),
        ),
        const SizedBox(height: AppSpacing.x12),
        // Cabeçalho S T Q Q S S D.
        Row(
          children: [
            for (final inicial in CalendarioMes.iniciaisColunas)
              Expanded(
                child: Text(inicial,
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(color: cores.textSecondary)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x8),
        for (final linha in semanas)
          Row(
            children: [
              for (final celula in linha)
                Expanded(
                  child: celula == null
                      ? const SizedBox(height: AppSizes.touchMin)
                      : _CelulaDia(
                          celula: celula,
                          aoTocar: celula.futuro
                              ? null
                              : () => _abrirDia(context, celula.data),
                        ),
                ),
            ],
          ),
      ],
    );
  }

  void _abrirDia(BuildContext context, DateTime dia) {
    final fichas = [...?plano?.treinos]..sort((a, b) => a.ordem.compareTo(b.ordem));
    abrirFolhaDoDia(
      context,
      dia: dia,
      sessoes: InicioLogica.sessoesDoDia(dia, sessoes),
      fichas: fichas,
      planoNome: plano?.nome,
    );
  }
}

/// Uma célula da grade: número do dia + a marca de estado, como um só nó de
/// semântica (rótulo igual ao da faixa semanal).
class _CelulaDia extends StatelessWidget {
  const _CelulaDia({required this.celula, required this.aoTocar});

  final CelulaMes celula;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      container: true,
      button: !celula.futuro,
      label: _rotulo(celula),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.campoSerie),
        onTap: aoTocar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${celula.dia}',
                    style: AppText.caption.copyWith(
                      color: celula.ehHoje ? cores.primaryText : cores.textSecondary,
                      fontWeight: celula.ehHoje ? FontWeight.w700 : null,
                    )),
                const SizedBox(height: AppSpacing.x4),
                MarcaDia(
                  treinou: celula.treinou,
                  ehHoje: celula.ehHoje,
                  futuro: celula.futuro,
                  tamanho: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _rotulo(CelulaMes c) {
    final dd = '${c.data.day.toString().padLeft(2, '0')}/${c.data.month.toString().padLeft(2, '0')}';
    if (c.treinou) return 'Dia $dd, treino registrado';
    if (c.futuro) return 'Dia $dd, ainda não chegou';
    return 'Dia $dd, sem treino. Toque para registrar';
  }
}

/// Erro de rede: aviso + "Tentar de novo". Nunca um mês vazio falso.
class _ErroHistorico extends StatelessWidget {
  const _ErroHistorico({required this.aoTentar});

  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cloudOff, size: 40, color: cores.iconMuted),
          const SizedBox(height: AppSpacing.x12),
          Text('Não foi possível carregar seu histórico.',
              style: AppText.body.copyWith(color: cores.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
