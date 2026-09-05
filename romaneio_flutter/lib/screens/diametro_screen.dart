part of '../main.dart';

class DiametroScreen extends StatefulWidget {
  const DiametroScreen({
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
  State<DiametroScreen> createState() => _DiametroScreenState();
}

class _DiametroScreenState extends State<DiametroScreen> {
  final TextEditingController _customController = TextEditingController();
  String? _customError;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addTora(int diametro) {
    widget.onChanged(widget.romaneio.addTora(diametro, 1));
    widget.onPersist();
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Adicionado 1x di\u00E2metro $diametro',
            style: const TextStyle(color: Colors.black87),
          ),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFF4F4F4),
        ),
      );
  }

  void _advance() {
    if (widget.romaneio.toras.isEmpty) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Adicione ao menos um di\u00E2metro antes de avan\u00E7ar.',
              style: TextStyle(color: Colors.black87),
            ),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    widget.onNext();
  }

  void _addCustomTora() {
    final value = int.tryParse(_customController.text.trim());
    if (value == null || value <= 52) {
      setState(() => _customError = 'Informe um di\u00E2metro maior que 52.');
      return;
    }
    _addTora(value);
    _customController.clear();
    setState(() => _customError = null);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.romaneio.summary();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final volume = (summary['volToras'] as double).toStringAsFixed(3);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Di\u00E2metro'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ColoredBox(
          color: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const forestAspectRatio = 1774 / 887;
              final footerHeight = constraints.maxWidth / forestAspectRatio;
              return Stack(
                fit: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(18, 12, 18, footerHeight + 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TORAS: ' + summary['numToras'].toString(),
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'VOLUME: ' + volume + 'm\u00B3',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const DiameterLogIllustration(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selecione o di\u00E2metro sem a casca:',
                          style: TextStyle(fontSize: 15, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 38,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 10,
                                childAspectRatio: 2.1,
                              ),
                          itemBuilder: (context, index) {
                            final value = 15 + index;
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26A69A),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () => _addTora(value),
                              child: Text(
                                '$value',
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Se maior que 52:',
                          style: TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('diametro-custom-field'),
                                controller: _customController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) {
                                  if (_customError != null) {
                                    setState(() => _customError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Di\u00E2metro',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  errorText: _customError,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              key: const ValueKey('diametro-add-custom-button'),
                              onPressed: _addCustomTora,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26A69A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(48, 48),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        if (widget.romaneio.toras.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '\u00DAltimas toras inseridas',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton.icon(
                                key: const ValueKey('diametro-undo-last'),
                                onPressed: () {
                                  widget.onChanged(
                                    widget.romaneio.removeTora(
                                      widget.romaneio.toras.last,
                                    ),
                                  );
                                  widget.onPersist();
                                },
                                icon: const Icon(Icons.undo, size: 18),
                                label: const Text('Desfazer \u00FAltima'),
                              ),
                            ],
                          ),
                          ...widget.romaneio.toras
                              .take(5)
                              .map(
                                (tora) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Di\u00E2metro ' + tora.diametro.toString(),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      widget.onChanged(
                                        widget.romaneio.removeTora(tora),
                                      );
                                      widget.onPersist();
                                    },
                                  ),
                                ),
                              ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: widget.onBack,
                              child: const Text('Voltar'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              key: const ValueKey('diametro-next-button'),
                              onPressed: _advance,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26A69A),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Avan\u00E7ar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: SizedBox(
                        height: footerHeight,
                        child: const ForestFooter(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class DiameterLogIllustration extends StatelessWidget {
  const DiameterLogIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            child: Image.asset(
              'assets/images/front_log.png',
              key: const ValueKey('front-log-image'),
              width: 88,
              height: 88,
              fit: BoxFit.contain,
            ),
          ),
          const Positioned(
            top: 43,
            child: CustomPaint(
              // A largura visível do tronco fica entre as guias, sem incluir
              // as margens transparentes do PNG.
              size: Size(70, 55),
              painter: DiameterMeasurementPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class DiameterMeasurementPainter extends CustomPainter {
  const DiameterMeasurementPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const y = 54.0;
    final centerX = size.width / 2;
    final visibleWoodDiameter = size.width;
    final left = centerX - visibleWoodDiameter / 2;
    final right = centerX + visibleWoodDiameter / 2;
    final guide = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final green = Paint()
      ..color = Colors.green.shade700
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(left, 0), Offset(left, y), guide);
    canvas.drawLine(Offset(right, 0), Offset(right, y), guide);
    canvas.drawLine(Offset(left, y), Offset(right, y), green);
    canvas.drawLine(Offset(left, y), Offset(left + 7, y - 4), green);
    canvas.drawLine(Offset(left, y), Offset(left + 7, y + 4), green);
    canvas.drawLine(Offset(right, y), Offset(right - 7, y - 4), green);
    canvas.drawLine(Offset(right, y), Offset(right - 7, y + 4), green);
  }

  @override
  bool shouldRepaint(covariant DiameterMeasurementPainter oldDelegate) => false;
}
