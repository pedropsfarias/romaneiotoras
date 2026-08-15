import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:romaneio_flutter/main.dart';

void main() {
  testWidgets('login screen renders expected fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          romaneadores: const ['João', 'Maria'],
          selectedRomaneador: null,
          onChanged: (_) {},
          onLogin: () {},
        ),
      ),
    );

    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets(
    'cached romaneador is reused on restart and hides login until logout',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'romaneio_selected_romaneador': 'João',
      });

      await tester.pumpWidget(const RomaneioApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('Romaneador(a): João'), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
    },
  );
}
