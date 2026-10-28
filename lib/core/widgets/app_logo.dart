import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../constants/app_colors.dart';

/// Logo de Tianguis Control: un puesto de tianguis visto de frente, con
/// toldo a rayas, cajas de mercancía y una etiqueta de precio.
///
/// Se dibuja en código con [CustomPainter] para que:
/// - sea nítido en cualquier densidad de pantalla,
/// - sirva como app icon, splash y logo del negocio por defecto (§5, §6),
/// - no dependa de assets binarios versionados.
///
/// Para el app icon y el splash de Android, esta misma forma se rasteriza a
/// PNG con `tool/generate_icon.dart` (`flutter test tool/generate_icon.dart`).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.showText = false,
    this.customPath,
  });

  final double size;

  /// Añade el nombre de la app bajo el logo.
  final bool showText;

  /// Logo personalizado del negocio. Si es `null` se usa el de la app (§6).
  final String? customPath;

  @override
  Widget build(BuildContext context) {
    final Widget mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PuestoPainter()),
    );

    if (!showText) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        SizedBox(height: size * 0.16),
        Text(
          'Tianguis Control',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Tu puesto, bajo control.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Logo del negocio con fallback automático al de la app (§6).
class BusinessLogo extends ConsumerWidget {
  const BusinessLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? path = ref.watch(businessLogoPathProvider);
    if (path == null) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _PuestoPainter()),
      );
    }
    return ClipOval(
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(painter: _PuestoPainter()),
            ),
      ),
    );
  }
}

/// Dibuja el puesto: toldo, poste, mostrador, mercancía y etiqueta de precio.
class _PuestoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double u = math.min(w, h);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));

    _drawBackground(canvas, w, h);
    _drawPostes(canvas, w, h, u);
    _drawToldo(canvas, w, h, u);
    _drawMostrador(canvas, w, h, u);
    _drawMercancia(canvas, w, h, u);
    _drawEtiquetaPrecio(canvas, w, h, u);

    canvas.restore();
  }

  /// Fondo redondeado crema con un halo cálido: el "puesto" se recorta solo.
  void _drawBackground(Canvas canvas, double w, double h) {
    final Rect rect = Rect.fromLTWH(0, 0, w, h);
    final RRect bg = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.min(w, h) * 0.22),
    );
    canvas.drawRRect(
      bg,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[TianguisPalette.crema, Color(0xFFFFEFC9)],
        ).createShader(rect),
    );
  }

  void _drawPostes(Canvas canvas, double w, double h, double u) {
    final Paint paint = Paint()..color = TianguisPalette.cafe;
    final double postW = u * 0.045;
    final double top = h * 0.34;
    final double bottom = h * 0.84;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.13, top, postW, bottom - top),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.87 - postW, top, postW, bottom - top),
      paint,
    );
  }

  /// Toldo a rayas rojas, amarillas y naranjas, con festón inferior.
  void _drawToldo(Canvas canvas, double w, double h, double u) {
    final Rect toldo = Rect.fromLTWH(w * 0.08, h * 0.16, w * 0.84, h * 0.24);
    final RRect shape = RRect.fromRectAndCorners(
      toldo,
      topLeft: Radius.circular(u * 0.10),
      topRight: Radius.circular(u * 0.10),
      bottomLeft: Radius.circular(u * 0.02),
      bottomRight: Radius.circular(u * 0.02),
    );
    canvas.drawRRect(shape, Paint()..color = TianguisPalette.crema);

    // Rayas verticales.
    canvas.save();
    canvas.clipRRect(shape);
    const List<Color> stripes = <Color>[
      TianguisPalette.chile,
      TianguisPalette.amarillo,
      TianguisPalette.naranja,
    ];
    final int count = 9;
    final double stripeW = toldo.width / count;
    for (int i = 0; i < count; i++) {
      if (i.isOdd) continue;
      canvas.drawRect(
        Rect.fromLTWH(toldo.left + i * stripeW, toldo.top, stripeW, toldo.height),
        Paint()..color = stripes[(i ~/ 2) % stripes.length],
      );
    }
    canvas.restore();

    // Festón: semicírculos bajo el toldo.
    final Paint scallop = Paint()..color = TianguisPalette.naranja;
    final int bumps = 7;
    final double bumpW = toldo.width / bumps;
    for (int i = 0; i < bumps; i++) {
      final double cx = toldo.left + bumpW * (i + 0.5);
      canvas.drawCircle(
        Offset(cx, toldo.bottom + u * 0.005),
        bumpW / 2,
        scallop..color = i.isEven ? TianguisPalette.naranja : TianguisPalette.amarillo,
      );
    }
  }

  void _drawMostrador(Canvas canvas, double w, double h, double u) {
    final Rect counter = Rect.fromLTWH(w * 0.13, h * 0.60, w * 0.74, h * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(counter, Radius.circular(u * 0.03)),
      Paint()..color = TianguisPalette.cafe,
    );
    // Franja clara: da volumen sin detalles innecesarios.
    canvas.drawRect(
      Rect.fromLTWH(counter.left, counter.top, counter.width, counter.height * 0.3),
      Paint()..color = TianguisPalette.crema.withValues(alpha: 0.85),
    );
  }

  /// Cajas de mercancía apiladas sobre el mostrador.
  void _drawMercancia(Canvas canvas, double w, double h, double u) {
    final List<List<double>> boxes = <List<double>>[
      <double>[0.19, 0.24, 0.17],
      <double>[0.38, 0.19, 0.14],
      <double>[0.55, 0.25, 0.16],
    ];
    const List<Color> colors = <Color>[
      TianguisPalette.naranja,
      TianguisPalette.verde,
      TianguisPalette.turquesa,
    ];

    for (int i = 0; i < boxes.length; i++) {
      final List<double> b = boxes[i];
      final Rect r = Rect.fromLTWH(
        w * b[0],
        h * 0.60 - h * b[1],
        w * b[2],
        h * b[1],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(u * 0.015)),
        Paint()..color = colors[i],
      );
      // Cinturón de la caja.
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top + r.height * 0.42, r.width, r.height * 0.16),
        Paint()..color = TianguisPalette.crema.withValues(alpha: 0.55),
      );
    }
  }

  /// Etiqueta de precio colgada del lado derecho, estilo "¿cuánto?".
  void _drawEtiquetaPrecio(Canvas canvas, double w, double h, double u) {
    final double tagW = w * 0.20;
    final double tagH = h * 0.13;
    final Rect tag = Rect.fromLTWH(w * 0.66, h * 0.30, tagW, tagH);
    final Path path = Path()
      ..moveTo(tag.left, tag.top)
      ..lineTo(tag.right, tag.top)
      ..lineTo(tag.right, tag.bottom)
      // Punta hacia la izquierda: sugiere una etiqueta colgada.
      ..lineTo(tag.left, (tag.top + tag.bottom) / 2)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = TianguisPalette.blanco,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.014
        ..color = TianguisPalette.negro,
    );

    final TextPainter label = TextPainter(
      text: TextSpan(
        text: '\$150',
        style: TextStyle(
          color: TianguisPalette.negro,
          fontSize: tagH * 0.52,
          fontWeight: FontWeight.w800,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(
        tag.left + (tag.width - label.width) / 2 + tagW * 0.06,
        tag.top + (tag.height - label.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_PuestoPainter oldDelegate) => false;
}
