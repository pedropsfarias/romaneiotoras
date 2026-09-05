part of '../main.dart';

class MasterImportScreen extends StatelessWidget {
  const MasterImportScreen({
    super.key,
    required this.isImporting,
    required this.onImport,
  });
  final bool isImporting;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      minimum: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Container(
              width: constraints.maxWidth.clamp(280.0, 460.0),
              height: constraints.maxHeight,
              margin: const EdgeInsets.fromLTRB(10, 22, 10, 0),
              decoration: BoxDecoration(
                color: const Color(0xFF004D40),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    const Text(
                      'ROMANEIO\nTORAS MIERZVA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 30),
                    FractionallySizedBox(
                      widthFactor: .64,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          key: const ValueKey('select-master-file'),
                          onPressed: isImporting ? null : onImport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF26A69A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: isImporting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'SELECIONE A PASTA DOS ARQUIVOS',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A pasta deve conter o arquivo mestre e o template.xlsx',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Spacer(flex: 5),
                    const _BrandSignature(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _BrandSignature extends StatelessWidget {
  const _BrandSignature({
    this.widthFactor = .78,
    this.showDoubleRules = false,
    this.bottomOffset = 0,
  });

  final double widthFactor;
  final bool showDoubleRules;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottomOffset),
    child: FractionallySizedBox(
      widthFactor: widthFactor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Florestal Mierzva',
              maxLines: 1,
              style: TextStyle(
                color: Colors.black.withValues(alpha: .9),
                fontSize: 22,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          if (showDoubleRules) ...[
            const SizedBox(height: 3),
            Container(
              key: const ValueKey('brand-rule-top'),
              width: double.infinity,
              height: 1,
              color: Colors.black,
            ),
            const SizedBox(height: 3),
          ],
          const Text(
            'manejo de florestas',
            style: TextStyle(
              color: Colors.black,
              fontSize: 9,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            key: const ValueKey('brand-rule-bottom'),
            width: double.infinity,
            height: 1,
            color: Colors.black,
          ),
        ],
      ),
    ),
  );
}
