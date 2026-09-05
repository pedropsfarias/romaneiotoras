import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romaneio_flutter/main.dart';

void main() {
  Widget screen(Romaneio value) => MaterialApp(
    home: RomaneioScreen(
      romaneio: value,
      onBack: () {},
      onChanged: (_) {},
      onFinished: () {},
      onFinalize: (value) async => value,
    ),
  );

  testWidgets('abre com classes vazias sem RangeError', (tester) async {
    await tester.pumpWidget(screen(const Romaneio(id: 'R-vazio')));
    await tester.pump();
    expect(find.text('Romaneio'), findsOneWidget);
    expect(find.text('18-24'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renderiza dados com quatro classes sem acessar a quinta posição',
    (tester) async {
      await tester.pumpWidget(
        screen(
          const Romaneio(
            id: 'R-quatro',
            toras: [
              Tora(diametro: 20, quantidade: 1, volumeTotal: 1),
              Tora(diametro: 26, quantidade: 1, volumeTotal: 1),
              Tora(diametro: 31, quantidade: 1, volumeTotal: 1),
              Tora(diametro: 36, quantidade: 1, volumeTotal: 1),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('40'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
