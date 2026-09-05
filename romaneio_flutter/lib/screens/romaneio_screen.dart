part of '../main.dart';

class RomaneioScreen extends StatefulWidget {
  const RomaneioScreen({
    super.key,
    required this.romaneio,
    required this.onBack,
    required this.onFinalize,
    required this.onFinished,
    required this.onChanged,
    this.onPdfGenerated,
    this.showFinalize = true,
    this.footerBuilder,
    this.exportService,
  });

  final Romaneio romaneio;
  final VoidCallback onBack, onFinished;
  final Future<Romaneio> Function(Romaneio) onFinalize;
  final ValueChanged<Romaneio> onChanged;
  final ValueChanged<String>? onPdfGenerated;
  final bool showFinalize;
  final Widget Function(BuildContext context)? footerBuilder;
  final RomaneioExportService? exportService;

  @override
  State<RomaneioScreen> createState() => _RomaneioScreenState();
}

class _RomaneioScreenState extends State<RomaneioScreen> {
  static const _balanceamento = BalanceamentoService();
  late final RomaneioExportService _exportService;
  final _scroll = ScrollController();
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _exportService = widget.exportService ?? RomaneioExportService();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _money(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'R\$ $grouped,${parts[1]}';
  }

  String _display(String value) => value.trim().isEmpty ? '-' : value.trim();

  String _balanceText(BalanceamentoRow row) =>
      widget.romaneio.tipoBalanceamento == TipoBalanceamento.metroCubico
      ? '${row.empreiteiro} → ${row.volume.toStringAsFixed(3)} m${String.fromCharCode(0xB3)}'
      : '${row.empreiteiro} → ${row.quantidade} ${row.quantidade == 1 ? 'tora' : 'toras'}';

  String _balanceTextSafe(BalanceamentoRow row) {
    final arrow = String.fromCharCode(0x2192);
    if (widget.romaneio.tipoBalanceamento == TipoBalanceamento.metroCubico) {
      return '${row.empreiteiro} $arrow ${row.volume.toStringAsFixed(3)} m${String.fromCharCode(0xB3)}';
    }
    return '${row.empreiteiro} $arrow ${row.quantidade} ${row.quantidade == 1 ? 'tora' : 'toras'}';
  }

