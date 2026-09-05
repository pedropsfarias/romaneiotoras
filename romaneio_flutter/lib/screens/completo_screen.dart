part of '../main.dart';

class CompletoScreen extends StatefulWidget {
  const CompletoScreen({
    super.key,
    required this.romaneio,
    required this.onBack,
    required this.onFinalize,
    required this.onFinished,
    required this.onChanged,
    this.exportService,
  });

  final Romaneio romaneio;
  final VoidCallback onBack;
  final Future<Romaneio> Function(Romaneio romaneio) onFinalize;
  final VoidCallback onFinished;
  final ValueChanged<Romaneio> onChanged;
  final RomaneioExportService? exportService;

  @override
  State<CompletoScreen> createState() => _CompletoScreenState();
}

class _CompletoScreenState extends State<CompletoScreen> {
  late final TextEditingController _observacoesController;
  late final RomaneioExportService _exportService;
  late List<String> _fotos;
  bool _isWorking = false;
  Romaneio? _savedRomaneio;
  Object? _saveError;
  final Map<RomaneioExportFormat, RomaneioExportResult> _exportResults = {};

  @override
  void initState() {
    super.initState();
    _exportService = widget.exportService ?? RomaneioExportService();
    _observacoesController = TextEditingController(
      text: widget.romaneio.observacoes,
    );
    _fotos = List<String>.from(widget.romaneio.fotos);
    while (_fotos.length < 3) {
      _fotos.add('');
    }
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  Romaneio _currentRomaneio() => widget.romaneio.copyWith(
    observacoes: _observacoesController.text,
    fotos: List<String>.from(_fotos),
  );

  Future<void> _capturePhoto(int index) async {
    final result = await ImagePicker().pickImage(source: ImageSource.camera);
    if (result == null) return;
    final photosDirectory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/romaneio_photos',
    );
    await photosDirectory.create(recursive: true);
    final separator = result.name.lastIndexOf('.');
    final extension = separator >= 0
        ? result.name.substring(separator)
        : '.jpg';
    final safeId = widget.romaneio.id.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final savedPhoto = await File(result.path).copy(
      '${photosDirectory.path}/${safeId}_foto_${index + 1}_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    if (!mounted) return;
    setState(() => _fotos[index] = savedPhoto.path);
    widget.onChanged(_currentRomaneio());
  }

  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await _exportService.export(
      _savedRomaneio ?? _currentRomaneio(),
      RomaneioExportFormat.pdf,
    );
    if (!mounted) return;
    if (!result.succeeded) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Falha ao exportar PDF: ${result.error}')),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        text: 'Romaneio exportado',
        files: [XFile(result.file!.path)],
      ),
    );
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(content: Text('PDF disponível em ${result.file!.path}')),
    );
  }

  Future<void> _printPdf() async {
    final bytes = await _exportService.generatePdf(
      _savedRomaneio ?? _currentRomaneio(),
    );
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  Future<void> _finalizeAndExport() async {
    if (_isWorking || _savedRomaneio != null) return;
    setState(() {
      _isWorking = true;
      _saveError = null;
      _exportResults.clear();
    });
    try {
      final draft = _currentRomaneio();
      final batch = await _exportService.exportAll(
        draft,
        formats: const {RomaneioExportFormat.xlsx},
      );
      if (!batch.allSucceeded) {
        throw StateError('Não foi possível gerar um Excel válido.');
      }
      final saved = await widget.onFinalize(draft);
      if (!mounted) return;
      setState(() => _savedRomaneio = saved);
      setState(() => _exportResults.addAll(batch.results));
    } catch (error) {
      if (mounted) setState(() => _saveError = error);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _exportFormats(Set<RomaneioExportFormat> formats) async {
    final saved = _savedRomaneio;
    if (saved == null || formats.isEmpty) return;
    final batch = await _exportService.exportAll(saved, formats: formats);
    if (mounted) setState(() => _exportResults.addAll(batch.results));
  }

  Future<void> _retryFailedExports() async {
    if (_isWorking || _savedRomaneio == null) return;
    final failed = const {RomaneioExportFormat.xlsx}
        .where((format) => !(_exportResults[format]?.succeeded ?? false))
        .toSet();
    setState(() => _isWorking = true);
    try {
      await _exportFormats(failed);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.romaneio.summary();
    final editingEnabled = !_isWorking && _savedRomaneio == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completo'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Romaneador: ${widget.romaneio.romaneador}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Comprador: ${widget.romaneio.comprador}'),
            Text('Empreiteiro: ${widget.romaneio.empreiteiros.join(', ')}'),
            Text('Proprietário: ${widget.romaneio.proprietario}'),
            Text(
              'Localidade: ${widget.romaneio.localidade} / ${widget.romaneio.municipio}',
            ),
            Text(
              'Data: ${widget.romaneio.data} · Hora: ${widget.romaneio.hora}',
            ),
            const SizedBox(height: 14),
            Text('Quantidade total: ${summary['numToras']}'),
            Text(
              'Volume total: ${(summary['volToras'] as double).toStringAsFixed(3)} m³',
            ),
            Text(
              'Preço estimado: R\$ ${widget.romaneio.totalPrice().toStringAsFixed(2)}',
            ),
            const SizedBox(height: 18),
            const Text(
              'Observações',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextField(
              controller: _observacoesController,
              enabled: editingEnabled,
              onChanged: (_) => widget.onChanged(_currentRomaneio()),
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 18),
            const Text(
              'Fotos do romaneio',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(3, (index) {
                final exists =
                    _fotos[index].isNotEmpty &&
                    File(_fotos[index]).existsSync();
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    child: InkWell(
                      key: ValueKey('romaneio-photo-slot-$index'),
                      onTap: editingEnabled ? () => _capturePhoto(index) : null,
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                        ),
                        child: exists
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_fotos[index]),
                                  key: ValueKey('romaneio-photo-$index'),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 32,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            if (_isWorking) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                _savedRomaneio == null
                    ? 'Salvando romaneio...'
                    : 'Gerando Excel...',
              ),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 16),
              Text(
                'Falha ao salvar o romaneio: $_saveError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_savedRomaneio != null) ...[
              const SizedBox(height: 16),
              const Text('Romaneio salvo com sucesso.'),
              for (final format in const [RomaneioExportFormat.xlsx])
                _ExportStatusLine(
                  format: format,
                  result: _exportResults[format],
                  isWorking: _isWorking,
                ),
              if (!_isWorking &&
                  _exportResults.values.any((result) => !result.succeeded))
                TextButton.icon(
                  onPressed: _retryFailedExports,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar exportações novamente'),
                ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: editingEnabled ? widget.onBack : null,
                  child: const Text('Voltar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isWorking
                      ? null
                      : _savedRomaneio == null
                      ? _finalizeAndExport
                      : widget.onFinished,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B5D4C),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _savedRomaneio == null ? 'Finalizar' : 'Concluir',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportStatusLine extends StatelessWidget {
  const _ExportStatusLine({
    required this.format,
    required this.result,
    required this.isWorking,
  });

  final RomaneioExportFormat format;
  final RomaneioExportResult? result;
  final bool isWorking;

  @override
  Widget build(BuildContext context) {
    final label = format.name.toUpperCase();
    if (result == null) {
      return Text('$label: ${isWorking ? 'gerando...' : 'não gerado'}');
    }
    if (result!.succeeded) {
      return SelectableText('$label disponível em: ${result!.file!.path}');
    }
    return Text(
      '$label: falha na exportação (${result!.error})',
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
