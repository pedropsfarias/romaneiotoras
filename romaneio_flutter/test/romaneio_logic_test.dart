import 'package:flutter_test/flutter_test.dart';
import 'package:romaneio_flutter/main.dart';

void main() {
  test('deve calcular quantidade e volume do romaneio', () {
    final romaneio = Romaneio(
      id: 'A-01',
      romaneador: 'João',
      comprimento: 12,
      toras: [
        Tora(diametro: 20, quantidade: 2),
        Tora(diametro: 30, quantidade: 1),
      ],
    );

    final summary = romaneio.summary();

    expect(summary['numToras'], 3);
    expect(summary['volToras'], isA<double>());
    expect(summary['volToras'] > 0, isTrue);
  });

  test('deve agrupar diametros por faixa para resumo financeiro', () {
    final romaneio = Romaneio(
      id: 'A-02',
      romaneador: 'Maria',
      comprimento: 10,
      toras: [
        Tora(diametro: 18, quantidade: 5),
        Tora(diametro: 25, quantidade: 3),
        Tora(diametro: 35, quantidade: 2),
      ],
    );

    final grouped = romaneio.groupedVolumeByRange();

    expect(grouped.length, greaterThanOrEqualTo(3));
    expect(grouped.values.any((value) => value > 0), isTrue);
  });
}
