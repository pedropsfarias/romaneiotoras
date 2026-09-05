part of '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.romaneador,
    required this.abertos,
    required this.fechados,
    required this.onNew,
    required this.onOpen,
    this.onFinalizados,
    required this.onLogout,
    this.onUpdateMaster,
  });

  final String romaneador;
  final List<Romaneio> abertos;
  final List<Romaneio> fechados;
  final VoidCallback onNew;
  final ValueChanged<Romaneio> onOpen;
  final VoidCallback? onFinalizados;
  final VoidCallback onLogout;
  final VoidCallback? onUpdateMaster;

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
        appBar: AppBar(
          title: const Text('Romaneio Toras Mierzva'),
          backgroundColor: const Color(0xFF0B5D4C),
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: onLogout),
          ],
        ),
        backgroundColor: const Color(0xFF000000),
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomSystemInset),
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const forestAspectRatio = 1774 / 887;
                final footerHeight = constraints.maxWidth / forestAspectRatio;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Romaneador(a): $romaneador',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: onNew,
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                  label: const Text(
                                    'NOVO',
                                    style: TextStyle(color: Color(0xFFFFFFFF)),
                                  ),
                                  style: _primaryButtonStyle(
                                    backgroundColor: const Color(0xFF009688),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (abertos.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => onOpen(abertos.last),
                                    icon: const Icon(Icons.edit_note_outlined),
                                    label: const Text('Em andamento'),
                                    style: _primaryButtonStyle(),
                                  ),
                                ),
                              if (fechados.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        onFinalizados ??
                                        () => onOpen(fechados.last),
                                    icon: const Icon(Icons.archive_outlined),
                                    label: const Text('Finalizados'),
                                    style: _primaryButtonStyle(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: SizedBox(
                          key: const ValueKey('home-forest-footer'),
                          width: double.infinity,
                          height: footerHeight,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/floresta_rodape.png',
                                  key: const ValueKey('home-forest-image'),
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                ),
                              ),
                              const _BrandSignature(
                                widthFactor: .52,
                                showDoubleRules: true,
                                bottomOffset: 14,
                              ),
                            ],
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

  ButtonStyle _primaryButtonStyle({
    Color backgroundColor = const Color(0xFF0B5D4C),
  }) => ElevatedButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
