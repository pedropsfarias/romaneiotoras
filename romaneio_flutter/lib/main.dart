import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as spreadsheet;

import 'models/romaneio.dart';
import 'models/master_data.dart';
import 'services/romaneio_storage.dart';
import 'services/master_import_service.dart';
import 'services/romaneio_export_service.dart';
import 'services/balanceamento_service.dart';
import 'services/bluetooth_print_service.dart';

export 'models/romaneio.dart';
export 'models/master_data.dart';
export 'services/master_import_service.dart';
export 'services/bluetooth_print_service.dart';

part 'app/romaneio_app.dart';
part 'screens/login_screen.dart';
part 'screens/master_import_screen.dart';
part 'screens/home_screen.dart';
part 'screens/comprador_screen.dart';
part 'screens/dados_gerais_screen.dart';
part 'screens/balanceamento_screen.dart';
part 'screens/comprimento_screen.dart';
part 'screens/diametro_screen.dart';
part 'screens/quantidade_screen.dart';
part 'screens/resumo_screen.dart';
part 'screens/completo_screen.dart';
part 'screens/romaneio_screen.dart';
part 'screens/impressao_screen.dart';
part 'screens/finalizados_screen.dart';
part 'widgets/romaneio_fields.dart';
part 'widgets/forest_footer.dart';
part 'screens/fotos_screen.dart';

void main() {
  runApp(const RomaneioApp());
}
