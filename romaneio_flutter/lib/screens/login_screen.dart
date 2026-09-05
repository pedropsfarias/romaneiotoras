part of '../main.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.romaneadores,
    required this.selectedRomaneador,
    required this.onChanged,
    required this.onLogin,
    this.onUpdateMaster,
  });

  final List<String> romaneadores;
  final String? selectedRomaneador;
  final ValueChanged<String?> onChanged;
  final VoidCallback onLogin;
  final VoidCallback? onUpdateMaster;

  @override
  Widget build(BuildContext context) {
    final canLogin =
        selectedRomaneador != null && romaneadores.contains(selectedRomaneador);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 6),
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: Container(
              width: constraints.maxWidth.clamp(280.0, 460.0),
              height: constraints.maxHeight,
              margin: const EdgeInsets.fromLTRB(10, 22, 10, 0),
              decoration: BoxDecoration(
                color: const Color(0xFF004D40),
                borderRadius: BorderRadius.circular(40),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 76,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
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
                        const SizedBox(height: 28),
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6EEEC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: canLogin ? selectedRomaneador : null,
                              hint: const Text('Selecione o Romaneador'),
                              dropdownColor: const Color(0xFFE6EEEC),
                              style: const TextStyle(
                                color: Color(0xFF1C2927),
                                fontSize: 16,
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFF1C2927),
                              ),
                              items: romaneadores
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                              onChanged: onChanged,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 124,
                            height: 44,
                            child: ElevatedButton(
                              key: const ValueKey('login-button'),
                              onPressed: canLogin ? onLogin : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26A69A),
                                disabledBackgroundColor: const Color(
                                  0xFFD6D6D6,
                                ),
                                foregroundColor: const Color(0xFFFFFFFF),
                                disabledForegroundColor: const Color(
                                  0xFF757575,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'ENTRAR',
                                    style: TextStyle(
                                      color: canLogin
                                          ? const Color(0xFFFFFFFF)
                                          : const Color(0xFF757575),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                    color: canLogin
                                        ? const Color(0xFFFFFFFF)
                                        : const Color(0xFF757575),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 20),
                        const _BrandSignature(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
