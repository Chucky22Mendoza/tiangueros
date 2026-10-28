// Genera los iconos de Android rasterizando el logo real de la app.
//
// El logo se dibuja en código con `AppLogo` (ver `lib/core/widgets/app_logo.dart`).
// Rasterizar ese mismo widget garantiza que el icono del lanzador, el splash y el
// logo dentro de la app sean la misma imagen: no hay dos fuentes de verdad.
//
// Uso (offline, no necesita `flutter_launcher_icons`):
//   flutter test tool/generate_icon.dart
//
// Escribe:
//   android/app/src/main/res/mipmap-*/ic_launcher.png
//   android/app/src/main/res/mipmap-*/ic_launcher_round.png
//   android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
//   android/app/src/main/res/mipmap-anydpi-v26/ic_launcher{,_round}.xml
//   android/app/src/main/res/values/ic_launcher_background.xml
//
// Iconos adaptativos (Android 8+): el PNG heredado lleva la imagen completa, pero
// en `mipmap-anydpi-v26` el fondo va aparte y el logo va dentro de la zona segura
// central de 72/108, que es lo que sobrevive al recorte en círculo, squircle o
// "burbuja" que aplica cada fabricante.
//
// Todo el IO es **síncrono** a propósito: dentro de `testWidgets` el cuerpo corre
// en una zona de async falsa donde `await File(...)` nunca se resuelve, y
// `tester.runAsync` se colgaba al_RELEASEar imágenes de Flutter. `writeAsBytesSync`
// y `Process.runSync` no dependen del event loop.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/core/widgets/app_logo.dart';

/// Lienzo grande una sola vez; el escalado a cada densidad lo hace Pillow.
const double _master = 1024;

/// Un solo `pumpWidget` por test: rasterizar dos veces seguidas cuelga el
/// rasterizador por software del isolate de `flutter test`.
Future<ByteData> _renderLogo(WidgetTester tester) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: const SizedBox.square(
          dimension: _master,
          child: AppLogo(size: _master),
        ),
      ),
    ),
  );
  // Un frame basta: el logo es estático.
  await tester.pump();

  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 1);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) throw StateError('no se pudo rasterizar el logo');
  return png;
}

/// Reescala y compone los PNG de cada densidad.
///
/// `mode` decide qué se guarda:
/// - `full`: la imagen completa, que es el icono heredado (48dp).
/// - `safe`: la imagen completa reducida a 72/108 y centrada sobre un lienzo
///   transparente de 108dp, que es el foreground adaptativo.
const String _pythonScript = r'''
import sys
from PIL import Image

master, out_dir, mode, side = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
src = Image.open(master).convert("RGBA")
if mode == "full":
    out = src.resize((side, side), Image.LANCZOS)
else:
    inner = int(round(side * 72 / 108))
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(src.resize((inner, inner), Image.LANCZOS), ((side - inner) // 2, (side - inner) // 2))
out.save(out_dir, "PNG", optimize=True)
''';

void _runPython(List<String> args) {
  final ProcessResult result = Process.runSync('python3', <String>[
    '-c',
    _pythonScript,
    ...args,
  ]);
  if (result.exitCode != 0) {
    throw StateError('Pillow falló (${args.join(' ')}):\n${result.stderr}');
  }
}

void main() {
  testWidgets('genera los iconos de Android desde AppLogo', (
    WidgetTester tester,
  ) async {
    final ByteData png = await _renderLogo(tester);

    // 1) Maestro en disco.
    const String masterPath = '/tmp/tianguis_icon_master.png';
    File(masterPath).writeAsBytesSync(
      png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      flush: true,
    );
    stdout.writeln('Maestro: $_master px, ${png.lengthInBytes ~/ 1024} KiB');

    const String res = 'android/app/src/main/res';

    // 2) Cada densidad: icono heredado (48dp) y foreground adaptativo (108dp).
    //    Los lados son los canónicos de Android: 48/72/96/144/192 y
    //    108/162/216/324/432.
    const Map<String, int> legacyPx = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    const Map<String, int> foregroundPx = <String, int>{
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    };

    stdout.writeln('Iconos:');
    for (final String density in legacyPx.keys) {
      final Directory dir = Directory('$res/mipmap-$density')
        ..createSync(recursive: true);
      for (final String name in <String>['ic_launcher.png', 'ic_launcher_round.png']) {
        _runPython(<String>[masterPath, '${dir.path}/$name', 'full', '${legacyPx[density]}']);
        stdout.writeln('  mipmap-$density/$name  ${legacyPx[density]}px');
      }
      _runPython(<String>[
        masterPath,
        '${dir.path}/ic_launcher_foreground.png',
        'safe',
        '${foregroundPx[density]}',
      ]);
      stdout.writeln('  mipmap-$density/ic_launcher_foreground.png  ${foregroundPx[density]}px');
    }

    // 3) El fondo del icono adaptativo es el crema del propio logo
    //    (TianguisPalette.crema) para que no se note el corte del recorte.
    const String colorsXml =
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <!-- Fondo del icono adaptativo: el crema de TianguisPalette.crema. -->\n'
        '    <color name="ic_launcher_background">#FFF8E7</color>\n'
        '</resources>\n';
    File('$res/values/ic_launcher_background.xml')
        .writeAsStringSync(colorsXml, flush: true);
    stdout.writeln('  values/ic_launcher_background.xml');

    // 4) anydpi-v26: Android 8+ usa el icono adaptativo; las versiones
    //    anteriores caen al PNG heredado.
    const String adaptiveXml =
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n';
    final Directory adaptive = Directory('$res/mipmap-anydpi-v26')
      ..createSync(recursive: true);
    File('${adaptive.path}/ic_launcher.xml').writeAsStringSync(adaptiveXml, flush: true);
    File('${adaptive.path}/ic_launcher_round.xml').writeAsStringSync(adaptiveXml, flush: true);
    stdout.writeln('  mipmap-anydpi-v26/ic_launcher.xml');
    stdout.writeln('  mipmap-anydpi-v26/ic_launcher_round.xml');
  });
}
