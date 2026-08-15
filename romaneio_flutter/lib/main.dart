import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const RomaneioApp());
}

class RomaneioApp extends StatefulWidget {
  const RomaneioApp({super.key});

  @override
  State<RomaneioApp> createState() => _RomaneioAppState();
}

class _RomaneioAppState extends State<RomaneioApp> {
  String currentScreen = 'login';
  String? selectedRomaneador;
  final List<String> romaneadores = const [
    'João',
    'Maria',
    'Carlos',
    'Ana',
    'Pedro',
  ];
  final List<String> compradores = const ['Comprador A', 'Comprador B', 'Novo comprador'];
  final List<String> empreiteiros = const ['Empreiteiro A', 'Empreiteiro B'];
  final List<String> proprietarios = const ['Proprietário A', 'Proprietário B'];
  final List<String> municipios = const ['Municipio A', 'Municipio B'];
  final List<String> localidades = const ['Localidade A', 'Localidade B'];
  final List<String> carregadores = const ['Operador Munk A', 'Operador Munk B'];
  final List<String> medidores = const ['Medidor A', 'Medidor B'];
  final List<String> motoristas = const ['Motorista A', 'Motorista B'];
  final List<String> operadores = const ['Munk A', 'Munk B'];
  final List<String> placas = const ['ABC-1234', 'XYZ-5678'];

  List<Romaneio> abertos = [];
  List<Romaneio> fechados = [];
  Romaneio? currentRomaneio;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('romaneio_flutter_state');
    final cachedRomaneador = prefs.getString('romaneio_selected_romaneador');

    if (!mounted) return;

    if (cachedRomaneador != null && cachedRomaneador.trim().isNotEmpty) {
      selectedRomaneador = cachedRomaneador;
      currentScreen = 'home';
    }

    if (raw == null || raw.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final abertosList = (decoded['abertos'] as List? ?? const [])
          .map((item) => Romaneio.fromJson(item as Map<String, dynamic>))
          .toList();
      final fechadosList = (decoded['fechados'] as List? ?? const [])
          .map((item) => Romaneio.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        abertos = abertosList;
        fechados = fechadosList;
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'abertos': abertos.map((item) => item.toJson()).toList(),
      'fechados': fechados.map((item) => item.toJson()).toList(),
    };
    await prefs.setString('romaneio_flutter_state', jsonEncode(payload));
  }

