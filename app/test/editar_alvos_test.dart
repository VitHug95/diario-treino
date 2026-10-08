import 'package:diario_treino/features/catalogo/metrica.dart';
import 'package:diario_treino/features/fichas/editar_alvos_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const _cargaKg = Metrica(
    id: 1, codigo: 'CARGA_KG', nome: 'Carga', unidade: 'kg', eixo: 'INTENSIDADE');
const _reps = Metrica(
    id: 10, codigo: 'REPETICOES', nome: 'Repetições', unidade: '', eixo: 'VOLUME');
const _tempo = Metrica(
    id: 11, codigo: 'TEMPO_SEG', nome: 'Tempo', unidade: 's', eixo: 'VOLUME');

void main() {
  group('montarResumo', () {
    test('monta a frase completa com carga, reps e descanso', () {
      final frase = montarResumo(
        series: 3,
        intensidade: _cargaKg,
        intensidadeAlvo: 30,
        volume: _reps,
        volumeAlvo: 10,
        descansoSeg: 90,
      );
      expect(frase, '3 séries de 10 com 30 kg, 90 s de descanso.');
    });

    test('usa singular quando é uma série só', () {
      final frase = montarResumo(
        series: 1,
        intensidade: _cargaKg,
        intensidadeAlvo: 20,
        volume: _reps,
        volumeAlvo: 12,
        descansoSeg: null,
      );
      expect(frase, '1 série de 12 com 20 kg.');
    });

    test('omite alvos nulos e mostra unidade de tempo', () {
      final frase = montarResumo(
        series: 4,
        intensidade: null,
        intensidadeAlvo: null,
        volume: _tempo,
        volumeAlvo: 45,
        descansoSeg: 60,
      );
      expect(frase, '4 séries de 45 s, 60 s de descanso.');
    });

    test('formata decimal com vírgula', () {
      final frase = montarResumo(
        series: 2,
        intensidade: _cargaKg,
        intensidadeAlvo: 12.5,
        volume: _reps,
        volumeAlvo: 8,
        descansoSeg: null,
      );
      expect(frase, '2 séries de 8 com 12,5 kg.');
    });
  });
}
