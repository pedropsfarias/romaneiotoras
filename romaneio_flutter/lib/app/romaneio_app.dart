part of '../main.dart';

class RomaneioApp extends StatefulWidget {
  const RomaneioApp({super.key, this.bluetoothService});
  final BluetoothPrintService? bluetoothService;
  @override
  State<RomaneioApp> createState() => _RomaneioAppState();
}

class _RomaneioAppState extends State<RomaneioApp> {
  final _storage = RomaneioStorage();
  final _importer = MasterImportService();
  String currentScreen = 'import';
  String? selectedRomaneador;
  MasterData? master;
  String? templatePath;
  String masterFileName = 'mestre.xlsx';
  List<Romaneio> abertos = [], fechados = [];
  Romaneio? currentRomaneio;
  String? currentPdfPath;
  bool isLoading = true, isImporting = false;
  List<String> get romaneadores => master?.romaneadores ?? const [];
  List<String> get compradores => master?.compradores ?? const [];
  List<CompradorMaster> get cadastroCompradores =>
      master?.cadastroCompradores ?? const [];
  List<String> get empreiteiros => master?.empreiteiros ?? const [];
  List<String> get proprietarios => master?.proprietarios ?? const [];
  List<String> get municipios => master?.municipios ?? const [];
  List<String> get localidades => master?.localidades ?? const [];
  List<String> get carregadores => master?.carregadores ?? const [];
  List<String> get medidores => master?.medidores ?? const [];
  List<String> get motoristas => master?.motoristas ?? const [];
  List<String> get operadores => master?.operadores ?? const [];
  List<String> get placas => master?.placas ?? const [];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final loaded = await _storage.loadMasterData();
      final loadedTemplate = await _storage.loadTemplatePath();
      final loadedMasterFileName = await _storage.loadMasterFileName();
      final user = await _storage.loadSelectedRomaneador();
      final state = await _storage.loadRomaneios();
      final validUser =
          loaded != null && user != null && loaded.romaneadores.contains(user);
      if (!mounted) return;
      setState(() {
        master = loaded;
        templatePath =
            loadedTemplate != null && File(loadedTemplate).existsSync()
            ? loadedTemplate
            : null;
        masterFileName = loadedMasterFileName ?? 'mestre.xlsx';
        selectedRomaneador = validUser ? user : null;
        abertos = List.of(state?.abertos ?? const []);
        fechados = List.of(state?.fechados ?? const []);
        currentScreen = loaded == null || templatePath == null
            ? 'import'
            : validUser
            ? 'home'
            : 'login';
        isLoading = false;
      });
      if (user != null && !validUser) {
        await _storage.saveSelectedRomaneador(null);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          currentScreen = 'import';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _importMaster({bool replacing = false}) async {
    if (isImporting) return;
    if (replacing) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Atualizar arquivo mestre?'),
          content: const Text(
            'Os cadastros serão substituídos. Os romaneios existentes serão preservados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Atualizar'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => isImporting = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        allowMultiple: false,
        withData: true,
      );
      if (picked == null) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        throw const MasterImportException(
          'Não foi possível ler o arquivo selecionado.',
        );
      }
      final candidate = _importer.parse(file.bytes!, fileName: file.name);
      await _storage.saveMasterData(candidate);
      final keep =
          selectedRomaneador != null &&
          candidate.romaneadores.contains(selectedRomaneador);
      if (!keep) await _storage.saveSelectedRomaneador(null);
      if (!mounted) return;
      setState(() {
        master = candidate;
        if (!keep) selectedRomaneador = null;
        currentScreen = keep ? 'home' : 'login';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mestre “${file.name}” importado com sucesso.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is MasterImportException
                  ? e.message
                  : 'Falha ao importar o mestre: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isImporting = false);
    }
  }

  Future<void> _selectFolder() async {
    if (isImporting) return;
    setState(() => isImporting = true);
    try {
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecione a pasta dos arquivos',
      );
      if (selected == null) return;
      final directory = Directory(selected);
      if (!directory.existsSync()) {
        throw const MasterImportException(
          'A pasta selecionada não pôde ser acessada.',
        );
      }
      final files = directory.listSync().whereType<File>().toList();
      final xlsx = files.where((file) {
        final name = file.path.split(Platform.pathSeparator).last;
        return name.toLowerCase().endsWith('.xlsx') &&
            !name.startsWith('~\$') &&
            !name.toLowerCase().startsWith('romaneio_r-');
      }).toList();
      final templateFiles = xlsx
          .where(
            (file) =>
                file.path.split(Platform.pathSeparator).last.toLowerCase() ==
                'template.xlsx',
          )
          .toList();
      if (templateFiles.isEmpty) {
        throw const MasterImportException(
          'Template não encontrado\n\nA pasta selecionada precisa conter o arquivo template.xlsx.',
        );
      }
      if (templateFiles.length != 1 ||
          !_validTemplate(await templateFiles.single.readAsBytes())) {
        throw const MasterImportException(
          'Template inválido\n\nO arquivo template.xlsx não possui a estrutura necessária.',
        );
      }
      final candidates = <File>[];
      for (final file in xlsx.where((file) => !templateFiles.contains(file))) {
        try {
          _importer.parse(await file.readAsBytes(), fileName: file.path);
          candidates.add(file);
        } catch (_) {}
      }
      if (candidates.isEmpty) {
        throw MasterImportException(
          xlsx.length <= 1
              ? 'Arquivo mestre não encontrado\n\nAdicione um arquivo mestre Excel válido à pasta selecionada.'
              : 'Arquivo mestre inválido\n\nNão foi possível ler os dados obrigatórios do arquivo mestre.',
        );
      }
      if (candidates.length > 1) {
        throw const MasterImportException(
          'Mais de um arquivo mestre foi encontrado\n\nDeixe somente um arquivo mestre válido na pasta e tente novamente.',
        );
      }
      final masterFile = candidates.single;
      final parsed = _importer.parse(
        await masterFile.readAsBytes(),
        fileName: masterFile.path,
      );
      final privateDir = await getApplicationDocumentsDirectory();
      final privateTemplate = File('${privateDir.path}/template.xlsx');
      final privateMaster = File('${privateDir.path}/master.xlsx');
      await privateTemplate.writeAsBytes(
        await templateFiles.single.readAsBytes(),
        flush: true,
      );
      await privateMaster.writeAsBytes(
        await masterFile.readAsBytes(),
        flush: true,
      );
      await _storage.saveMasterData(parsed);
      await _storage.saveTemplatePath(privateTemplate.path);
      if (!mounted) return;
      setState(() {
        master = parsed;
        templatePath = privateTemplate.path;
        selectedRomaneador = null;
        currentScreen = 'login';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Arquivos carregados com sucesso\n\nMestre: ${masterFile.path.split(Platform.pathSeparator).last}\nTemplate: template.xlsx',
          ),
        ),
      );
    } on MasterImportException catch (error) {
      if (mounted) await _showImportError(error.message);
    } catch (_) {
      if (mounted)
        _showImportError('Não foi possível acessar a pasta selecionada.');
    } finally {
      if (mounted) setState(() => isImporting = false);
    }
  }

  Future<void> _selectFolderSaf() async {
    if (isImporting) return;
    setState(() => isImporting = true);
    try {
      final raw = await const MethodChannel('romaneio_flutter/files')
          .invokeMethod<List<dynamic>>('selectFolderFiles');
      if (!context.mounted || raw == null) return;
      final documents = <Map<String, dynamic>>[];
      for (final item in raw) {
        final value = Map<String, dynamic>.from(item as Map);
        final name = value['name']?.toString() ?? '';
        final bytes = value['bytes'];
        if (name.isEmpty || bytes is! List || bytes.isEmpty) continue;
        documents.add({
          'name': name,
          'bytes': Uint8List.fromList(List<int>.from(bytes)),
        });
      }
      if (documents.isEmpty) {
        throw const MasterImportException(
          'Arquivos obrigatórios não encontrados\n\nA pasta selecionada deve conter:\n• mestre.xlsx\n• template.xlsx',
        );
      }
      final templates = documents
          .where(
            (item) => item['name'].toString().toLowerCase() == 'template.xlsx',
          )
          .toList();
      if (templates.isEmpty) {
        throw const MasterImportException(
          'Template não encontrado\n\nAdicione o arquivo template.xlsx à pasta selecionada.',
        );
      }
      final template = templates.single;
      if (!_validTemplate(template['bytes'] as Uint8List)) {
        throw const MasterImportException(
          'Template inválido\n\nO template.xlsx foi encontrado, mas não pôde ser validado.',
        );
      }
      final masters = <Map<String, dynamic>>[];
      for (final item in documents) {
        if (identical(item, template)) continue;
        try {
          _importer.parse(
            item['bytes'] as Uint8List,
            fileName: item['name'].toString(),
          );
          masters.add(item);
        } catch (error, stackTrace) {
          debugPrint('Mestre rejeitado: $error\n$stackTrace');
        }
      }
      if (masters.isEmpty) {
        throw MasterImportException(
          documents.length == templates.length
              ? 'Arquivo mestre não encontrado\n\nAdicione um arquivo mestre .xlsx válido à pasta selecionada.'
              : 'Arquivo mestre inválido\n\nO arquivo foi encontrado, mas não possui a estrutura necessária.',
        );
        /*
        throw const MasterImportException(
          'Arquivo mestre inválido\n\nO arquivo foi encontrado, mas não possui a estrutura necessária.',
        ); */
      }
      int rank(String name) {
        final value = name.toLowerCase();
        return value == 'mestre.xlsx'
            ? 0
            : value.contains('mestre')
            ? 1
            : 2;
      }

      masters.sort(
        (a, b) =>
            rank(a['name'].toString()).compareTo(rank(b['name'].toString())),
      );
      if (masters.length > 1) {
        throw const MasterImportException(
          'Mais de um arquivo mestre foi encontrado\n\nDeixe somente um arquivo mestre válido na pasta e tente novamente.',
        );
      }
      final master = masters.first;
      final parsed = _importer.parse(
        master['bytes'] as Uint8List,
        fileName: master['name'].toString(),
      );
      final appDir = await getApplicationDocumentsDirectory();
      final imports = Directory(appDir.path + '/imports');
      await imports.create(recursive: true);
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final tempMaster = File(imports.path + '/.mestre_$stamp.tmp');
      final tempTemplate = File(imports.path + '/.template_$stamp.tmp');
      final localMaster = File(imports.path + '/mestre.xlsx');
      final localTemplate = File(imports.path + '/template.xlsx');
      await tempMaster.writeAsBytes(master['bytes'] as Uint8List, flush: true);
      await tempTemplate.writeAsBytes(
        template['bytes'] as Uint8List,
        flush: true,
      );
      if (!await tempMaster.exists() || !await tempTemplate.exists()) {
        throw const FileSystemException('Cópia incompleta');
      }
      if (await localMaster.exists()) await localMaster.delete();
      if (await localTemplate.exists()) await localTemplate.delete();
      await tempMaster.rename(localMaster.path);
      await tempTemplate.rename(localTemplate.path);
      await _storage.saveMasterData(parsed);
      await _storage.saveTemplatePath(localTemplate.path);
      masterFileName = master['name'].toString();
      if (!context.mounted) return;
      setState(() {
        this.master = parsed;
        templatePath = localTemplate.path;
        selectedRomaneador = null;
        currentScreen = 'login';
      });
      await _showImportSuccess(
        'Mestre: ' +
            master['name'].toString() +
            '\nTemplate: ' +
            template['name'].toString(),
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Falha SAF (' + error.code + '): ' + error.toString() + '\n$stackTrace',
      );
      if (context.mounted && error.code != 'CANCELLED') {
        await _showImportError(
          error.code == 'PERMISSION_DENIED'
              ? 'Acesso à pasta negado\n\nPermita que o aplicativo leia a pasta selecionada.'
              : 'Não foi possível carregar os arquivos\n\nO aplicativo não conseguiu ler a pasta selecionada. Tente novamente.',
        );
      }
    } on FileSystemException catch (error, stackTrace) {
      debugPrint('Falha ao copiar arquivos: $error\n$stackTrace');
      if (context.mounted) {
        await _showImportError(
          'Não foi possível carregar os arquivos\n\nO aplicativo não conseguiu ler a pasta selecionada. Tente novamente.',
        );
      }
    } on FormatException catch (error, stackTrace) {
      debugPrint('Excel inválido: $error\n$stackTrace');
      if (context.mounted)
        await _showImportError(
          'Arquivo mestre inválido\n\nO arquivo foi encontrado, mas não possui a estrutura necessária.',
        );
    } on MasterImportException catch (error, stackTrace) {
      debugPrint('Validação: ' + error.message + '\n$stackTrace');
      if (context.mounted) await _showImportError(error.message);
    } catch (error, stackTrace) {
      debugPrint('Erro inesperado: $error\n$stackTrace');
      if (context.mounted)
        await _showImportError(
          'Não foi possível carregar os arquivos\n\nO aplicativo não conseguiu ler a pasta selecionada. Tente novamente.',
        );
    } finally {
      if (mounted) setState(() => isImporting = false);
    }
  }

  Future<void> _showImportSuccess(String details) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivos carregados com sucesso'),
        content: Text(details),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _validTemplate(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((file) => file.name).toSet();
      return names.contains('xl/worksheets/sheet1.xml') &&
          names.contains('xl/styles.xml') &&
          names.any((name) => name.startsWith('xl/drawings/')) &&
          names.any((name) => name.startsWith('xl/media/')) &&
          utf8
              .decode(
                archive.findFile('xl/worksheets/sheet1.xml')!.content
                    as List<int>,
                allowMalformed: true,
              )
              .contains('dimension');
    } catch (_) {
      return false;
    }
  }

  Future<void> _showImportError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pasta inválida'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _persistState() =>
      _storage.saveRomaneios(abertos: abertos, fechados: fechados);

  Future<void> _addCadastroToMaster(String category, String value) async {
    final path = templatePath == null
        ? null
        : File(templatePath!).parent.path + '/mestre.xlsx';
    if (path == null || master == null) return;
    final sheetName = <String, String>{
      'romaneador': 'romaneadores',
      'comprador': 'compradores',
      'proprietario': 'proprietarios',
      'placa': 'placas',
      'localidade': 'localidades',
      'municipio': 'municipios',
      'operador do munk': 'carregadores',
      'medidor': 'medidores',
      'motorista': 'motoristas',
      'munk': 'munk',
      'empreiteiro(s)': 'empreiteiros',
      'placa(s)': 'placas',
    }[_normalizeCadastro(category)];
    if (sheetName == null) return;
    try {
      final original = await File(path).readAsBytes();
      final workbook = spreadsheet.Excel.decodeBytes(original);
      final actual = workbook.tables.keys.firstWhere(
        (name) => name.trim().toLowerCase() == sheetName,
        orElse: () => throw const FormatException('Aba do mestre ausente.'),
      );
      final sheet = workbook.tables[actual]!;
      final exists = List.generate(sheet.maxRows, (row) => row).any(
        (row) =>
            _normalizeCadastro(
              sheet
                      .cell(
                        spreadsheet.CellIndex.indexByColumnRow(
                          columnIndex: 0,
                          rowIndex: row,
                        ),
                      )
                      .value
                      ?.toString() ??
                  '',
            ) ==
            _normalizeCadastro(value),
      );
      if (exists) return;
      sheet.appendRow([spreadsheet.TextCellValue(value)]);
      final bytes = Uint8List.fromList(workbook.encode() ?? const []);
      _importer.parse(bytes, fileName: 'mestre.xlsx');
      final temporary = File('$path.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      await const MethodChannel('romaneio_flutter/downloads')
          .invokeMethod<void>('writeMasterFile', {
            'filename': masterFileName,
            'bytes': bytes,
          });
      if (await File(path).exists()) await File(path).delete();
      await temporary.rename(path);
      final updated = _importer.parse(bytes, fileName: master!.fileName);
      await _storage.saveMasterData(updated);
      if (mounted) setState(() => master = updated);
    } catch (error, stackTrace) {
      debugPrint('Falha ao atualizar mestre: $error\n$stackTrace');
      if (mounted) {
        await _showImportError(
          'Não foi possível atualizar o arquivo mestre.\n\nVerifique se o aplicativo possui permissão para modificar a pasta.',
        );
      }
    }
  }

  String _normalizeCadastro(String value) => value
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');
  void _goTo(String s) => setState(() => currentScreen = s);
  void _login() {
    if (master == null ||
        selectedRomaneador == null ||
        !romaneadores.contains(selectedRomaneador)) {
      setState(() => selectedRomaneador = null);
      return;
    }
    _storage.saveSelectedRomaneador(selectedRomaneador);
    _goTo('home');
  }

  void _createRomaneio() {
    if (master == null || !master!.isValid) {
      _goTo('import');
      return;
    }
    final now = DateTime.now();
    final nextNumber =
        [
          ...abertos.map((item) => item.numeroRomaneio),
          ...fechados.map((item) => item.numeroRomaneio),
        ].fold<int>(0, (max, value) => value > max ? value : max) +
        1;
    final value = Romaneio(
      id: 'R-${now.microsecondsSinceEpoch}',
      idInterno: 'R-${now.microsecondsSinceEpoch}',
      numeroRomaneio: nextNumber,
      romaneador: selectedRomaneador ?? '',
      data: now.toIso8601String().substring(0, 10),
      hora:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    setState(() {
      currentRomaneio = value;
      currentScreen = 'comprador';
    });
  }

  void _resumeRomaneio(Romaneio v) => setState(() {
    currentRomaneio = v;
    currentScreen = 'comprador';
  });

  void _advanceFromComprador() {
    final draft = currentRomaneio;
    if (draft == null || draft.comprador.trim().isEmpty) return;
    final isMasterBuyer = cadastroCompradores.any(
      (item) =>
          item.chaveOrigem == draft.compradorChaveOrigem &&
          item.nome == draft.comprador,
    );
    final isManualBuyer = draft.compradorChaveOrigem.startsWith('manual:');
    if (!isMasterBuyer && !isManualBuyer) {
      return;
    }
    setState(() {
      final index = abertos.indexWhere((item) => item.id == draft.id);
      if (index < 0) {
        abertos.add(draft);
      } else {
        abertos[index] = draft;
      }
      currentScreen = 'comprimento';
    });
    _persistState();
  }

  void _saveCurrentRomaneio() {
    if (currentRomaneio == null) return;
    final i = abertos.indexWhere((e) => e.id == currentRomaneio!.id);
    if (i >= 0) {
      setState(() => abertos[i] = currentRomaneio!);
    } else {
      final closedIndex = fechados.indexWhere(
        (item) => item.id == currentRomaneio!.id,
      );
      if (closedIndex >= 0) {
        setState(() => fechados[closedIndex] = currentRomaneio!);
      }
    }
    _persistState();
  }

  void _updateCompletedRomaneio(Romaneio v) {
    setState(() {
      currentRomaneio = v;
      final i = abertos.indexWhere((e) => e.id == v.id);
      if (i >= 0) {
        abertos[i] = v;
      } else {
        final closedIndex = fechados.indexWhere((e) => e.id == v.id);
        if (closedIndex >= 0) fechados[closedIndex] = v;
      }
      if (v.pdfPath.isNotEmpty) currentPdfPath = v.pdfPath;
    });
    _persistState();
  }

  Future<Romaneio> _finalizeCurrentRomaneio(Romaneio v) async {
    final oldA = List<Romaneio>.of(abertos),
        oldF = List<Romaneio>.of(fechados),
        saved = v.copyWith(romaneioAberto: false);
    setState(() {
      abertos.removeWhere((e) => e.id == saved.id);
      final i = fechados.indexWhere((e) => e.id == saved.id);
      i < 0 ? fechados.add(saved) : fechados[i] = saved;
      currentRomaneio = saved;
    });
    try {
      await _persistState();
      return saved;
    } catch (_) {
      if (mounted) {
        setState(() {
          abertos = oldA;
          fechados = oldF;
          currentRomaneio = v;
        });
      }
      rethrow;
    }
  }

  void _finishCompletedRomaneio() =>
      setState(() => currentScreen = 'impressao');

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Romaneio Toras Mierzva',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF004D40)),
      ),
      home: _screen(currentScreen),
    );
  }

  Widget _screen(String s) {
    if (s == 'import') {
      return MasterImportScreen(
        isImporting: isImporting,
        onImport: _selectFolderSaf,
      );
    }
    if (s == 'login') {
      return LoginScreen(
        romaneadores: romaneadores,
        selectedRomaneador: selectedRomaneador,
        onChanged: (v) => setState(() => selectedRomaneador = v),
        onLogin: _login,
        onUpdateMaster: () => _importMaster(replacing: true),
      );
    }
    if (s == 'home') {
      return HomeScreen(
        romaneador: selectedRomaneador ?? '',
        abertos: abertos,
        fechados: fechados,
        onNew: _createRomaneio,
        onOpen: _resumeRomaneio,
        onFinalizados: () => _goTo('finalizados'),
        onUpdateMaster: () => _importMaster(replacing: true),
        onLogout: () async {
          selectedRomaneador = null;
          currentScreen = 'login';
          await _storage.saveSelectedRomaneador(null);
          if (mounted) setState(() {});
        },
      );
    }
    if (s == 'finalizados') {
      return FinalizadosScreen(
        finalizados: fechados,
        onBack: () => _goTo('home'),
        onOpen: (romaneio) {
          currentRomaneio = romaneio;
          currentPdfPath = romaneio.pdfPath;
          _goTo('historicoDetalhe');
        },
      );
    }
    if (currentRomaneio == null) return _screen('home');
    switch (s) {
      case 'comprador':
        return CompradorScreen(
          romaneio: currentRomaneio!,
          compradores: cadastroCompradores,
          onChanged: (v) => setState(() => currentRomaneio = v),
          onNext: _advanceFromComprador,
          onBack: () => _goTo('home'),
          onAddCadastro: _addCadastroToMaster,
        );
      case 'dadosGerais':
        return DadosGeraisScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            if (currentRomaneio!.empreiteiros.length > 1) {
              _goTo('balanceamento');
            } else {
              final balanced = const BalanceamentoService().assignSingle(
                currentRomaneio!,
              );
              currentRomaneio = balanced;
              _goTo('fotos');
            }
          },
          onBack: () => _goTo('resumo'),
          compradores: compradores,
          empreiteiros: empreiteiros,
          proprietarios: proprietarios,
          municipios: municipios,
          localidades: localidades,
          carregadores: carregadores,
          medidores: medidores,
          motoristas: motoristas,
          operadores: operadores,
          placas: placas,
          onChanged: (v) => setState(() => currentRomaneio = v),
          onAddCadastro: _addCadastroToMaster,
        );
      case 'balanceamento':
        return BalanceamentoScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('fotos');
          },
          onBack: () => _goTo('dadosGerais'),
          onChanged: (v) => setState(() => currentRomaneio = v),
          onPersist: _persistState,
        );
      case 'fotos':
        return FotosScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('completo');
          },
          onBack: () => _goTo(
            currentRomaneio!.empreiteiros.length > 1
                ? 'balanceamento'
                : 'dadosGerais',
          ),
          onChanged: (v) => setState(() => currentRomaneio = v),
        );
      case 'comprimento':
        return ComprimentoScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            if (currentRomaneio!.comprimento > 0) _goTo('diametro');
          },
          onBack: () => _goTo('comprador'),
          onChanged: (v) => setState(() => currentRomaneio = v),
        );
      case 'diametro':
        return DiametroScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('quantidade');
          },
          onBack: () => _goTo('comprimento'),
          onChanged: (v) => setState(() => currentRomaneio = v),
          onPersist: _persistState,
        );
      case 'quantidade':
        return QuantidadeScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('resumo');
          },
          onBack: () => _goTo('diametro'),
          onChanged: (v) => setState(() => currentRomaneio = v),
          onPersist: _persistState,
        );
      case 'resumo':
        return ResumoScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('dadosGerais');
          },
          onBack: () => _goTo('quantidade'),
          onChanged: (v) => setState(() => currentRomaneio = v),
          onPersist: _persistState,
        );
      case 'completo':
        return RomaneioScreen(
          romaneio: currentRomaneio!,
          onBack: () => _goTo('resumo'),
          onFinalize: _finalizeCurrentRomaneio,
          onFinished: _finishCompletedRomaneio,
          onChanged: _updateCompletedRomaneio,
          onPdfGenerated: (path) => currentPdfPath = path,
          exportService: RomaneioExportService(templatePath: templatePath),
        );
      case 'impressao':
        return ImpressaoScreen(
          romaneio: currentRomaneio!,
          pdfPath: currentPdfPath,
          onBackToSummary: () => _goTo('resumo'),
          onFinalizados: () async {
            await _persistState();
            if (mounted) setState(() => currentScreen = 'finalizados');
          },
          bluetoothService:
              widget.bluetoothService ??
              const UnavailableBluetoothPrintService(),
        );
      case 'historicoDetalhe':
        return ImpressaoScreen(
          romaneio: currentRomaneio!,
          pdfPath: currentRomaneio!.pdfPath.isNotEmpty
              ? currentRomaneio!.pdfPath
              : currentPdfPath,
          onBackToSummary: () => _goTo('finalizados'),
          onFinalizados: () => _goTo('finalizados'),
          bluetoothService:
              widget.bluetoothService ??
              const UnavailableBluetoothPrintService(),
          showPdfMissingNotice: true,
        );
      default:
        return _screen(master == null ? 'import' : 'login');
    }
  }
}