  Future<void> _persistSelectedRomaneador() async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedRomaneador == null || selectedRomaneador!.trim().isEmpty) {
      await prefs.remove('romaneio_selected_romaneador');
      return;
    }
    await prefs.setString('romaneio_selected_romaneador', selectedRomaneador!);
  }

  void _goTo(String screen) {
    setState(() => currentScreen = screen);
  }

  void _login() {
    if (selectedRomaneador == null || selectedRomaneador!.trim().isEmpty) {
      return;
    }
    _persistSelectedRomaneador();
    setState(() => currentScreen = 'home');
  }

  void _createRomaneio() {
    final now = DateTime.now();
    final newRomaneio = Romaneio(
      id: 'R-${now.microsecondsSinceEpoch}',
      romaneador: selectedRomaneador ?? 'Romaneador',
      comprador: compradores.first,
      empreiteiros: [empreiteiros.first],
      proprietario: proprietarios.first,
      placas: [placas.first],
      localidade: localidades.first,
      municipio: municipios.first,
      data: now.toIso8601String().substring(0, 10),
      hora: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      carregador: carregadores.first,
      medidor: medidores.first,
      motorista: motoristas.first,
      operador: operadores.first,
      observacoes: '',
      comprimento: 0,
      toras: const [],
    );

    setState(() {
      currentRomaneio = newRomaneio;
      abertos.add(newRomaneio);
      currentScreen = 'comprador';
    });
    _persistState();
  }

  void _resumeRomaneio(Romaneio romaneio) {
    setState(() {
      currentRomaneio = romaneio;
      currentScreen = 'comprador';
    });
  }

  void _saveCurrentRomaneio() {
    if (currentRomaneio == null) return;
    setState(() {
      final index = abertos.indexWhere((item) => item.id == currentRomaneio!.id);
      if (index >= 0) {
        abertos[index] = currentRomaneio!;
      }
    });
    _persistState();
  }

  void _finalizeCurrentRomaneio() {
    if (currentRomaneio == null) return;
    setState(() {
      final index = abertos.indexWhere((item) => item.id == currentRomaneio!.id);
      if (index >= 0) {
        abertos.removeAt(index);
      }
      fechados.add(currentRomaneio!.copyWith(romaneioAberto: false));
      currentRomaneio = null;
      currentScreen = 'home';
    });
    _persistState();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    return MaterialApp(
      title: 'Romaneio de Toras',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5D4C)),
        scaffoldBackgroundColor: const Color(0xFFF5F8F7),
      ),
      home: _buildScreen(currentScreen),
    );
  }

  Widget _buildScreen(String screen) {
    switch (screen) {
      case 'login':
        return LoginScreen(
          romaneadores: romaneadores,
          selectedRomaneador: selectedRomaneador,
          onChanged: (value) => setState(() => selectedRomaneador = value),
          onLogin: _login,
        );
      case 'home':
        return HomeScreen(
          romaneador: selectedRomaneador ?? 'Romaneador',
          abertos: abertos,
          fechados: fechados,
          onNew: _createRomaneio,
          onOpen: _resumeRomaneio,
          onLogout: () async {
            selectedRomaneador = null;
            currentScreen = 'login';
            await _persistSelectedRomaneador();
            setState(() {});
          },
        );
      case 'comprador':
        if (currentRomaneio == null) {
          return _buildScreen('home');
        }
        return DadosGeraisScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('comprimento');
          },
          onBack: () => _goTo('home'),
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
          onChanged: (updated) => setState(() => currentRomaneio = updated),
        );
      case 'comprimento':
        if (currentRomaneio == null) {
          return _buildScreen('home');
        }
        return ComprimentoScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            if (currentRomaneio!.comprimento <= 0) {
              return;
            }
            _goTo('diametro');
          },
          onBack: () => _goTo('comprador'),
          onChanged: (updated) => setState(() => currentRomaneio = updated),
        );
      case 'diametro':
        if (currentRomaneio == null) {
          return _buildScreen('home');
        }
        return DiametroScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('quantidade');
          },
          onBack: () => _goTo('comprimento'),
          onChanged: (updated) => setState(() => currentRomaneio = updated),
          onPersist: _persistState,
        );
      case 'quantidade':
        if (currentRomaneio == null) {
          return _buildScreen('home');
        }
        return QuantidadeScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('resumo');
          },
          onBack: () => _goTo('diametro'),
          onChanged: (updated) => setState(() => currentRomaneio = updated),
          onPersist: _persistState,
        );
      case 'resumo':
        if (currentRomaneio == null) {
          return _buildScreen('home');
        }
        return ResumoScreen(
          romaneio: currentRomaneio!,
          onNext: () {
            _saveCurrentRomaneio();
            _goTo('completo');
          },
          onBack: () => _goTo('quantidade'),
        );
      case 'completo':
        if (currentRomaneio == null) {
          return _buildScreen('home');
        }
        return CompletoScreen(
          romaneio: currentRomaneio!,
          onBack: () => _goTo('resumo'),
          onFinalize: _finalizeCurrentRomaneio,
          onChanged: (updated) => setState(() => currentRomaneio = updated),
        );
      default:
        return LoginScreen(
          romaneadores: romaneadores,
          selectedRomaneador: selectedRomaneador,
          onChanged: (value) => setState(() => selectedRomaneador = value),
          onLogin: _login,
        );
    }
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.romaneadores,
    required this.selectedRomaneador,
    required this.onChanged,
    required this.onLogin,
  });

  final List<String> romaneadores;
  final String? selectedRomaneador;
  final ValueChanged<String?> onChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B5D4C),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.park_rounded, size: 88, color: Colors.white),
                  const SizedBox(height: 18),
                  const Text(
                    'ROMANEIO\nDE TORAS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRomaneador,
                        hint: const Text('Selecione o Romaneador'),
                        items: romaneadores
                            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                            .toList(),
                        onChanged: onChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onLogin,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Entrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.romaneador,
    required this.abertos,
    required this.fechados,
    required this.onNew,
    required this.onOpen,
    required this.onLogout,
  });

  final String romaneador;
  final List<Romaneio> abertos;
  final List<Romaneio> fechados;
  final VoidCallback onNew;
  final ValueChanged<Romaneio> onOpen;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Romaneio de Toras'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: onLogout),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Romaneador(a): $romaneador', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onNew,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Novo'),
                    style: _primaryButtonStyle(),
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
                      onPressed: () => onOpen(fechados.last),
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
    );
  }

  ButtonStyle _primaryButtonStyle() => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

