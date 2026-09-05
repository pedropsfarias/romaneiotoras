import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romaneio_flutter/main.dart';

void main() {
  testWidgets('troca para metro cúbico e edita volume com vírgula', (
    tester,
  ) async {
    var value = const Romaneio(
      empreiteiros: ['A', 'B'],
      toras: [Tora(diametro: 20, quantidade: 2, volumeTotal: .080)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => BalanceamentoScreen(
            romaneio: value,
            onNext: () {},
            onBack: () {},
            onChanged: (updated) => setState(() => value = updated),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('balanceamento-type-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Por metro cúbico').last);
    await tester.pumpAndSettle();
    expect(find.text('Por metro cúbico'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('balanceamento-volume-A')),
      findsOneWidget,
    );
    expect(find.text('Preencher'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('balanceamento-volume-A')));
    await tester.pumpAndSettle();
    expect(find.text('Inserir volume (m³)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0,030');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('0.030'), findsOneWidget);
    expect(find.text('0.050'), findsOneWidget);
    expect(value.balanceamentoVolume['A'], .030);
    expect(find.text('-'), findsWidgets);
  });
}
