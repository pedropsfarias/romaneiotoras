import 'package:flutter_test/flutter_test.dart';
import 'package:romaneio_flutter/models/romaneio.dart';
import 'package:romaneio_flutter/services/balanceamento_service.dart';

void main() {
  const service = BalanceamentoService();
  final romaneio = Romaneio(
    empreiteiros: ['A', 'B'],
    toras: [
      Tora(diametro: 20, quantidade: 3, volumeTotal: 3),
      Tora(diametro: 30, quantidade: 1, volumeTotal: 1),
    ],
  );

  test('um empreiteiro recebe 100% dos totais', () {
    final result = service.assignSingle(romaneio.copyWith(empreiteiros: ['A']));
    expect(result.balanceamentoToras, {'A': 4});
    expect(result.balanceamentoVolume, {'A': 4});
    expect(service.validate(result).isValid, isTrue);
  });

  test('valida soma de toras e aceita zero informado', () {
    expect(
      service
          .validate(romaneio.copyWith(balanceamentoToras: {'A': 4, 'B': 0}))
          .isValid,
      isTrue,
    );
    expect(
      service.validate(romaneio.copyWith(balanceamentoToras: {'A': 4})).isValid,
      isFalse,
    );
    expect(
      service
          .validate(romaneio.copyWith(balanceamentoToras: {'A': 5, 'B': 0}))
          .isValid,
      isFalse,
    );
  });

  test(
    'calcula volume proporcional e corrige a soma no último empreiteiro',
    () {
      final value = romaneio.copyWith(balanceamentoToras: {'A': 3, 'B': 1});
      expect(service.validate(value).isValid, isTrue);
      expect(service.rows(value)[0].volume, 3);
      expect(service.rows(value)[1].volume, 1);
    },
  );

  test('valida e expõe distribuição por metro cúbico em milésimos', () {
    final volumeMode = romaneio.copyWith(
      tipoBalanceamento: TipoBalanceamento.metroCubico,
      balanceamentoVolume: {'A': 2.500, 'B': 1.500},
    );
    final rows = service.rows(volumeMode);
    expect(rows.map((row) => row.quantidade), [0, 0]);
    expect(rows.map((row) => row.volume), [2.5, 1.5]);
    expect(service.validate(volumeMode).isValid, isTrue);
    expect(
      service
          .validate(
            volumeMode.copyWith(balanceamentoVolume: {'A': 2.4, 'B': 1.5}),
          )
          .message,
      'Ainda faltam 0.100 m³ para distribuir.',
    );
  });
  test('preenche automaticamente o último empreiteiro por toras', () {
    final value = romaneio.copyWith(
      empreiteiros: ['A', 'B'],
      balanceamentoToras: {'A': 2},
    );
    final rows = service.rows(value);
    expect(rows.map((row) => row.quantidade), [2, 2]);
    expect(rows.every((row) => row.informado), isTrue);
    expect(service.validate(value).isValid, isTrue);
  });

  test('preenche automaticamente o último empreiteiro em três modos', () {
    final toras = romaneio.copyWith(
      empreiteiros: ['A', 'B', 'C'],
      balanceamentoToras: {'A': 1, 'B': 1},
    );
    expect(service.rows(toras).map((row) => row.quantidade), [1, 1, 2]);

    final volume = romaneio.copyWith(
      empreiteiros: ['A', 'B', 'C'],
      tipoBalanceamento: TipoBalanceamento.metroCubico,
      balanceamentoVolume: {'A': 1.000, 'B': 1.000},
    );
    expect(service.rows(volume).map((row) => row.volume), [1, 1, 2]);
    expect(service.validate(volume).isValid, isTrue);
  });
}
