part of '../main.dart';

abstract class PhotoCaptureService {
  Future<XFile?> capture();
}

class ImagePickerPhotoCaptureService implements PhotoCaptureService {
  const ImagePickerPhotoCaptureService();

  @override
  Future<XFile?> capture() =>
      ImagePicker().pickImage(source: ImageSource.camera);
}

class FotosScreen extends StatefulWidget {
  const FotosScreen({
    super.key,
    required this.romaneio,
    required this.onNext,
    required this.onBack,
    required this.onChanged,
    this.cameraService,
  });

  final Romaneio romaneio;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final ValueChanged<Romaneio> onChanged;
  final PhotoCaptureService? cameraService;

  @override
  State<FotosScreen> createState() => _FotosScreenState();
}

class _FotosScreenState extends State<FotosScreen> {
  static const _captions = [
    'Traseira do caminhão carregado (aparecendo a placa)',
    'Lateral do caminhão carregado',
    'Nota fiscal',
  ];

  final _scrollController = ScrollController();
  late final PhotoCaptureService _camera;
  late List<String> _photos;
  int? _firstMissing;

  @override
  void initState() {
    super.initState();
    _camera = widget.cameraService ?? const ImagePickerPhotoCaptureService();
    _photos = List<String>.from(widget.romaneio.fotos);
    while (_photos.length < 3) _photos.add('');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _capture(int index) async {
    try {
      final picked = await _camera.capture();
      if (picked == null) return;
      final dot = picked.name.lastIndexOf('.');
      final extension = dot >= 0 ? picked.name.substring(dot) : '.jpg';
      final safeId = widget.romaneio.id.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final fileName =
          '${safeId}_foto_${index + 1}_${DateTime.now().microsecondsSinceEpoch}$extension';
      final directories = <Directory>[];
      if (Platform.environment['FLUTTER_TEST'] != 'true') {
        try {
          final documentsPath = await getApplicationDocumentsDirectory();
          directories.add(Directory('${documentsPath.path}/romaneio_photos'));
        } catch (_) {}
      }
      directories.add(Directory('.dart_tool/romaneio_photos'));
      File? saved;
      Object? lastError;
      for (final directory in directories) {
        try {
          directory.createSync(recursive: true);
          saved = File(picked.path).copySync('${directory.path}/$fileName');
          break;
        } catch (error) {
          lastError = error;
        }
      }
      if (saved == null) throw lastError ?? StateError('Falha ao salvar foto.');
      if (!mounted) return;
      setState(() {
        _photos[index] = saved!.path;
        _firstMissing = null;
      });
      widget.onChanged(
        widget.romaneio.copyWith(fotos: List<String>.from(_photos)),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = error.code == 'camera_access_denied'
          ? 'A permissão da câmera foi negada. Autorize o acesso nas configurações do aparelho.'
          : 'Não foi possível abrir a câmera. Verifique as permissões do aparelho.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a foto.')),
        );
      }
    }
  }

  void _advance() {
    final missing = _photos.indexWhere((photo) => photo.trim().isEmpty);
    if (missing >= 0) {
      setState(() => _firstMissing = missing);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollController.animateTo(
          missing * 500.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tire todas as fotos obrigatórias.')),
      );
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  height: 48,
                  color: const Color(0xFF004D40),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('fotos-back-button'),
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: widget.onBack,
                      ),
                      const Text(
                        'Fotos',
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
                      SingleChildScrollView(
                        key: const ValueKey('fotos-list'),
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(15, 20, 15, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < _captions.length; i++) ...[
                              _photoCard(i),
                              if (i < _captions.length - 1)
                                const SizedBox(height: 36),
                            ],
                            SizedBox(
                              height: 204,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const ForestFooter(),
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: ElevatedButton.icon(
                                      key: const ValueKey('fotos-next-button'),
                                      onPressed: _advance,
                                      iconAlignment: IconAlignment.end,
                                      icon: const Icon(
                                        Icons.arrow_forward,
                                        size: 18,
                                      ),
                                      label: const Text('AVANÇAR'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF26A69A,
                                        ),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(105, 36),
                                        elevation: 3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  Widget _photoCard(int index) {
    final path = _photos[index];
    final exists = path.isNotEmpty && File(path).existsSync();
    final missing = _firstMissing == index;
    return Material(
      elevation: 3,
      shadowColor: Colors.grey.shade400,
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.none,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: missing
              ? Border.all(color: const Color(0xFFE57373), width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          children: [
            InkWell(
              key: ValueKey('fotos-image-area-$index'),
              onTap: () => _capture(index),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: exists
                    ? Image.file(
                        File(path),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        key: ValueKey('fotos-thumbnail-$index'),
                      )
                    : const ColoredBox(
                        color: Color(0xFFF1F1F1),
                        child: Center(
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 48,
                            color: Colors.black,
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _captions[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: -19,
                    child: Material(
                      color: const Color(0xFF26A69A),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        key: ValueKey('fotos-add-$index'),
                        customBorder: const CircleBorder(),
                        onTap: () => _capture(index),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.add, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
