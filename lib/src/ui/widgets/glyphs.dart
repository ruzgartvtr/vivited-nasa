import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../theme/vivited_theme.dart';

Color targetColor(TargetKind k) => switch (k) {
      TargetKind.astrobiology => VColors.ice,
      TargetKind.geology => VColors.bone,
      TargetKind.cache => VColors.sulfur,
      TargetKind.landmark => VColors.dust,
    };

/// The Vivited mark: a planetary limb, and a route that descends to a single
/// destination point — a "V" drawn the way a traverse is drawn on a map.
class VivitedMark extends StatelessWidget {
  const VivitedMark({super.key, this.size = 28, this.progress = 1});
  final double size;

  /// 0–1 draw-on progress for the loading animation.
  final double progress;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(progress),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = size.center(Offset.zero);
    final stroke = math.max(1.0, s * 0.055);
    // Limb.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: s / 2 - stroke / 2),
      -math.pi / 2,
      2 * math.pi * t.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = VColors.bone
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.6,
    );
    // Route: two legs meeting at the destination.
    final a = Offset(s * 0.27, s * 0.30);
    final b = Offset(s * 0.50, s * 0.72);
    final d = Offset(s * 0.73, s * 0.30);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * ((t - 0.25) / 0.6).clamp(0.0, 1.0)),
      Paint()
        ..color = VColors.bone
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.square,
    );
    if (t > 0.8) {
      canvas.drawCircle(b, s * 0.085, Paint()..color = VColors.oxide);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.t != t;
}

/// Diamond survey mark for a science target.
class TargetGlyph extends StatelessWidget {
  const TargetGlyph({super.key, required this.kind, this.selected = false, this.inRoute = false});
  final TargetKind kind;
  final bool selected;
  final bool inRoute;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size.square(22),
        painter: _TargetPainter(targetColor(kind), selected, inRoute),
      );
}

class _TargetPainter extends CustomPainter {
  _TargetPainter(this.color, this.selected, this.inRoute);
  final Color color;
  final bool selected;
  final bool inRoute;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = selected ? 8.0 : 5.5;
    final diamond = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = VColors.ink);
    canvas.drawPath(
      diamond,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1.5,
    );
    if (selected || inRoute) {
      canvas.drawCircle(c, 1.8, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_TargetPainter old) =>
      old.color != color || old.selected != selected || old.inRoute != inRoute;
}

/// Compact code badge for educational mission checkpoints (H0, CP1…).
class CheckpointGlyph extends StatelessWidget {
  const CheckpointGlyph({
    super.key,
    required this.code,
    this.selected = false,
    this.signal = false,
  });
  final String code;
  final bool selected;
  final bool signal;

  @override
  Widget build(BuildContext context) {
    final fill = signal || code == 'H0' ? VColors.oxide : VColors.ice;
    final fg = signal || code == 'H0' ? VColors.ink : VColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? fill : VColors.ink,
        border: Border.all(color: fill, width: selected ? 2 : 1.5),
      ),
      child: Text(
        code,
        style: VType.label(
          color: selected ? fg : fill,
          size: 8.5,
        ),
      ),
    );
  }
}

/// Numbered square for a planned stop; the base is an oxide ring.
class StopGlyph extends StatelessWidget {
  const StopGlyph({super.key, required this.index});

  /// 0 = base.
  final int index;

  @override
  Widget build(BuildContext context) {
    if (index == 0) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: VColors.ink,
          border: Border.all(color: VColors.oxide, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: VColors.oxide,
          ),
        ),
      );
    }
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VColors.ice,
        border: Border.all(color: VColors.ink, width: 1.5),
      ),
      child: Text('$index', style: VType.data(10, color: VColors.ink, medium: true)),
    );
  }
}

/// The walker: a dot with a heading wedge and a slow range ring.
class WalkerGlyph extends StatefulWidget {
  const WalkerGlyph({super.key, required this.headingDeg, this.moving = true});
  final double headingDeg;
  final bool moving;

  @override
  State<WalkerGlyph> createState() => _WalkerGlyphState();
}

class _WalkerGlyphState extends State<WalkerGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: const Size.square(44),
          painter: _WalkerPainter(widget.headingDeg, _c.value, widget.moving),
        ),
      );
}

class _WalkerPainter extends CustomPainter {
  _WalkerPainter(this.heading, this.t, this.moving);
  final double heading;
  final double t;
  final bool moving;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      7 + 13 * t,
      Paint()
        ..color = VColors.oxide.withValues(alpha: 0.55 * (1 - t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    if (moving) {
      final a = (heading - 90) * math.pi / 180;
      final tip = c + Offset(math.cos(a), math.sin(a)) * 15;
      final l = c + Offset(math.cos(a + 2.3), math.sin(a + 2.3)) * 6;
      final r = c + Offset(math.cos(a - 2.3), math.sin(a - 2.3)) * 6;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(l.dx, l.dy)
          ..lineTo(r.dx, r.dy)
          ..close(),
        Paint()..color = VColors.oxide,
      );
    }
    canvas.drawCircle(c, 6, Paint()..color = VColors.ink);
    canvas.drawCircle(c, 4.5, Paint()..color = VColors.oxide);
  }

  @override
  bool shouldRepaint(_WalkerPainter old) =>
      old.heading != heading || old.t != t || old.moving != moving;
}