  Future<void> _finalize() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final exported = await _exportService.exportAll(
        widget.romaneio,
        formats: const {RomaneioExportFormat.xlsx},
      );
      if (!exported.allSucceeded) {
        throw StateError('Não foi possível gerar um Excel válido.');
      }
      final saved = await widget.onFinalize(
        widget.romaneio.copyWith(finalizadoEm: DateTime.now()),
      );
      if (!mounted) return;
      widget.onChanged(saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Excel salvo em Downloads:\nromaneio_R-${saved.numeroRomaneio}.xlsx',
            ),
          ),
        );
      }
      widget.onFinished();
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Falha ao finalizar o romaneio: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              Container(
                height: 48,
                color: const Color(0xFF004D40),
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    ),
                    const Text(
                      'Romaneio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 170,
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/images/floresta_rodape_transparente.png',
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 18),
                      child: _content(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _content() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Image.asset(
          'assets/images/logo_florestal_mierzva_transparente.png',
          key: const ValueKey('romaneio-florestal-logo'),
          width: 190,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'FLORESTAL MIERZVA - Manejo de Florestas',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Mallet - PR',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.35),
      ),
      const SizedBox(height: 10),
      const Text(
        'Leon Lucas Mierzva – (42) 99916-7040',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.35),
      ),
      const SizedBox(height: 10),
      const Text(
        'Leonel Mierzva – (42) 99914-0527',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.35),
      ),
      const SizedBox(height: 30),
      _sectionTitle('Romaneio de Tora'),
      _line(
        'Nº',
        widget.romaneio.numeroRomaneio > 0
            ? '${widget.romaneio.numeroRomaneio}'
            : '-',
      ),
      _line('Romaneador', _display(widget.romaneio.romaneador)),
      const SizedBox(height: 28),
      _sectionTitle('Dados Gerais'),
      _generalData(),
      const SizedBox(height: 28),
      _sectionTitle('Toras'),
      _logsTable(),
      const SizedBox(height: 24),
      _priceTable(),
      const SizedBox(height: 16),
      _readOnlyOptions(),
      const SizedBox(height: 28),
      _photosSection(),
      const SizedBox(height: 28),
      _sectionTitle('Balanceamento'),
      _line(
        'Tipo',
        widget.romaneio.tipoBalanceamento == TipoBalanceamento.metroCubico
            ? 'Por metro cúbico'
            : 'Por número de toras',
      ),
      ..._balanceRows(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      const SizedBox(height: 18),
      if (widget.showFinalize)
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            key: const ValueKey('romaneio-finalize-button'),
            onPressed: _working ? null : _finalize,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(_working ? 'SALVANDO...' : 'FINALIZAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF26A69A),
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 38),
              elevation: 3,
            ),
          ),
        ),
      if (widget.footerBuilder != null) widget.footerBuilder!(context),
      SizedBox(height: 155),
    ],
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _generalData() {
    final r = widget.romaneio;
    final lines = <Widget>[
      _line('Comprador', _display(r.comprador)),
      _line('Proprietário', _display(r.proprietario)),
      for (final name in r.empreiteiros) _line('Empreiteiro', _display(name)),
      _line('Localidade', _display(r.localidade)),
      _line('Município', _display(r.municipio)),
      _line('Data', _display(r.data)),
      _line('Hora', _display(r.hora)),
      _line('Munk', _display(r.operador)),
      _line('Operador do Munk', _display(r.carregador)),
      _line('Medidor', _display(r.medidor)),
      _line('Motorista', _display(r.motorista)),
      for (var i = 0; i < r.placas.length; i++)
        _line(
          i == 0 ? 'Placa do Caminhão' : '${i + 1}ª Placa',
          _display(r.placas[i]),
        ),
      _line('Observações', _display(r.observacoes)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }

  Widget _logsTable() {
    final r = widget.romaneio;
    final total = r.summary()['volToras'] as double;
    final rows = <Widget>[
      _tableHeader(const [
        'Diâm. (cm)',
        'Unid.\n(toras)',
        'Cub. Un.\n(m³)',
        'Total\n(m³)',
      ]),
    ];
    for (var i = 0; i < r.toras.length; i++) {
      final tora = r.toras[i];
      final volume = r.volumeDaTora(tora);
      rows.add(
        _tableRow([
          '${tora.diametro}',
          '${tora.quantidade}',
          (volume / tora.quantidade).toStringAsFixed(3),
          volume.toStringAsFixed(3),
        ], i.isEven),
      );
    }
    rows.add(
      _tableRow(
        ['TOTAL', '${r.summary()['numToras']}', '-', total.toStringAsFixed(3)],
        false,
        total: true,
      ),
    );
    return Column(children: rows);
  }

  Widget _priceTable() {
    final grouped = <String, List<Tora>>{};
    for (final tora in widget.romaneio.toras)
      grouped
          .putIfAbsent(Romaneio.priceClassForDiameter(tora.diametro), () => [])
          .add(tora);
    final rows = <Widget>[
      _tableHeader(const [
        'Classe Diamétrica\n(cm)',
        'Quant.\n(toras)',
        'Volume\n(m³)',
        'Preço Unitário\n(R\$)',
        'Valor Total\n(R\$)',
      ], price: true),
    ];
    var totalVolume = 0.0, totalValue = 0.0, totalQuantity = 0;
    for (final key in Romaneio.priceClassKeys) {
      final items = grouped[key] ?? const <Tora>[];
      final quantity = items.fold(0, (sum, tora) => sum + tora.quantidade);
      final volume = items.fold(
        0.0,
        (sum, tora) => sum + widget.romaneio.volumeDaTora(tora),
      );
      final price = widget.romaneio.precosPorClasse[key];
      final value = price == null ? 0.0 : volume * price;
      totalQuantity += quantity;
      totalVolume += volume;
      totalValue += value;
      rows.add(
        _tableRow(
          [
            key.replaceAll('-', '–'),
            quantity == 0 ? '-' : '$quantity',
            volume == 0 ? '-' : volume.toStringAsFixed(3),
            price == null ? '-' : _money(price),
            value == 0 ? '-' : _money(value),
          ],
          key.hashCode.isEven,
          price: true,
        ),
      );
    }
    rows.add(
      _tableRow(
        [
          'TOTAL',
          '$totalQuantity',
          totalVolume.toStringAsFixed(3),
          '-',
          totalValue == 0 ? '-' : _money(totalValue),
        ],
        false,
        total: true,
        price: true,
      ),
    );
    return Column(children: rows);
  }

  Widget _tableHeader(List<String> values, {bool price = false}) =>
      _tableRow(values, false, header: true, price: price);

  Widget _tableRow(
    List<String> values,
    bool stripe, {
    bool header = false,
    bool total = false,
    bool price = false,
  }) => Container(
    constraints: BoxConstraints(minHeight: header ? 50 : 50),
    color: Colors.white,
    child: Row(
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            flex: price
                ? const [21, 17, 16, 24, 22][i]
                : const [22, 24, 24, 30][i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
              child: Text(
                values[i],
                maxLines: 3,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: header || total ? FontWeight.bold : null,
                  height: 1.35,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _readOnlyOptions() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _check('Com nó', widget.romaneio.comNo),
            _check('Do pé', widget.romaneio.doPe),
            _check('2ª Tora', widget.romaneio.segundaTora),
          ],
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _line('Total de toras', '${widget.romaneio.summary()['numToras']}'),
            _line(
              'Volume total',
              '${(widget.romaneio.summary()['volToras'] as double).toStringAsFixed(3)} m³',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _check(String label, bool value) => Row(
    children: [
      Checkbox(value: value, onChanged: null),
      Flexible(child: Text(label, style: const TextStyle(fontSize: 14))),
    ],
  );

  Widget _photosSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Fotos'),
      for (var i = 0; i < widget.romaneio.fotos.length && i < 3; i++)
        if (widget.romaneio.fotos[i].isNotEmpty &&
            File(widget.romaneio.fotos[i]).existsSync())
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(widget.romaneio.fotos[i]),
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                key: ValueKey('romaneio-summary-photo-$i'),
              ),
            ),
          ),
    ],
  );

  List<Widget> _balanceRows() {
    final rows = _balanceamento.rows(widget.romaneio);
    if (rows.isEmpty) return [const Text('-')];
    return [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Text(_balanceTextSafe(row)),
          /* Text(
            '${row.empreiteiro} → '
            '${widget.romaneio.tipoBalanceamento == TipoBalanceamento.metroCubico ? '-' : '${row.quantidade} toras'} → '
            '${row.informado ? row.volume.toStringAsFixed(3) : '-'} m³',
            style: const TextStyle(fontSize: 14),
          ), */
        ),
    ];
  }
}
