import 'package:dio/dio.dart';
import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/perfil_api.dart';
import 'package:diario_treino/features/auth/perfil_screen.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
import 'package:diario_treino/features/medidas/dados_corporais_screen.dart';
import 'package:diario_treino/features/medidas/medidas_comandos.dart';
import 'package:diario_treino/features/medidas/medidas_formato.dart';
import 'package:diario_treino/features/medidas/medidas_models.dart';
import 'package:diario_treino/features/medidas/medidas_repository.dart';
import 'package:diario_treino/features/medidas/perfil_corporal_comandos.dart';
import 'package:diario_treino/features/medidas/perfil_corporal_models.dart';
import 'package:diario_treino/features/medidas/perfil_corporal_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PBI-93 (E12): dados corporais e TMB no app. Linha no Perfil, tela com sexo,
/// nascimento, altura e peso, cartão da TMB (três estados), peso só enviado
/// quando muda, limpar com confirmação e invalidação entre medidas e dados.

final _hoje = DateTime(2026, 11, 9);
final _nasc = DateTime(1995, 5, 20); // 31 anos completos em 09/11/2026

class _RelogioFixo implements Relogio {
  @override
  DateTime agora() => DateTime(2026, 11, 9, 22, 30); // à noite: em UTC já seria dia 10
}

typedef _Salvo = ({
  SexoBiologico? sexo,
  DateTime? nascimento,
  int? altura,
  double? peso,
  DateTime? dataPeso,
});

class _RepoPerfil extends PerfilCorporalRepository {
  _RepoPerfil([PerfilCorporal? inicial])
      : atual = inicial ?? const PerfilCorporal(motivoSemTmb: MotivoSemTmb.dadosIncompletos),
        super(Dio());

  PerfilCorporal atual;
  int leituras = 0;
  int limpezas = 0;
  bool falharLeitura = false;
  bool falharSalvar = false;
  final salvos = <_Salvo>[];

  @override
  Future<PerfilCorporal> obter() async {
    leituras++;
    if (falharLeitura) throw Exception('rede');
    return atual;
  }

  @override
  Future<PerfilCorporal> salvarPerfilCorporal({
    SexoBiologico? sexo,
    DateTime? nascimento,
    int? alturaCm,
    double? pesoKg,
    DateTime? dataPeso,
  }) async {
    if (falharSalvar) throw const PerfilCorporalException('Sem conexão.');
    salvos.add((
      sexo: sexo,
      nascimento: nascimento,
      altura: alturaCm,
      peso: pesoKg,
      dataPeso: dataPeso,
    ));
    final peso = pesoKg ?? atual.pesoKg;
    final completo = sexo != null && nascimento != null && alturaCm != null && peso != null;
    atual = PerfilCorporal(
      sexo: sexo,
      nascimento: nascimento,
      alturaCm: alturaCm,
      pesoKg: peso,
      idade: nascimento == null ? null : 31,
      tmbKcal: completo ? 1755 : null,
      motivoSemTmb: completo ? null : MotivoSemTmb.dadosIncompletos,
    );
    return atual;
  }

  @override
  Future<void> limparPerfilCorporal() async {
    limpezas++;
    // O peso é uma medida: continua depois de limpar.
    atual = PerfilCorporal(
        pesoKg: atual.pesoKg, motivoSemTmb: MotivoSemTmb.dadosIncompletos);
  }
}

PerfilCorporal _completo({double peso = 78.0}) => PerfilCorporal(
      sexo: SexoBiologico.masculino,
      nascimento: _nasc,
      alturaCm: 180,
      pesoKg: peso,
      idade: 31,
      tmbKcal: 1755,
    );

Future<ProviderScope> _escopo(_RepoPerfil repo, Widget filho) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      perfilCorporalRepositoryProvider.overrideWithValue(repo),
      relogioProvider.overrideWithValue(_RelogioFixo()),
      perfilProvider.overrideWith((ref) async => const Perfil(
          id: 'u1', nome: 'Vitor', email: 'v@teste.local', papeis: ['ATLETA'])),
      convitesPendentesProvider.overrideWith((ref) async => []),
      resumoMedidasProvider.overrideWith(
          (ref) async => const ResumoMedidas(ultimas: [], historico: [])),
    ],
    child: filho,
  );
}

void _telaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _abrir(WidgetTester tester, _RepoPerfil repo, {ThemeData? tema}) async {
  _telaDeCelular(tester);
  await tester.pumpWidget(await _escopo(
    repo,
    MaterialApp(theme: tema ?? AppTheme.claro, home: const DadosCorporaisScreen()),
  ));
  await tester.pumpAndSettle();
}

Finder _campo(String rotulo) => find.widgetWithText(TextField, rotulo);

