part of '../main.dart';

class ComprimentoScreen extends StatefulWidget {
  const ComprimentoScreen({
    super.key,
    required this.romaneio,
    required this.onNext,
    required this.onBack,
    required this.onChanged,
  });

  final Romaneio romaneio;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final ValueChanged<Romaneio> onChanged;

  @override
  State<ComprimentoScreen> createState() => _ComprimentoScreenState();
}

class _ComprimentoScreenState extends State<ComprimentoScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.romaneio.comprimento > 0
          ? _formatInitialValue(widget.romaneio.comprimento)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parse(String value) {
    final normalized = _normalizeDecimalText(value);
    final parsed = double.tryParse(normalized);
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
  }

  bool get _canAdvance => _parse(_controller.text) != null;

  void _onChanged(String value) {
    widget.onChanged(widget.romaneio.copyWith(comprimento: _parse(value) ?? 0));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomSystemInset = MediaQuery.viewPaddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF000000),
        systemNavigationBarDividerColor: Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: BackButton(onPressed: widget.onBack),
          title: const Text('Comprimento'),
          backgroundColor: const Color(0xFF0B5D4C),
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomSystemInset),
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
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        footerHeight + 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: FractionallySizedBox(
                                widthFactor: .72,
                                child: const LogLengthIllustration(
                                  key: ValueKey('log-length-illustration'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Comprimento:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextField(
                            key: const ValueKey('comprimento-field'),
                            controller: _controller,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: const [_DecimalInputFormatter()],
                            onChanged: _onChanged,
                            decoration: const InputDecoration(
                              hintText: 'Comprimento (m)',
                              hintStyle: TextStyle(color: Color(0xFF757575)),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFFBDBDBD),
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFF26A69A),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Exemplo: 1,23 ou 1.23',
                            style: TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                key: const ValueKey('comprimento-next-button'),
                                onPressed: _canAdvance ? widget.onNext : null,
                                iconAlignment: IconAlignment.end,
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                label: const Text('AVANÇAR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF26A69A),
                                  disabledBackgroundColor: const Color(
                                    0xFFD6D6D6,
                                  ),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: const Color(
                                    0xFF757575,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                              ),
                            ),
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
                          key: const ValueKey('comprimento-forest-footer'),
                          height: footerHeight,
                          child: Image.asset(
                            'assets/images/floresta_rodape.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DecimalInputFormatter extends TextInputFormatter {
  const _DecimalInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return RegExp(r'^\d*([.,]\d*)?$').hasMatch(newValue.text)
        ? newValue
        : oldValue;
  }
}

String _normalizeDecimalText(String value) => value.trim().replaceAll(',', '.');

class LogLengthIllustration extends StatelessWidget {
  const LogLengthIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // Preserve the space previously reserved above the square image for the
      // indicator while keeping the image and arrow in one coordinate system.
      aspectRatio: 230 / 272,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize = constraints.maxWidth;
          final arrowLength = imageSize * .72;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    'assets/images/wooden_log.png',
                    key: const ValueKey('wooden-log-image'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Transform.translate(
                // The asset's log axis is approximately -29 degrees. This
                // offset moves the measure line to the upper side of the log.
                offset: Offset(-imageSize * .062, -imageSize * .01),
                child: Transform.rotate(
                  angle: -0.5,
                  child: SizedBox(
                    width: arrowLength,
                    height: 24,
                    child: const CustomPaint(painter: DoubleArrowPainter()),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DoubleArrowPainter extends CustomPainter {
  const DoubleArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0B5D4C)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final start = Offset(8, size.height / 2);
    final end = Offset(size.width - 8, size.height / 2);
    canvas.drawLine(start, end, paint);
    _drawTip(canvas, start, end, paint);
    _drawTip(canvas, end, start, paint);
  }

  void _drawTip(Canvas canvas, Offset tip, Offset toward, Paint paint) {
    final direction = (toward - tip) / (toward - tip).distance;
    final perpendicular = Offset(-direction.dy, direction.dx);
    final base = tip + direction * 8;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + perpendicular * 4).dx, (base + perpendicular * 4).dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base - perpendicular * 4).dx, (base - perpendicular * 4).dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatInitialValue(double value) {
  final text = value.toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
