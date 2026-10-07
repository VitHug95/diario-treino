import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rotas/app_router.dart';
import 'catalogo_repository.dart';
import 'exercicio_resumo.dart';

/// Tela 8 do protótipo: busca de exercícios no catálogo (PBI-10).
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  final _buscaController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  void _aoDigitar(String valor) {
    // Espera a digitação parar antes de consultar a API.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(catalogoFiltroProvider.notifier).definirBusca(valor);
    });
  }

  void _abrirCriar(BuildContext context) {
    context.push(Rotas.criarExercicio);
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(catalogoFiltroProvider);
    final resultado = ref.watch(catalogoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercícios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirCriar(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _buscaController,
              onChanged: _aoDigitar,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Buscar exercício',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          _FiltroModalidade(
            selecionada: filtro.modalidade,
            aoSelecionar: (m) =>
                ref.read(catalogoFiltroProvider.notifier).definirModalidade(m),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: resultado.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Erro(aoTentarNovamente: () => ref.invalidate(catalogoProvider)),
              data: (itens) => itens.isEmpty
                  ? const _EstadoVazio()
                  : _ListaExercicios(itens: itens),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltroModalidade extends StatelessWidget {
  const _FiltroModalidade({required this.selecionada, required this.aoSelecionar});

  final ModalidadeFiltro selecionada;
  final ValueChanged<ModalidadeFiltro> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final m in ModalidadeFiltro.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(m.rotulo),
                selected: m == selecionada,
                onSelected: (_) => aoSelecionar(m),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListaExercicios extends StatelessWidget {
  const _ListaExercicios({required this.itens});

  final List<ExercicioResumo> itens;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: itens.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = itens[i];
        final subtitulo = [
          if (e.grupoMuscular != null && e.grupoMuscular!.isNotEmpty) e.grupoMuscular!,
          e.formaDeMedir,
        ].join(' · ');

        return ListTile(
          title: Text(e.nome),
          subtitle: Text(subtitulo),
          trailing: e.proprio ? const _SeloMeu() : null,
          onTap: () {
            // Seleção do exercício entra nas PBIs de ficha/sessão.
          },
        );
      },
    );
  }
}

class _SeloMeu extends StatelessWidget {
  const _SeloMeu();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Exercício criado por você',
      child: Chip(
        label: const Text('Meu'),
        backgroundColor: scheme.secondaryContainer,
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 48),
            const SizedBox(height: 12),
            Text(
              'Nenhum exercício encontrado',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Que tal criar um exercício novo?',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push(Rotas.criarExercicio),
              icon: const Icon(Icons.add),
              label: const Text('Criar exercício'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.aoTentarNovamente});

  final VoidCallback aoTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os exercícios.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: aoTentarNovamente,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