class DadosGeraisScreen extends StatefulWidget {
  const DadosGeraisScreen({
    super.key,
    required this.romaneio,
    required this.onNext,
    required this.onBack,
    required this.compradores,
    required this.empreiteiros,
    required this.proprietarios,
    required this.municipios,
    required this.localidades,
    required this.carregadores,
    required this.medidores,
    required this.motoristas,
    required this.operadores,
    required this.placas,
    required this.onChanged,
  });

  final Romaneio romaneio;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final List<String> compradores;
  final List<String> empreiteiros;
  final List<String> proprietarios;
  final List<String> municipios;
  final List<String> localidades;
  final List<String> carregadores;
  final List<String> medidores;
  final List<String> motoristas;
  final List<String> operadores;
  final List<String> placas;
  final ValueChanged<Romaneio> onChanged;

  @override
  State<DadosGeraisScreen> createState() => _DadosGeraisScreenState();
}

class _DadosGeraisScreenState extends State<DadosGeraisScreen> {
  late TextEditingController observacoesController;

  @override
  void initState() {
    super.initState();
    observacoesController = TextEditingController(text: widget.romaneio.observacoes);
  }

  @override
  void dispose() {
    observacoesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final romaneio = widget.romaneio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados Gerais'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _DropdownField<String>(
              label: 'Comprador',
              value: romaneio.comprador,
              items: widget.compradores,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(comprador: value ?? romaneio.comprador));
              },
            ),
            _DropdownField<String>(
              label: 'Empreiteiro(s)',
              value: romaneio.empreiteiros.isNotEmpty ? romaneio.empreiteiros.first : widget.empreiteiros.first,
              items: widget.empreiteiros,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(empreiteiros: value == null ? const [] : [value]));
              },
            ),
            _DropdownField<String>(
              label: 'Proprietário',
              value: romaneio.proprietario,
              items: widget.proprietarios,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(proprietario: value ?? romaneio.proprietario));
              },
            ),
            _DropdownField<String>(
              label: 'Placa',
              value: romaneio.placas.isNotEmpty ? romaneio.placas.first : widget.placas.first,
              items: widget.placas,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(placas: value == null ? const [] : [value]));
              },
            ),
            _DropdownField<String>(
              label: 'Localidade',
              value: romaneio.localidade,
              items: widget.localidades,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(localidade: value ?? romaneio.localidade));
              },
            ),
            _DropdownField<String>(
              label: 'Município',
              value: romaneio.municipio,
              items: widget.municipios,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(municipio: value ?? romaneio.municipio));
              },
            ),
            const SizedBox(height: 8),
            _ReadOnlyField(label: 'Data', value: romaneio.data),
            _ReadOnlyField(label: 'Hora', value: romaneio.hora),
            _DropdownField<String>(
              label: 'Operador do Munk',
              value: romaneio.carregador,
              items: widget.carregadores,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(carregador: value ?? romaneio.carregador));
              },
            ),
            _DropdownField<String>(
              label: 'Medidor',
              value: romaneio.medidor,
              items: widget.medidores,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(medidor: value ?? romaneio.medidor));
              },
            ),
            _DropdownField<String>(
              label: 'Motorista',
              value: romaneio.motorista,
              items: widget.motoristas,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(motorista: value ?? romaneio.motorista));
              },
            ),
            _DropdownField<String>(
              label: 'Munk',
              value: romaneio.operador,
              items: widget.operadores,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(operador: value ?? romaneio.operador));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: observacoesController,
              onChanged: (value) {
                widget.onChanged(romaneio.copyWith(observacoes: value));
              },
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onBack, child: const Text('Voltar')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5D4C), foregroundColor: Colors.white),
                  child: const Text('Avançar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.romaneio.comprimento > 0 ? widget.romaneio.comprimento.toString() : '');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprimento'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.straighten, size: 120, color: Color(0xFF0B5D4C)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                final parsed = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                widget.onChanged(widget.romaneio.copyWith(comprimento: parsed));
              },
              decoration: const InputDecoration(
                labelText: 'Comprimento (m)',
                hintText: 'Exemplo: 1,23 ou 1.23',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onBack, child: const Text('Voltar')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5D4C), foregroundColor: Colors.white),
                  child: const Text('Avançar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
  final TextEditingController customController = TextEditingController();

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  void _addTora(int diametro) {
    final updated = widget.romaneio.addTora(diametro, 1);
    widget.onChanged(updated);
    widget.onPersist();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.romaneio.summary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diâmetro'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('TORAS: ${summary['numToras']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                Expanded(child: Text('VOLUME: ${summary['volToras'].toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Selecione o diâmetro sem a casca:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.8,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(38, (index) {
                final value = 15 + index;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5D4C), foregroundColor: Colors.white),
                  onPressed: () => _addTora(value),
                  child: Text(value.toString()),
                );
              }),
            ),
            const SizedBox(height: 22),
            const Text('Se maior que 52:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Diâmetro', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final value = int.tryParse(customController.text);
                    if (value != null && value > 0) {
                      _addTora(value);
                      customController.clear();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5D4C), foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (widget.romaneio.toras.isNotEmpty) ...[
              const Text('Última tora inserida', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...widget.romaneio.toras.take(5).map((tora) => ListTile(
                    title: Text('Diâmetro ${tora.diametro}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final updated = widget.romaneio.removeTora(tora);
                        widget.onChanged(updated);
                        widget.onPersist();
                      },
                    ),
                  )),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onBack, child: const Text('Voltar')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5D4C), foregroundColor: Colors.white),
                  child: const Text('Avançar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    final toras = romaneio.toras;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quantidade'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: toras.isEmpty
          ? const Center(child: Text('Nenhuma tora cadastrada.'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: toras.length,
              itemBuilder: (context, index) {
                final tora = toras[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('Diâmetro ${tora.diametro}'),
                    subtitle: Text('Quantidade: ${tora.quantidade} · Volume: ${tora.volumeTotal.toStringAsFixed(3)} m³'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            final updated = romaneio.updateQuantity(tora.diametro, tora.quantidade - 1);
                            onChanged(updated);
                            onPersist();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            final updated = romaneio.updateQuantity(tora.diametro, tora.quantidade + 1);
                            onChanged(updated);
                            onPersist();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            final updated = romaneio.removeTora(tora);
                            onChanged(updated);
                            onPersist();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onBack, child: const Text('Voltar')),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5D4C), foregroundColor: Colors.white),
              child: const Text('Avançar'),
            ),
          ],
        ),
      ),
    );
  }
}

