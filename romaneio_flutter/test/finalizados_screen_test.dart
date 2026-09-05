import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:romaneio_flutter/main.dart';
import 'package:romaneio_flutter/services/romaneio_storage.dart';

Romaneio _item({
  required String id,
  required DateTime finalized,
  required String buyer,
  int quantity = 2,
}) => Romaneio(
  id: id,
  numeroRomaneio: int.tryParse(id) ?? 0,
  idInterno: 'internal-$id',
  comprador: buyer,
  finalizadoEm: finalized,
  toras: [Tora(diametro: 20, quantidade: quantity, volumeTotal: 14.993)],
  romaneioAberto: false,
);

Widget _app(List<Romaneio> items, ValueChanged<Romaneio> onOpen) => MaterialApp(
  home: FinalizadosScreen(finalizados: items, onBack: () {}, onOpen: onOpen),
);

void main() {
  testWidgets('ordena por finalização e exibe dados e pluralização', (
    tester,
  ) async {
    final old = _item(
      id: '27',
      finalized: DateTime(2026, 3, 27, 10),
      buyer: 'Antigo',
      quantity: 1,
    );
    final recent = _item(
      id: '28',
      finalized: DateTime(2026, 3, 28, 10),
      buyer: 'Antônio Matias',
    );
    await tester.pumpWidget(_app([old, recent], (_) {}));
    expect(find.text('28 - Antônio Matias'), findsOneWidget);
    expect(find.text('27 - Antigo'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('28 - Antônio Matias')).dy,
      lessThan(tester.getTopLeft(find.text('27 - Antigo')).dy),
    );
    expect(
      find.textContaining('28/03/2026 - 14.993 m³ - 2 toras'),
      findsOneWidget,
    );
    expect(
      find.textContaining('27/03/2026 - 14.993 m³ - 1 tora'),
      findsOneWidget,
    );
  });

  testWidgets('toque abre exatamente o registro escolhido', (tester) async {
    Romaneio? selected;
    final current = _item(
      id: 'atual',
      finalized: DateTime(2026, 3, 1),
      buyer: 'Em andamento',
    );
    final historical = _item(
      id: 'historico',
      finalized: DateTime(2026, 3, 2),
      buyer: 'Comprador histórico',
    );
    await tester.pumpWidget(
      _app([current, historical], (value) => selected = value),
    );
    await tester.tap(find.byKey(const ValueKey('finalizados-item-historico')));
    expect(selected, same(historical));
    expect(selected, isNot(same(current)));
  });

  testWidgets('lista vazia mantém floresta e mostra mensagem', (tester) async {
    await tester.pumpWidget(_app(const [], (_) {}));
    expect(find.text('Nenhum romaneio finalizado.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('finalizados-forest-background')),
      findsOneWidget,
    );
  });

  test(
    'persistência conserva registros e atualizar por ID não duplica',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = RomaneioStorage();
      final first = _item(
        id: 'R-1',
        finalized: DateTime(2026, 3, 1),
        buyer: 'A',
      );
      final updated = first.copyWith(
        comprador: 'B',
        finalizadoEm: DateTime(2026, 3, 2),
      );
      await storage.saveRomaneios(abertos: const [], fechados: [first]);
      await storage.saveRomaneios(abertos: const [], fechados: [updated]);
      final loaded = await storage.loadRomaneios();
      expect(loaded!.fechados, hasLength(1));
      expect(loaded.fechados.single.comprador, 'B');
      expect(loaded.fechados.single.finalizadoEm, DateTime(2026, 3, 2));
    },
  );

  test('migra antigos por data uma única vez e conserva a sequência', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = RomaneioStorage();
    final oldest = _item(
      id: 'oldest-internal',
      finalized: DateTime(2026, 1, 1),
      buyer: 'A',
    ).copyWith(numeroRomaneio: 0);
    final newest = _item(
      id: 'newest-internal',
      finalized: DateTime(2026, 2, 1),
      buyer: 'B',
    ).copyWith(numeroRomaneio: 0);
    await storage.saveRomaneios(abertos: const [], fechados: [newest, oldest]);
    final firstLoad = await storage.loadRomaneios();
    expect(firstLoad!.fechados.first.numeroRomaneio, 2);
    expect(firstLoad.fechados.last.numeroRomaneio, 1);
    final secondLoad = await storage.loadRomaneios();
    expect(secondLoad!.fechados.map((item) => item.numeroRomaneio), [2, 1]);
  });
}