String _texto(WidgetTester tester, String rotulo) =>
    tester.widget<TextField>(_campo(rotulo)).controller!.text;

void main() {
  // ---- Formatação ----

  group('formatação', () {
    test('milhar pt-BR sem intl', () {
      expect(formatarMilhar(1755), '1.755');
      expect(formatarMilhar(999), '999');
      expect(formatarMilhar(12345), '12.345');
      expect(formatarMilhar(1000000), '1.000.000');
    });

    test('peso curto: inteiro sem casa, quebrado com vírgula', () {
      expect(formatarPesoCurto(78.0), '78 kg');
      expect(formatarPesoCurto(78.5), '78,5 kg');
    });

    test('resumo do Perfil', () {
      expect(resumoDadosParaPerfil(const PerfilCorporal()), 'Preencha para calcular sua TMB');
      expect(resumoDadosParaPerfil(_completo()), '78 kg · 180 cm · TMB 1.755 kcal por dia');
      expect(
          resumoDadosParaPerfil(const PerfilCorporal(
              pesoKg: 78.0, motivoSemTmb: MotivoSemTmb.dadosIncompletos)),
          '78 kg · preencha para calcular a TMB');
      expect(
          resumoDadosParaPerfil(const PerfilCorporal(
              pesoKg: 60.0, alturaCm: 165, motivoSemTmb: MotivoSemTmb.menorDeIdade)),
          '60 kg · 165 cm · TMB só para adultos');
    });
  });

  // ---- Perfil ----

  testWidgets('Perfil: a linha "Dados corporais" mostra peso, altura e TMB', (tester) async {
    await tester.pumpWidget(await _escopo(
        _RepoPerfil(_completo()), MaterialApp(theme: AppTheme.claro, home: const PerfilScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Dados corporais'), findsOneWidget);
    expect(find.text('78 kg · 180 cm · TMB 1.755 kcal por dia'), findsOneWidget);
  });

  testWidgets('Perfil: sem dados, convida a preencher', (tester) async {
    await tester.pumpWidget(await _escopo(
        _RepoPerfil(), MaterialApp(theme: AppTheme.claro, home: const PerfilScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Preencha para calcular sua TMB'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // o Perfil não ganha campos
  });

  testWidgets('Perfil: a linha fala o resumo, não só o título', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _escopo(
        _RepoPerfil(_completo()), MaterialApp(theme: AppTheme.claro, home: const PerfilScreen())));
    await tester.pumpAndSettle();

    expect(
        find.bySemanticsLabel('Dados corporais. 78 kg · 180 cm · TMB 1.755 kcal por dia'),
        findsOneWidget);
    handle.dispose();
  });

  // ---- Cartão da TMB: três estados ----

  testWidgets('TMB calculada: mostra o número que veio da API', (tester) async {
    await _abrir(tester, _RepoPerfil(_completo()));

    expect(find.text('TAXA METABÓLICA BASAL'), findsOneWidget);
    expect(find.text('1.755 kcal por dia'), findsOneWidget);
  });

  testWidgets('TMB incompleta: diz o que falta', (tester) async {
    await _abrir(tester, _RepoPerfil());

    expect(find.text('Preencha sexo, nascimento, altura e peso'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
  });

  testWidgets('TMB de menor de idade: a estimativa vale para adultos', (tester) async {
    await _abrir(
        tester,
        _RepoPerfil(PerfilCorporal(
          sexo: SexoBiologico.masculino,
          nascimento: DateTime(2010, 1, 1),
          alturaCm: 160,
          pesoKg: 50.0,
          idade: 16,
          motivoSemTmb: MotivoSemTmb.menorDeIdade,
        )));

    expect(find.text('A estimativa vale para adultos'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
  });

  // ---- Formulário ----

  testWidgets('Abre preenchido com os dados, a idade na ajuda e a linha de privacidade',
      (tester) async {
    await _abrir(tester, _RepoPerfil(_completo()));

    expect(find.text('Só você vê estes dados.'), findsOneWidget);
    expect(find.text('20/05/1995'), findsOneWidget);
    expect(find.text('31 anos'), findsOneWidget);
    expect(_texto(tester, 'Altura'), '180');
    expect(_texto(tester, 'Peso'), '78,0');
    final selecionado = tester
        .widget<SegmentedButton<SexoBiologico>>(find.byType(SegmentedButton<SexoBiologico>))
        .selected;
    expect(selecionado, {SexoBiologico.masculino});
  });

  testWidgets('Sem dados, os campos abrem vazios e nada está selecionado', (tester) async {
    await _abrir(tester, _RepoPerfil());

    expect(_texto(tester, 'Altura'), isEmpty);
    expect(_texto(tester, 'Peso'), isEmpty);
    expect(find.text('Toque para escolher'), findsOneWidget);
    expect(
        tester
            .widget<SegmentedButton<SexoBiologico>>(find.byType(SegmentedButton<SexoBiologico>))
            .selected,
        isEmpty);
  });

  testWidgets('O sexo é anunciado como grupo', (tester) async {
    final handle = tester.ensureSemantics();
    await _abrir(tester, _RepoPerfil(_completo()));

    expect(find.bySemanticsLabel('Sexo, para o cálculo'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Salvar com o peso novo manda o peso e o dia local (à noite, ainda hoje)',
      (tester) async {
    final repo = _RepoPerfil();
    await _abrir(tester, repo);

    await tester.tap(find.text('Feminino'));
    await tester.pump();
    await tester.enterText(_campo('Altura'), '165');
    await tester.enterText(_campo('Peso'), '60,5');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final s = repo.salvos.single;
    expect(s.sexo, SexoBiologico.feminino);
    expect(s.altura, 165);
    expect(s.peso, 60.5);
    // O app manda o dia dele (09/11, às 22h30), não o "hoje" do servidor em UTC.
    expect(s.dataPeso, _hoje);
    expect(find.text('Dados salvos'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Salvar sem mexer no peso NÃO manda o peso (não cria ponto falso)',
      (tester) async {
    final repo = _RepoPerfil(_completo());
    await _abrir(tester, repo);

    await tester.enterText(_campo('Altura'), '181'); // muda só a altura
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final s = repo.salvos.single;
    expect(s.altura, 181);
    expect(s.peso, isNull);
    expect(s.dataPeso, isNull);
    // Sexo e nascimento seguem (o PUT substitui os três).
    expect(s.sexo, SexoBiologico.masculino);
    expect(s.nascimento, _nasc);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Depois de salvar o peso, salvar de novo não repete o peso', (tester) async {
    final repo = _RepoPerfil(_completo());
    await _abrir(tester, repo);

    await tester.enterText(_campo('Peso'), '79');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repo.salvos, hasLength(2));
    expect(repo.salvos[0].peso, 79.0);
    expect(repo.salvos[1].peso, isNull);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Tocar no sexo selecionado desmarca (limpa) e salva sem sexo', (tester) async {
    final repo = _RepoPerfil(_completo());
    await _abrir(tester, repo);

    await tester.tap(find.text('Masculino'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repo.salvos.single.sexo, isNull);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Valores fora da faixa: erro no campo e nada é gravado', (tester) async {
    final repo = _RepoPerfil();
    await _abrir(tester, repo);

    await tester.enterText(_campo('Altura'), '99');
    await tester.enterText(_campo('Peso'), '20');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Use um valor entre 100 e 250 cm.'), findsOneWidget);
    expect(find.text('Use um valor entre 30 e 300 kg.'), findsOneWidget);
    expect(repo.salvos, isEmpty);

    await tester.enterText(_campo('Peso'), '78,25');
    await tester.enterText(_campo('Altura'), '180');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Use no máximo uma casa decimal.'), findsOneWidget);
    expect(repo.salvos, isEmpty);

    // Corrigir o campo limpa o erro dele.
    await tester.enterText(_campo('Peso'), '78');
    await tester.pumpAndSettle(); // o texto de erro some com uma animação
    expect(find.text('Use no máximo uma casa decimal.'), findsNothing);
  });

  testWidgets('Tudo vazio é válido: salva só a limpeza dos campos', (tester) async {
    final repo = _RepoPerfil();
    await _abrir(tester, repo);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final s = repo.salvos.single;
    expect(s.sexo, isNull);
    expect(s.nascimento, isNull);
    expect(s.altura, isNull);
    expect(s.peso, isNull);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Falha ao salvar mostra o erro e mantém o que foi digitado', (tester) async {
    final repo = _RepoPerfil()..falharSalvar = true;
    await _abrir(tester, repo);

    await tester.enterText(_campo('Altura'), '170');
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sem conexão.'), findsOneWidget);
    expect(_texto(tester, 'Altura'), '170');

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('A data de nascimento só aceita idade entre 10 e 100 anos', (tester) async {
    await _abrir(tester, _RepoPerfil());

    await tester.tap(find.text('Toque para escolher'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(picker.lastDate, DateTime(2016, 11, 9)); // 10 anos
    expect(picker.firstDate, DateTime(1926, 11, 9)); // 100 anos
  });

  // ---- Limpar ----

  testWidgets('Limpar pede confirmação, apaga os campos e deixa o peso', (tester) async {
    final repo = _RepoPerfil(_completo());
    await _abrir(tester, repo);

    await tester.tap(find.widgetWithText(TextButton, 'Limpar dados corporais'));
    await tester.pumpAndSettle();
    expect(find.text('Limpar dados corporais?'), findsOneWidget);
    expect(find.textContaining('histórico de peso continua nas medidas'), findsOneWidget);

    // Cancelar não limpa.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar').last);
    await tester.pumpAndSettle();
    expect(repo.limpezas, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Limpar dados corporais'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Limpar dados'));
    await tester.pumpAndSettle();

    expect(repo.limpezas, 1);
    expect(_texto(tester, 'Altura'), isEmpty);
    expect(find.text('Toque para escolher'), findsOneWidget);
    expect(_texto(tester, 'Peso'), '78,0'); // o histórico de peso fica
    expect(find.text('Preencha sexo, nascimento, altura e peso'), findsOneWidget);
    expect(find.text('Dados corporais limpos'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  // ---- Carga ----

  testWidgets('Erro de rede ao carregar: "Tentar de novo"', (tester) async {
    final repo = _RepoPerfil(_completo())..falharLeitura = true;
    await _abrir(tester, repo);

    expect(find.text('Não foi possível carregar seus dados corporais.'), findsOneWidget);

    repo.falharLeitura = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('1.755 kcal por dia'), findsOneWidget);
  });

  // ---- Acessibilidade e tema ----

  for (final escuro in [false, true]) {
    testWidgets('Funciona em 360 px e fonte 1,3x (${escuro ? 'escuro' : 'claro'})',
        (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(await _escopo(
        _RepoPerfil(_completo()),
        MaterialApp(
          theme: escuro ? AppTheme.escuro : AppTheme.claro,
          home: const DadosCorporaisScreen(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // sem overflow
      expect(find.text('1.755 kcal por dia'), findsOneWidget);
    });
  }

  // ---- Invalidação ----

  test('Salvar os dados atualiza a tela e a lista de medidas (Mudanca.perfilCorporal)',
      () async {
    final repo = _RepoPerfil();
    var leiturasResumo = 0;
    final c = ProviderContainer(overrides: [
      perfilCorporalRepositoryProvider.overrideWithValue(repo),
      resumoMedidasProvider.overrideWith((ref) async {
        leiturasResumo++;
        return const ResumoMedidas(ultimas: [], historico: []);
      }),
    ]);
    addTearDown(c.dispose);
    c.listen(perfilCorporalProvider, (_, __) {});
    c.listen(resumoMedidasProvider, (_, __) {});
    await c.read(perfilCorporalProvider.future);
    await c.read(resumoMedidasProvider.future);
    final antesPerfil = repo.leituras;
    final antesResumo = leiturasResumo;

    await c.read(perfilCorporalComandosProvider).salvar(
        sexo: SexoBiologico.masculino,
        nascimento: _nasc,
        alturaCm: 180,
        pesoKg: 78.0,
        dataPeso: _hoje);

    // O peso salvo virou uma medida PESO: as duas leituras são refeitas.
    expect((await c.read(perfilCorporalProvider.future)).tmbKcal, 1755);
    await c.read(resumoMedidasProvider.future);
    expect(repo.leituras, greaterThan(antesPerfil));
    expect(leiturasResumo, greaterThan(antesResumo));
  });

  test('Registrar um peso nas medidas atualiza os dados corporais (Mudanca.medidas)',
      () async {
    final repo = _RepoPerfil(_completo());
    final repoMedidas = _RepoMedidasMudo();
    final c = ProviderContainer(overrides: [
      perfilCorporalRepositoryProvider.overrideWithValue(repo),
      medidasRepositoryProvider.overrideWithValue(repoMedidas),
    ]);
    addTearDown(c.dispose);
    c.listen(perfilCorporalProvider, (_, __) {});
    await c.read(perfilCorporalProvider.future);
    final antes = repo.leituras;

    await c
        .read(medidasComandosProvider)
        .salvar(_hoje, {TipoMedida.peso: 80.0});

    await c.read(perfilCorporalProvider.future);
    expect(repo.leituras, greaterThan(antes)); // a TMB usa o peso mais recente
  });

  test('Mesmo quando salvar falha, os derivados são invalidados (finally)', () async {
    final repo = _RepoPerfil()..falharSalvar = true;
    final c = ProviderContainer(overrides: [
      perfilCorporalRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    c.listen(perfilCorporalProvider, (_, __) {});
    await c.read(perfilCorporalProvider.future);
    final antes = repo.leituras;

    await expectLater(
      c.read(perfilCorporalComandosProvider).salvar(alturaCm: 180),
      throwsA(isA<PerfilCorporalException>()),
    );
    await c.read(perfilCorporalProvider.future);
    expect(repo.leituras, greaterThan(antes));
  });
}

class _RepoMedidasMudo extends MedidasRepository {
  _RepoMedidasMudo() : super(Dio());

  @override
  Future<void> salvarMedidas(DateTime data, Map<TipoMedida, double?> valores) async {}
}