class ResumoScreen extends StatelessWidget {
  const ResumoScreen({
    super.key,
    required this.romaneio,
    required this.onNext,
    required this.onBack,
  });

  final Romaneio romaneio;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final summary = romaneio.summary();
    final agrupado = romaneio.groupedVolumeByRange();
    final total = romaneio.totalPrice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoCard(label: 'TORAS', value: '${summary['numToras']}'),
            _InfoCard(label: 'VOLUME', value: '${summary['volToras'].toStringAsFixed(3)} m³'),
            _InfoCard(label: 'DIÂMETRO MÉDIO', value: '${romaneio.averageDiameter().toStringAsFixed(2)} cm'),
            const SizedBox(height: 16),
            const Text('Distribuição por faixa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...agrupado.entries.map((entry) => ListTile(
                  title: Text(entry.key),
                  trailing: Text('${entry.value.toStringAsFixed(3)} m³'),
                )),
            const SizedBox(height: 24),
            Text('Valor estimado: R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onBack, child: const Text('Voltar')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5D4C), foregroundColor: Colors.white),
                  child: const Text('Avançar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CompletoScreen extends StatefulWidget {
  const CompletoScreen({
    super.key,
    required this.romaneio,
    required this.onBack,
    required this.onFinalize,
    required this.onChanged,
  });

  final Romaneio romaneio;
  final VoidCallback onBack;
  final VoidCallback onFinalize;
  final ValueChanged<Romaneio> onChanged;

  @override
  State<CompletoScreen> createState() => _CompletoScreenState();
}

class _CompletoScreenState extends State<CompletoScreen> {
  late final TextEditingController _observacoesController;
  late List<String> _fotos;

  @override
  void initState() {
    super.initState();
    _observacoesController = TextEditingController(text: widget.romaneio.observacoes);
    _fotos = List<String>.from(widget.romaneio.fotos);
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto(int index) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.camera);
    if (result == null) return;

    setState(() {
      _fotos[index] = result.path;
      widget.onChanged(widget.romaneio.copyWith(
        observacoes: _observacoesController.text,
        fotos: List<String>.from(_fotos),
      ));
    });
  }

  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final pdfDocument = await _buildPdf();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/romaneio_${widget.romaneio.id}.pdf');
    await file.writeAsBytes(await pdfDocument.save());

    if (!mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        text: 'Romaneio exportado',
        files: [XFile(file.path)],
      ),
    );

    if (!mounted) return;
    messenger?.showSnackBar(
      const SnackBar(content: Text('PDF exportado com sucesso.')),
    );
  }

  Future<void> _printPdf() async {
    final pdfDocument = await _buildPdf();
    await Printing.layoutPdf(onLayout: (format) async => pdfDocument.save());
  }

  Future<pw.Document> _buildPdf() async {
    final pdf = pw.Document();
    final summary = widget.romaneio.summary();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final body = <pw.Widget>[];
          body.add(pw.Text('ROMANEIO DE TORAS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)));
          body.add(pw.SizedBox(height: 10));
          body.add(pw.Text('Romaneador: ${widget.romaneio.romaneador}'));
          body.add(pw.Text('Comprador: ${widget.romaneio.comprador}'));
          body.add(pw.Text('Empreiteiro: ${widget.romaneio.empreiteiros.join(', ')}'));
          body.add(pw.Text('Proprietário: ${widget.romaneio.proprietario}'));
          body.add(pw.Text('Localidade: ${widget.romaneio.localidade} / ${widget.romaneio.municipio}'));
          body.add(pw.Text('Data: ${widget.romaneio.data} • Hora: ${widget.romaneio.hora}'));
          body.add(pw.SizedBox(height: 12));
          body.add(pw.Text('Quantidade total: ${summary['numToras']}'));
          body.add(pw.Text('Volume total: ${summary['volToras'].toStringAsFixed(3)} m³'));
          body.add(pw.Text('Preço estimado: R\$ ${widget.romaneio.totalPrice().toStringAsFixed(2)}'));
          body.add(pw.SizedBox(height: 12));
          body.add(pw.Text('Toras:'));
          for (final tora in widget.romaneio.toras) {
            body.add(pw.Text('• Diâmetro ${tora.diametro} | Quantidade ${tora.quantidade} | Volume ${tora.volumeTotal.toStringAsFixed(3)} m³'));
          }
          body.add(pw.SizedBox(height: 12));
          body.add(pw.Text('Observações: ${widget.romaneio.observacoes}'));

          for (final photoPath in _fotos.where((path) => path.isNotEmpty)) {
            final file = File(photoPath);
            if (!file.existsSync()) continue;
            final bytes = file.readAsBytesSync();
            final image = pw.MemoryImage(bytes);
            body.add(pw.SizedBox(height: 12));
            body.add(pw.Image(image));
          }

          return pw.Column(children: body, crossAxisAlignment: pw.CrossAxisAlignment.start);
        },
      ),
    );

    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.romaneio.summary();

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
            Text('Romaneador: ${widget.romaneio.romaneador}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Comprador: ${widget.romaneio.comprador}'),
            Text('Empreiteiro: ${widget.romaneio.empreiteiros.join(', ')}'),
            Text('Proprietário: ${widget.romaneio.proprietario}'),
            Text('Localidade: ${widget.romaneio.localidade} / ${widget.romaneio.municipio}'),
            Text('Data: ${widget.romaneio.data} · Hora: ${widget.romaneio.hora}'),
            const SizedBox(height: 14),
            Text('Quantidade total: ${summary['numToras']}'),
            Text('Volume total: ${summary['volToras'].toStringAsFixed(3)} m³'),
            Text('Preço estimado: R\$ ${widget.romaneio.totalPrice().toStringAsFixed(2)}'),
            const SizedBox(height: 18),
            const Text('Observações', style: TextStyle(fontWeight: FontWeight.w700)),
            TextField(
              controller: _observacoesController,
              onChanged: (value) {
                widget.onChanged(widget.romaneio.copyWith(observacoes: value, fotos: List<String>.from(_fotos)));
              },
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 18),
            const Text('Fotos do romaneio', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(3, (index) {
                final exists = index < _fotos.length && _fotos[index].isNotEmpty;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _capturePhoto(index),
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
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(child: Icon(Icons.camera_alt_outlined, size: 32)),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportPdf,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Exportar PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _printPdf,
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Imprimir'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onBack, child: const Text('Voltar')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.onFinalize,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5D4C), foregroundColor: Colors.white),
                  child: const Text('Finalizar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(value),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    String? selected = items.contains(value.toString()) ? value.toString() : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        readOnly: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class Tora {
  const Tora({
    required this.diametro,
    required this.quantidade,
    this.volumeTotal = 0,
  });

  final int diametro;
  final int quantidade;
  final double volumeTotal;

  Tora copyWith({int? diametro, int? quantidade, double? volumeTotal}) {
    return Tora(
      diametro: diametro ?? this.diametro,
      quantidade: quantidade ?? this.quantidade,
      volumeTotal: volumeTotal ?? this.volumeTotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'diametro': diametro,
        'quantidade': quantidade,
        'volumeTotal': volumeTotal,
      };

  factory Tora.fromJson(Map<String, dynamic> json) {
    return Tora(
      diametro: (json['diametro'] as num).toInt(),
      quantidade: (json['quantidade'] as num).toInt(),
      volumeTotal: (json['volumeTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Romaneio {
  const Romaneio({
    this.id = '',
    this.romaneador = '',
    this.comprador = '',
    this.empreiteiros = const [],
    this.proprietario = '',
    this.placas = const [],
    this.localidade = '',
    this.municipio = '',
    this.data = '',
    this.hora = '',
    this.carregador = '',
    this.medidor = '',
    this.motorista = '',
    this.operador = '',
    this.observacoes = '',
    this.comprimento = 0,
    this.toras = const [],
    this.fotos = const [],
    this.romaneioAberto = true,
  });

  final String id;
  final String romaneador;
  final String comprador;
  final List<String> empreiteiros;
  final String proprietario;
  final List<String> placas;
  final String localidade;
  final String municipio;
  final String data;
  final String hora;
  final String carregador;
  final String medidor;
  final String motorista;
  final String operador;
  final String observacoes;
  final double comprimento;
  final List<Tora> toras;
  final List<String> fotos;
  final bool romaneioAberto;

  Romaneio copyWith({
    String? id,
    String? romaneador,
    String? comprador,
    List<String>? empreiteiros,
    String? proprietario,
    List<String>? placas,
    String? localidade,
    String? municipio,
    String? data,
    String? hora,
    String? carregador,
    String? medidor,
    String? motorista,
    String? operador,
    String? observacoes,
    double? comprimento,
    List<Tora>? toras,
    List<String>? fotos,
    bool? romaneioAberto,
  }) {
    return Romaneio(
      id: id ?? this.id,
      romaneador: romaneador ?? this.romaneador,
      comprador: comprador ?? this.comprador,
      empreiteiros: empreiteiros ?? this.empreiteiros,
      proprietario: proprietario ?? this.proprietario,
      placas: placas ?? this.placas,
      localidade: localidade ?? this.localidade,
      municipio: municipio ?? this.municipio,
      data: data ?? this.data,
      hora: hora ?? this.hora,
      carregador: carregador ?? this.carregador,
      medidor: medidor ?? this.medidor,
      motorista: motorista ?? this.motorista,
      operador: operador ?? this.operador,
      observacoes: observacoes ?? this.observacoes,
      comprimento: comprimento ?? this.comprimento,
      toras: toras ?? this.toras,
      fotos: fotos ?? this.fotos,
      romaneioAberto: romaneioAberto ?? this.romaneioAberto,
    );
  }

  double _volumeUnitario(int diametro) {
    final d = diametro.toDouble();
    return ((d * d * math.pi) / 40000) * comprimento;
  }

  Romaneio addTora(int diametro, int quantidade) {
    final novaLista = List<Tora>.from(toras);
    final index = novaLista.indexWhere((item) => item.diametro == diametro);

    if (index >= 0) {
      final atual = novaLista[index];
      final novoVolume = _volumeUnitario(diametro) * (atual.quantidade + quantidade);
      novaLista[index] = atual.copyWith(
        quantidade: atual.quantidade + quantidade,
        volumeTotal: novoVolume,
      );
    } else {
      novaLista.add(Tora(
        diametro: diametro,
        quantidade: quantidade,
        volumeTotal: _volumeUnitario(diametro) * quantidade,
      ));
    }

    return copyWith(toras: novaLista);
  }

  Romaneio removeTora(Tora tora) {
    final novaLista = toras.where((item) => item.diametro != tora.diametro).toList();
    return copyWith(toras: novaLista);
  }

  Romaneio updateQuantity(int diametro, int novaQuantidade) {
    if (novaQuantidade <= 0) {
      return removeTora(Tora(diametro: diametro, quantidade: 1));
    }

    final novaLista = List<Tora>.from(toras);
    final index = novaLista.indexWhere((item) => item.diametro == diametro);
    if (index >= 0) {
      final atual = novaLista[index];
      novaLista[index] = atual.copyWith(
        quantidade: novaQuantidade,
        volumeTotal: _volumeUnitario(diametro) * novaQuantidade,
      );
      return copyWith(toras: novaLista);
    }
    return addTora(diametro, novaQuantidade);
  }

  Map<String, dynamic> summary() {
    int numToras = 0;
    double volTotal = 0;

    for (final tora in toras) {
      final volume = tora.volumeTotal > 0 ? tora.volumeTotal : _volumeUnitario(tora.diametro) * tora.quantidade;
      numToras += tora.quantidade;
      volTotal += volume;
    }

    return {'numToras': numToras, 'volToras': volTotal};
  }

  Map<String, double> groupedVolumeByRange() {
    final result = {
      '<= 24': 0.0,
      '25 a 29': 0.0,
      '30 a 34': 0.0,
      '35 a 39': 0.0,
      '> 39': 0.0,
    };

    for (final tora in toras) {
      final volume = tora.volumeTotal > 0 ? tora.volumeTotal : _volumeUnitario(tora.diametro) * tora.quantidade;
      if (tora.diametro <= 24) {
        result['<= 24'] = (result['<= 24'] ?? 0) + volume;
      } else if (tora.diametro <= 29) {
        result['25 a 29'] = (result['25 a 29'] ?? 0) + volume;
      } else if (tora.diametro <= 34) {
        result['30 a 34'] = (result['30 a 34'] ?? 0) + volume;
      } else if (tora.diametro <= 39) {
        result['35 a 39'] = (result['35 a 39'] ?? 0) + volume;
      } else {
        result['> 39'] = (result['> 39'] ?? 0) + volume;
      }
    }

    return result;
  }

  double averageDiameter() {
    if (toras.isEmpty) return 0;
    final totalQuant = toras.fold<int>(0, (sum, item) => sum + item.quantidade);
    final totalDiam = toras.fold<double>(0, (sum, item) => sum + (item.diametro * item.quantidade));
    return totalQuant == 0 ? 0 : totalDiam / totalQuant;
  }

  double totalPrice() {
    if (toras.isEmpty) return 0;
    final totalVolume = summary()['volToras'] as double;
    return totalVolume * 120.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'romaneador': romaneador,
        'comprador': comprador,
        'empreiteiros': empreiteiros,
        'proprietario': proprietario,
        'placas': placas,
        'localidade': localidade,
        'municipio': municipio,
        'data': data,
        'hora': hora,
        'carregador': carregador,
        'medidor': medidor,
        'motorista': motorista,
        'operador': operador,
        'observacoes': observacoes,
        'comprimento': comprimento,
        'toras': toras.map((item) => item.toJson()).toList(),
        'fotos': fotos,
        'romaneioAberto': romaneioAberto,
      };

  factory Romaneio.fromJson(Map<String, dynamic> json) {
    return Romaneio(
      id: json['id'] as String? ?? '',
      romaneador: json['romaneador'] as String? ?? '',
      comprador: json['comprador'] as String? ?? '',
      empreiteiros: (json['empreiteiros'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      proprietario: json['proprietario'] as String? ?? '',
      placas: (json['placas'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      localidade: json['localidade'] as String? ?? '',
      municipio: json['municipio'] as String? ?? '',
      data: json['data'] as String? ?? '',
      hora: json['hora'] as String? ?? '',
      carregador: json['carregador'] as String? ?? '',
      medidor: json['medidor'] as String? ?? '',
      motorista: json['motorista'] as String? ?? '',
      operador: json['operador'] as String? ?? '',
      observacoes: json['observacoes'] as String? ?? '',
      comprimento: (json['comprimento'] as num?)?.toDouble() ?? 0,
      toras: (json['toras'] as List<dynamic>? ?? const [])
          .map((item) => Tora.fromJson(item as Map<String, dynamic>))
          .toList(),
      fotos: (json['fotos'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      romaneioAberto: json['romaneioAberto'] as bool? ?? true,
    );
  }
}
