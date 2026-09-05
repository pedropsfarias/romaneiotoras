import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:romaneio_flutter/main.dart';
import 'package:romaneio_flutter/services/romaneio_export_service.dart';

void _noop() {}

void main() {
  Map<String, Object> masterPrefs() => {
    'romaneio_selected_romaneador': 'João',
    'romaneio_master_data': jsonEncode({
      'version': 1,
      'fileName': 'fixture.xlsx',
      'importedAt': '2026-08-27T12:00:00.000',
      'romaneadores': ['João', 'Maria'],
      'compradores': ['C'],
      'empreiteiros': ['E'],
      'proprietarios': ['P'],
      'municipios': ['M'],
      'carregadores': ['Carg'],
      'medidores': ['Med'],
      'motoristas': ['Mot'],
      'operadores': ['Op'],
      'localidades': ['L'],
      'placas': ['VARIAS'],
    }),
  };

  testWidgets('primeira abertura sem mestre exige importação', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RomaneioApp());
    await tester.pumpAndSettle();
    expect(find.text('SELECIONE O ARQUIVO MESTRE'), findsOneWidget);
    expect(find.text('ENTRAR'), findsNothing);
  });

  testWidgets('captura visual da tela inicial', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MasterImportScreen(isImporting: false, onImport: _noop),
      ),
    );
    await tester.pumpAndSettle();

    final logo = tester.widget<Image>(
      find.byKey(const ValueKey('florestal-mierzva-logo')),
    );
    expect(logo.fit, BoxFit.contain);
    expect(
      (logo.image as AssetImage).assetName,
      'assets/images/logo_florestal_mierzva.png',
    );

    await expectLater(
      find.byType(MasterImportScreen),
      matchesGoldenFile('goldens/master_import_screen.png'),
    );
  });

  testWidgets('logo continua carregando ao reiniciar a tela', (tester) async {
    Widget app() => const MaterialApp(
      home: MasterImportScreen(isImporting: false, onImport: _noop),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('florestal-mierzva-logo')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('florestal-mierzva-logo')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('ENTRAR'), findsOneWidget);
  });

  testWidgets(
    'cached romaneador is reused on restart and hides login until logout',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(masterPrefs());

      await tester.pumpWidget(const RomaneioApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('Romaneador(a): João'), findsOneWidget);
      expect(find.text('ENTRAR'), findsNothing);
    },
  );

  testWidgets('login button states follow valid selection and clearing', (
    WidgetTester tester,
  ) async {
    String? selection;
    var loginCount = 0;

    Widget app(List<String> romaneadores) => MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => LoginScreen(
          romaneadores: romaneadores,
          selectedRomaneador: selection,
          onChanged: (value) => setState(() => selection = value),
          onLogin: () => loginCount++,
        ),
      ),
    );

    await tester.pumpWidget(app(const ['Joao', 'Maria']));

    ElevatedButton button() => tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('login-button')),
    );
    Color? background(Set<WidgetState> states) =>
        button().style?.backgroundColor?.resolve(states);
    Color? foreground(Set<WidgetState> states) =>
        button().style?.foregroundColor?.resolve(states);

    expect(button().onPressed, isNull);
    expect(background({WidgetState.disabled}), const Color(0xFFD6D6D6));
    expect(foreground({WidgetState.disabled}), const Color(0xFF757575));
    await tester.tap(find.byKey(const ValueKey('login-button')));
    expect(loginCount, 0);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria').last);
    await tester.pumpAndSettle();

    expect(button().onPressed, isNotNull);
    expect(background({}), const Color(0xFF26A69A));
    expect(foreground({}), const Color(0xFFFFFFFF));
    await tester.tap(find.byKey(const ValueKey('login-button')));
    expect(loginCount, 1);

    selection = null;
    await tester.pumpWidget(app(const ['Joao', 'Maria']));
    await tester.pump();
    expect(button().onPressed, isNull);
    expect(background({WidgetState.disabled}), const Color(0xFFD6D6D6));
    await tester.tap(find.byKey(const ValueKey('login-button')));
    expect(loginCount, 1);

    selection = 'Maria';
    await tester.pumpWidget(app(const ['Joao']));
    await tester.pump();
    expect(button().onPressed, isNull);
    expect(background({WidgetState.disabled}), const Color(0xFFD6D6D6));
  });

  testWidgets('creates exactly one romaneio after choosing buyer', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(masterPrefs());

    await tester.pumpWidget(const RomaneioApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'NOVO'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Comprador'), findsWidgets);

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('romaneio_flutter_state'), isNull);

    await tester.tap(find.byKey(const ValueKey('comprador-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comprador-next-button')));
    await tester.pumpAndSettle();

    expect(find.text('Comprimento'), findsOneWidget);
    prefs = await SharedPreferences.getInstance();
    final persistedState = jsonDecode(
      prefs.getString('romaneio_flutter_state')!,
    ) as Map<String, dynamic>;
    expect(persistedState['abertos'], hasLength(1));
    expect(persistedState['fechados'], isEmpty);
    expect(persistedState['abertos'][0]['comprador'], 'C');
    expect(
      persistedState['abertos'][0]['compradorChaveOrigem'],
      'compradores:linha:2',
    );
  });

  testWidgets('buyer picker searches, selects, cancels and clears', (
    WidgetTester tester,
  ) async {
    var draft = const Romaneio(id: 'draft', romaneador: 'Maria');
    var nextCount = 0;
    const buyers = [
      CompradorMaster(chaveOrigem: 'row-2', nome: 'Madeiras Árvore'),
      CompradorMaster(
        chaveOrigem: 'row-3',
        nome: 'Empresa com um nome comercial muito longo para validar quebra de linha',
      ),
    ];

    Widget app() => MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => CompradorScreen(
          romaneio: draft,
          compradores: buyers,
          onChanged: (value) => setState(() => draft = value),
          onNext: () => nextCount++,
          onBack: () {},
        ),
      ),
    );

    await tester.pumpWidget(app());
    ElevatedButton nextButton() => tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('comprador-next-button')),
    );
    expect(nextButton().onPressed, isNull);
    expect(find.text('Florestal Mierzva'), findsOneWidget);
    expect(find.text('manejo de florestas'), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-rule-top')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-rule-bottom')), findsOneWidget);
    final buyerFooterBottom = tester
        .getRect(find.byKey(const ValueKey('comprador-forest-footer')))
        .bottom;
    final buyerRuleBottom = tester
        .getRect(find.byKey(const ValueKey('brand-rule-bottom')))
        .bottom;
    expect(buyerFooterBottom - buyerRuleBottom, 14);

    await tester.tap(find.byKey(const ValueKey('comprador-field')));
    await tester.pumpAndSettle();
    expect(find.text('Madeiras Árvore'), findsOneWidget);
    expect(find.textContaining('Empresa com um nome'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('comprador-search')),
      'arvore',
    );
    await tester.pump();
    expect(find.text('Madeiras Árvore'), findsOneWidget);
    expect(find.textContaining('Empresa com um nome'), findsNothing);

    await tester.tap(find.text('Madeiras Árvore'));
    await tester.pumpAndSettle();
    expect(draft.comprador, 'Madeiras Árvore');
    expect(draft.compradorChaveOrigem, 'row-2');
    expect(nextButton().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('comprador-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('comprador-search')),
      'sem resultado',
    );
    await tester.pump();
    expect(find.text('Adicionar "sem resultado"'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-comprador-search')));
    await tester.pump();
    expect(find.text('Madeiras Árvore'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('close-comprador-picker')));
    await tester.pumpAndSettle();
    expect(draft.comprador, 'Madeiras Árvore');

    await tester.tap(find.byKey(const ValueKey('clear-comprador')));
    await tester.pump();
    expect(draft.comprador, isEmpty);
    expect(draft.compradorChaveOrigem, isEmpty);
    expect(nextButton().onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('comprador-next-button')));
    expect(nextCount, 0);
  });

  testWidgets('novo romaneio inicia comprador vazio e mantém catálogo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompradorScreen(
          romaneio: const Romaneio(id: 'new'),
          compradores: const [
            CompradorMaster(
              chaveOrigem: 'laselva',
              nome: 'Compensados LaSelva Ltda',
            ),
          ],
          onChanged: (_) {},
          onNext: () {},
          onBack: () {},
        ),
      ),
    );

    expect(find.text('Digite ou selecione'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-comprador')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('comprador-field')));
    await tester.pumpAndSettle();
    expect(find.text('Compensados LaSelva Ltda'), findsOneWidget);
  });

  testWidgets('voltar para a tela preserva o comprador informado', (
    WidgetTester tester,
  ) async {
    var draft = const Romaneio(id: 'draft');
    Widget app() => MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => CompradorScreen(
          romaneio: draft,
          compradores: const [
            CompradorMaster(chaveOrigem: 'buyer-1', nome: 'Comprador 1'),
          ],
          onChanged: (value) => setState(() => draft = value),
          onNext: () {},
          onBack: () {},
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const ValueKey('comprador-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprador 1').last);
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());

    expect(find.text('Comprador 1'), findsOneWidget);
    expect(draft.comprador, 'Comprador 1');
  });

  testWidgets('romaneio existente carrega o comprador salvo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompradorScreen(
          romaneio: const Romaneio(
            id: 'saved',
            comprador: 'Compensados LaSelva Ltda',
            compradorChaveOrigem: 'laselva',
          ),
          compradores: const [
            CompradorMaster(
              chaveOrigem: 'laselva',
              nome: 'Compensados LaSelva Ltda',
            ),
          ],
          onChanged: (_) {},
          onNext: () {},
          onBack: () {},
        ),
      ),
    );

    expect(find.text('Compensados LaSelva Ltda'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-comprador')), findsOneWidget);
  });

  testWidgets('novo romaneio seguinte não reutiliza comprador anterior', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(masterPrefs());
    await tester.pumpWidget(const RomaneioApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'NOVO'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comprador-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comprador-next-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'NOVO'));
    await tester.pumpAndSettle();

    expect(find.text('Digite ou selecione'), findsOneWidget);
    expect(find.text('C'), findsNothing);
  });

  testWidgets('buyer screen handles empty list and system inset', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              padding: const EdgeInsets.only(bottom: 24),
              viewPadding: const EdgeInsets.only(bottom: 24),
            ),
            child: child!,
          );
        },
        home: CompradorScreen(
          romaneio: const Romaneio(id: 'empty'),
          compradores: const [],
          onChanged: (_) {},
          onNext: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Nenhum comprador disponível na base mestre.'),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('comprador-forest-footer')))
          .bottom,
      616,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home keeps centered actions and responsive forest footer', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var newCount = 0;
    Widget withNavigationInset(BuildContext context, Widget? child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(
          padding: const EdgeInsets.only(bottom: 24),
          viewPadding: const EdgeInsets.only(bottom: 24),
        ),
        child: child!,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        builder: withNavigationInset,
        home: HomeScreen(
          romaneador: 'Maria',
          abertos: const [],
          fechados: const [],
          onNew: () => newCount++,
          onOpen: (_) {},
          onLogout: () {},
          onUpdateMaster: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Romaneador(a): Maria'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-forest-footer')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-forest-image')), findsOneWidget);
    expect(find.text('Florestal Mierzva'), findsOneWidget);
    expect(find.text('manejo de florestas'), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-rule-top')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-rule-bottom')), findsOneWidget);
    final footerRect = tester.getRect(
      find.byKey(const ValueKey('home-forest-footer')),
    );
    final homeRuleBottom = tester
        .getRect(find.byKey(const ValueKey('brand-rule-bottom')))
        .bottom;
    expect(footerRect.bottom - homeRuleBottom, 14);
    expect(tester.takeException(), isNull);

    final forestImage = tester.widget<Image>(
      find.byKey(const ValueKey('home-forest-image')),
    );
    expect(
      (forestImage.image as AssetImage).assetName,
      'assets/images/floresta_rodape.png',
    );
    expect(forestImage.fit, BoxFit.contain);
    expect(forestImage.alignment, Alignment.bottomCenter);
    expect(footerRect.left, 0);
    expect(footerRect.right, 320);
    expect(footerRect.bottom, 616);
    expect(footerRect.width / footerRect.height, closeTo(1774 / 887, .01));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF000000),
    );

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'NOVO'),
    );
    expect(button.style?.backgroundColor?.resolve({}), const Color(0xFF009688));
    expect(button.style?.foregroundColor?.resolve({}), Colors.white);

    final contentCenter = tester.getCenter(find.text('Romaneador(a): Maria'));
    expect(
      contentCenter.dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('home-forest-footer'))).dy,
      ),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'NOVO'));
    expect(newCount, 1);

    await tester.pumpWidget(
      MaterialApp(
        builder: withNavigationInset,
        home: HomeScreen(
          romaneador: 'Maria',
          abertos: const [Romaneio(id: 'aberto')],
          fechados: const [Romaneio(id: 'fechado')],
          onNew: () {},
          onOpen: (_) {},
          onLogout: () {},
          onUpdateMaster: () {},
        ),
      ),
    );
    await tester.pump();

    final lastActionBottom = tester.getBottomLeft(find.text('Finalizados')).dy;
    final footerTop = tester
        .getTopLeft(find.byKey(const ValueKey('home-forest-footer')))
        .dy;
    expect(lastActionBottom, lessThan(footerTop));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(430, 800);
    await tester.pump();
    final wideFooterRect = tester.getRect(
      find.byKey(const ValueKey('home-forest-footer')),
    );
    expect(wideFooterRect.left, 0);
    expect(wideFooterRect.right, 430);
    expect(wideFooterRect.bottom, 776);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion screen keeps saved photos in their slots', (
    WidgetTester tester,
  ) async {
    final tempDirectory = Directory('.dart_tool/romaneio_photos_test')
      ..createSync(recursive: true);
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final firstPhoto = File('${tempDirectory.path}/first.png')
      ..writeAsBytesSync(pngBytes);
    final thirdPhoto = File('${tempDirectory.path}/third.png')
      ..writeAsBytesSync(pngBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: CompletoScreen(
          romaneio: Romaneio(
            id: 'R-photos',
            fotos: [firstPhoto.path, '', thirdPhoto.path],
          ),
          onBack: () {},
          onFinalize: (romaneio) async => romaneio,
          onFinished: () {},
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('romaneio-photo-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('romaneio-photo-1')), findsNothing);
    expect(find.byKey(const ValueKey('romaneio-photo-2')), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

    final firstImage = tester.widget<Image>(
      find.byKey(const ValueKey('romaneio-photo-0')),
    );
    expect(firstImage.fit, BoxFit.cover);
  });

  testWidgets('finalization saves once and retries only failed export', (
    WidgetTester tester,
  ) async {
    final service = _RetryExportService();
    var saveCount = 0;
    Romaneio? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: CompletoScreen(
          romaneio: const Romaneio(id: 'R-flow'),
          exportService: service,
          onBack: () {},
          onFinalize: (romaneio) async {
            saveCount++;
            saved = romaneio.copyWith(romaneioAberto: false);
            return saved!;
          },
          onFinished: () {},
          onChanged: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Observação mais recente');
    final finalizeButton = find.widgetWithText(ElevatedButton, 'Finalizar');
    await tester.ensureVisible(finalizeButton);
    await tester.tap(finalizeButton);
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(saved!.observacoes, 'Observação mais recente');
    expect(service.calls[RomaneioExportFormat.pdf], 1);
    expect(find.textContaining('PDF: falha'), findsOneWidget);
    expect(find.textContaining('XLSX'), findsNothing);

    final retryButton = find.text('Tentar exportações novamente');
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(service.calls[RomaneioExportFormat.pdf], 2);
    expect(find.textContaining('PDF disponível em:'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Concluir'), findsOneWidget);
  });

  testWidgets('abre preenchimento de preço com foco e aceita ponto e vírgula', (
    WidgetTester tester,
  ) async {
    var draft = const Romaneio(
      id: 'price',
      toras: [Tora(diametro: 20, quantidade: 1, volumeTotal: 2)],
    );
    Widget app() => MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => ResumoScreen(
          romaneio: draft,
          onNext: () {},
          onBack: () {},
          onChanged: (value) => setState(() => draft = value),
          onPersist: () {},
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const ValueKey('resumo-price-18-24')));
    await tester.pumpAndSettle();
    expect(find.text('Inserir o valor'), findsOneWidget);
    expect(tester.binding.focusManager.primaryFocus, isNotNull);
    expect(find.byKey(const ValueKey('price-entry-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('price-entry-field')),
      '10.50',
    );
    await tester.tap(find.byKey(const ValueKey('price-entry-ok')));
    await tester.pumpAndSettle();
    expect(draft.precosPorClasse['18-24'], 10.5);
    expect(find.text(r'R$ 10,50'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('resumo-price-18-24')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('price-entry-field')),
      '12,75',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(draft.precosPorClasse['18-24'], 12.75);
  });

  testWidgets('rejeita valores inválidos e não altera ao cancelar', (
    WidgetTester tester,
  ) async {
    var draft = const Romaneio(
      id: 'invalid-price',
      toras: [Tora(diametro: 20, quantidade: 1, volumeTotal: 2)],
      precosPorClasse: {'18-24': 8.25},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => ResumoScreen(
            romaneio: draft,
            onNext: () {},
            onBack: () {},
            onChanged: (value) => setState(() => draft = value),
            onPersist: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('resumo-price-18-24')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('price-entry-field'));
    await tester.enterText(field, 'abc');
    expect(tester.widget<TextField>(field).controller!.text, '8.25');
    await tester.tap(find.byKey(const ValueKey('price-entry-clear')));
    await tester.tap(find.byKey(const ValueKey('price-entry-ok')));
    await tester.pump();
    expect(
      tester.widget<TextField>(field).decoration!.errorText,
      'Informe um valor maior que zero.',
    );
    await tester.enterText(field, '0');
    await tester.tap(find.byKey(const ValueKey('price-entry-ok')));
    await tester.pump();
    await tester.enterText(field, '-1');
    await tester.tap(find.byKey(const ValueKey('price-entry-ok')));
    await tester.pump();
    expect(find.text('Inserir o valor'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(draft.precosPorClasse['18-24'], 8.25);
    expect(find.text(r'R$ 8,25'), findsOneWidget);
  });

  testWidgets('edita preço existente e recalcula totais da linha e geral', (
    WidgetTester tester,
  ) async {
    var draft = const Romaneio(
      id: 'totals',
      toras: [
        Tora(diametro: 20, quantidade: 1, volumeTotal: 2),
        Tora(diametro: 30, quantidade: 1, volumeTotal: 3),
      ],
      precosPorClasse: {'18-24': 10, '30-34': 20},
    );
    Widget app() => MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => ResumoScreen(
          romaneio: draft,
          onNext: () {},
          onBack: () {},
          onChanged: (value) => setState(() => draft = value),
          onPersist: () {},
        ),
      ),
    );
    await tester.pumpWidget(app());
    expect(find.text(r'R$ 20,00'), findsNWidgets(2));
    expect(find.text(r'R$ 60,00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resumo-price-18-24')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('price-entry-field'));
    expect(tester.widget<TextField>(field).controller!.text, '10');
    await tester.enterText(field, '15');
    await tester.tap(find.byKey(const ValueKey('price-entry-ok')));
    await tester.pumpAndSettle();
    expect(draft.precosPorClasse['18-24'], 15);
    expect(find.text(r'R$ 30,00'), findsOneWidget);
    expect(find.text(r'R$ 90,00'), findsOneWidget);
  });

  testWidgets('fotos mantém cartões, cancelamento e miniaturas por categoria', (
    WidgetTester tester,
  ) async {
    final directory = Directory('.dart_tool/fotos_test')
      ..createSync(recursive: true);
    final source = File('${directory.path}/camera.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
    var draft = const Romaneio(id: 'fotos-test');
    final camera = _FakePhotoCaptureService([
      null,
      XFile(source.path),
      XFile(source.path),
    ]);
    Widget app() => MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => FotosScreen(
          romaneio: draft,
          cameraService: camera,
          onNext: () {},
          onBack: () {},
          onChanged: (value) => setState(() => draft = value),
        ),
      ),
    );

    await tester.pumpWidget(app());
    expect(
      find.text('Traseira do caminhão carregado (aparecendo a placa)'),
      findsOneWidget,
    );
    expect(find.text('Lateral do caminhão carregado'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fotos-image-area-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fotos-thumbnail-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('fotos-image-area-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fotos-thumbnail-0')), findsOneWidget);
    expect(draft.fotos.first, isNotEmpty);
    await tester.scrollUntilVisible(
      find.text('Nota fiscal'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Nota fiscal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('fotos-next-button')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const ValueKey('fotos-next-button')));
    await tester.pump();
    expect(find.text('Tire todas as fotos obrigatórias.'), findsOneWidget);
  });

  testWidgets('balanceamento exibe um único botão Avançar e uma única seta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BalanceamentoScreen(
          romaneio: const Romaneio(
            empreiteiros: ['E1', 'E2'],
            toras: [Tora(diametro: 20, quantidade: 2, volumeTotal: 4)],
          ),
          onNext: _noop,
          onBack: _noop,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AVANÇAR'), findsOneWidget);
    expect(find.text('AVANÃ‡AR'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.contains(r'\u00C7') == true,
      ),
      findsNothing,
    );
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}

class _FakePhotoCaptureService implements PhotoCaptureService {
  _FakePhotoCaptureService(this.results);
  final List<XFile?> results;
  @override
  Future<XFile?> capture() async => results.removeAt(0);
}

class _RetryExportService extends RomaneioExportService {
  final Map<RomaneioExportFormat, int> calls = {};

  @override
  Future<RomaneioExportResult> export(
    Romaneio romaneio,
    RomaneioExportFormat format,
  ) async {
    calls[format] = (calls[format] ?? 0) + 1;
    if (format == RomaneioExportFormat.pdf && calls[format] == 1) {
      return RomaneioExportResult.failure(format, StateError('falha simulada'));
    }
    return RomaneioExportResult.success(
      format,
      File('mock_export.${format.name}'),
    );
  }
}
