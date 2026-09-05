part of '../main.dart';

class QuantidadeScreen extends StatelessWidget {
  const QuantidadeScreen({
    super.key,
    required this.romaneio,
    required this.onNext,
    required this.onBack,
    required this.onChanged,
    required this.onPersist,
  });
  final Romaneio romaneio;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final ValueChanged<Romaneio> onChanged;
  final VoidCallback onPersist;

  @override
  Widget build(BuildContext context) {
    final summary = romaneio.summary();
    final totalToras = summary['numToras'] as int;
    final totalVolume = summary['volToras'] as double;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            0,
            8,
            MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    height: 58,
                    decoration: const BoxDecoration(color: Color(0xFF004D40)),
                    child: Row(
                      children: [
                        IconButton(
                          color: Colors.white,
                          icon: const Icon(Icons.arrow_back),
                          onPressed: onBack,
                        ),
                        const Text(
                          'Quantidade',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 190),
                          children: [
                            _table(romaneio),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final info = Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _summaryText(
                                        'Toras: ' + totalToras.toString(),
                                      ),
                                      const SizedBox(height: 10),
                                      _summaryText(
                                        'Volume: ' +
                                            totalVolume.toStringAsFixed(3) +
                                            ' m\u00b3',
                                      ),
                                      const SizedBox(height: 10),
                                      _summaryText(
                                        'Di\u00e2metro m\u00e9dio das toras: ' +
                                            romaneio
                                                .averageDiameter()
                                                .toStringAsFixed(2) +
                                            ' cm',
                                      ),
                                      const SizedBox(height: 10),
                                      _summaryText(
                                        'Comprimento: ' +
                                            romaneio.comprimento
                                                .toStringAsFixed(2) +
                                            ' m',
                                      ),
                                    ],
                                  ),
                                );
                                final button = ElevatedButton.icon(
                                  key: const ValueKey('quantidade-next-button'),
                                  onPressed: onNext,
                                  iconAlignment: IconAlignment.end,
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                  ),
                                  label: const Text('AVAN\u00c7AR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF26A69A),
                                    foregroundColor: Colors.white,
                                  ),
                                );
                                if (constraints.maxWidth < 330) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      info,
                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: button,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: info),
                                    const SizedBox(width: 16),
                                    button,
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 160,
                          child: IgnorePointer(
                            child: Image.asset(
                              'assets/images/floresta_rodape.png',
                              width: double.infinity,
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(Romaneio value) {
    return Column(
      children: [
        _row(const [
          'Di\u00e2m. (cm)',
          'Unid. (toras)',
          'Cub. Un. (m\u00b3)',
          'Total (m\u00b3)',
          '',
        ], header: true),
        ...value.toras.asMap().entries.map((entry) {
          final tora = entry.value;
          final total = value.volumeDaTora(tora);
          final unit = tora.quantidade == 0 ? 0 : total / tora.quantidade;
          return _row(
            [
              tora.diametro.toString(),
              tora.quantidade.toString(),
              unit.toStringAsFixed(3),
              total.toStringAsFixed(3),
              '',
            ],
            delete: () {
              onChanged(value.removeTora(tora));
              onPersist();
            },
            stripe: entry.key.isEven,
          );
        }),
      ],
    );
  }

  Widget _row(
    List<String> values, {
    bool header = false,
    bool stripe = false,
    VoidCallback? delete,
  }) {
    final cells = <Widget>[
      _cell(values[0], 0, header),
      _cell(values[1], 1, header),
      _cell(values[2], 2, header),
      _cell(values[3], 3, header),
      delete == null
          ? _cell('', 4, header)
          : IconButton(
              tooltip: 'Excluir',
              icon: const Text(
                '\u00d7',
                style: TextStyle(fontSize: 25, color: Color(0xFF222222)),
              ),
              padding: EdgeInsets.zero,
              onPressed: delete,
            ),
    ];
    return Container(
      margin: EdgeInsets.only(top: header ? 0 : 2),
      constraints: BoxConstraints(minHeight: header ? 48 : 56),
      color: header ? Colors.white : const Color(0xFFF3F3F3),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(flex: const [18, 22, 23, 27, 10][i], child: cells[i]),
        ],
      ),
    );
  }

  Widget _cell(String text, int index, bool header) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: header ? 11 : 13,
          fontWeight: header ? FontWeight.w700 : null,
        ),
      ),
    ),
  );

  Widget _summaryText(String text) => Text(
    text,
    softWrap: true,
    style: const TextStyle(
      fontSize: 13.5,
      height: 1.3,
      color: Color(0xFF222222),
    ),
  );
}
