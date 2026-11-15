import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/climate.dart';
import '../../mission/mission_plan.dart';
import '../../science/mars_time.dart';
import '../../theme/vivited_theme.dart';

void _text(
  Canvas canvas,
  String s,
  Offset at,
  TextStyle style, {
  Alignment align = Alignment.topLeft,
}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = -(align.x + 1) / 2 * tp.width;
  final dy = -(align.y + 1) / 2 * tp.height;
  tp.paint(canvas, at + Offset(dx, dy));
}

// ---- Elevation profile ----------------------------------------------------------

/// Route cross-section: elevation against distance, the line coloured by the
/// hazard class of the ground underfoot. Drag to scrub the rehearsal clock.
class ElevationProfile extends StatelessWidget {
  const ElevationProfile({
    super.key,
    required this.plan,
    this.playheadS,
    this.onScrub,
    this.height = 120,
  });

  final MissionPlan plan;
  final double? playheadS;
  final ValueChanged<double>? onScrub;
  final double height;

  void _scrub(Offset local, double width) {
    if (onScrub == null || plan.distanceM <= 0) return;
    final f = ((local.dx - _ProfilePainter.padL) /
            (width - _ProfilePainter.padL - _ProfilePainter.padR))
        .clamp(0.0, 1.0);
    final d = f * plan.distanceM;
    // First sample at or beyond that distance.
    final s = plan.samples.firstWhere(
      (s) => s.distM >= d,
      orElse: () => plan.samples.last,
    );
    onScrub!(s.timeS);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => MouseRegion(
          cursor: onScrub == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _scrub(d.localPosition, c.maxWidth),
            onHorizontalDragUpdate: (d) => _scrub(d.localPosition, c.maxWidth),
            child: CustomPaint(
              size: Size(c.maxWidth, height),
              painter: _ProfilePainter(plan, playheadS),
            ),
          ),
        ),
      );
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.plan, this.playheadS);
  final MissionPlan plan;
  final double? playheadS;

  static const padL = 46.0, padR = 12.0, padT = 16.0, padB = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = plan.samples;
    if (s.length < 2) return;
    final w = size.width - padL - padR, h = size.height - padT - padB;
    var lo = plan.minElevM, hi = plan.maxElevM;
    final pad = math.max(4.0, (hi - lo) * 0.12);
    lo -= pad;
    hi += pad;
    final total = plan.distanceM;
    Offset pt(RouteSample p) => Offset(
          padL + p.distM / total * w,
          padT + (1 - (p.elevM - lo) / (hi - lo)) * h,
        );

    final label = VType.data(9.5, color: VColors.ash);
    final rule = Paint()
      ..color = VColors.rule
      ..strokeWidth = 1;
    // Horizontal grid: three elevation lines.
    for (var i = 0; i <= 2; i++) {
      final y = padT + h * i / 2;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), rule);
      final z = hi - (hi - lo) * i / 2;
      _text(canvas, '${z.round()}', Offset(padL - 6, y), label,
          align: Alignment.centerRight);
    }
    _text(canvas, 'm', Offset(padL - 6, padT - 12), label,
        align: Alignment.topRight);
    // Distance ticks.
    final stepKm = total > 6000 ? 2.0 : total > 2500 ? 1.0 : 0.5;
    for (var km = 0.0; km * 1000 <= total; km += stepKm) {
      final x = padL + km * 1000 / total * w;
      canvas.drawLine(Offset(x, padT + h), Offset(x, padT + h + 4), rule);
      _text(canvas, km == 0 ? '0 km' : (km % 1 == 0 ? '${km.round()}' : '$km'),
          Offset(x, padT + h + 7), label,
          align: Alignment.topCenter);
    }

    // Fill.
    final fill = Path()..moveTo(padL, padT + h);
    for (final p in s) {
      final o = pt(p);
      fill.lineTo(o.dx, o.dy);
    }
    fill
      ..lineTo(padL + w, padT + h)
      ..close();
    canvas.drawPath(fill, Paint()..color = const Color(0x14EFE8DC));

    // Line, coloured by hazard class.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < s.length; i++) {
      line.color = VColors.hazard(s[i].hazard);
      canvas.drawLine(pt(s[i - 1]), pt(s[i]), line);
    }

    // Stations.
    for (final st in plan.stations) {
      final sample = s.firstWhere((p) => p.timeS >= st.arriveS);
      final o = pt(sample);
      canvas.drawLine(
        Offset(o.dx, padT),
        Offset(o.dx, padT + h),
        Paint()
          ..color = VColors.ice.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(o.dx, padT), width: 13, height: 13),
        Paint()..color = VColors.ice,
      );
      _text(canvas, '${st.stopIndex}', Offset(o.dx, padT),
          VType.data(9, color: VColors.ink, medium: true),
          align: Alignment.center);
    }

    // Playhead.
    if (playheadS != null) {
      final st = plan.stateAt(playheadS!);
      final x = padL + st.distM / total * w;
      final y = padT + (1 - (st.elevM - lo) / (hi - lo)) * h;
      canvas.drawLine(
        Offset(x, padT - 4),
        Offset(x, padT + h),
        Paint()
          ..color = VColors.oxide
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = VColors.oxide);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..color = VColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_ProfilePainter old) =>
      old.plan != plan || old.playheadS != playheadS;
}

// ---- Diurnal chart ----------------------------------------------------------------

/// A sol of measured MEDA air and ground temperature at the chosen season,
/// against local true solar time, with night shading and the EVA window.
class DiurnalChart extends StatelessWidget {
  const DiurnalChart({
    super.key,
    required this.climate,
    required this.ls,
    required this.latDeg,
    this.evaStart,
    this.evaEnd,
    this.nowLtst,
    this.height = 132,
  });

  final Climatology climate;
  final double ls;
  final double latDeg;
  final double? evaStart;
  final double? evaEnd;
  final double? nowLtst;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _DiurnalPainter(this),
      );
}

class _DiurnalPainter extends CustomPainter {
  _DiurnalPainter(this.w);
  final DiurnalChart w;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 40.0, padR = 10.0, padT = 10.0, padB = 22.0;
    final cw = size.width - padL - padR, ch = size.height - padT - padB;
    final label = VType.data(9.5, color: VColors.ash);

    // Sample the climatology in LTST.
    const n = 96;
    final air = <double?>[], ground = <double?>[];
    for (var i = 0; i <= n; i++) {
      final ltst = i * 24.0 / n;
      final c = w.climate.sample(w.ls, MarsTime.lmstFromLtst(ltst, w.ls));
      air.add(c.airTempC);
      ground.add(c.groundTempC);
    }
    final all = [...air, ...ground].whereType<double>().toList();
    if (all.isEmpty) return;
    var lo = (all.reduce(math.min) / 20).floor() * 20.0;
    var hi = (all.reduce(math.max) / 20).ceil() * 20.0;
    if (hi - lo < 40) hi = lo + 40;
    double x(double ltst) => padL + ltst / 24 * cw;
    double y(double t) => padT + (1 - (t - lo) / (hi - lo)) * ch;

    // Night.
    final rise = MarsTime.sunriseLtst(ls: w.ls, latDeg: w.latDeg);
    final set = MarsTime.sunsetLtst(ls: w.ls, latDeg: w.latDeg);
    final night = Paint()..color = const Color(0xFF080807);
    canvas.drawRect(Rect.fromLTRB(x(0), padT, x(rise), padT + ch), night);
    canvas.drawRect(Rect.fromLTRB(x(set), padT, x(24), padT + ch), night);

    // EVA window.
    if (w.evaStart != null && w.evaEnd != null) {
      canvas.drawRect(
        Rect.fromLTRB(
          x(w.evaStart!),
          padT,
          x(math.min(24, w.evaEnd!)),
          padT + ch,
        ),
        Paint()..color = VColors.oxide.withValues(alpha: 0.16),
      );
      final edge = Paint()
        ..color = VColors.oxide
        ..strokeWidth = 1;
      canvas.drawLine(
          Offset(x(w.evaStart!), padT), Offset(x(w.evaStart!), padT + ch), edge);
      canvas.drawLine(Offset(x(math.min(24, w.evaEnd!)), padT),
          Offset(x(math.min(24, w.evaEnd!)), padT + ch), edge);
    }

    // Grid.
    final rule = Paint()
      ..color = VColors.rule
      ..strokeWidth = 1;
    for (var t = lo; t <= hi; t += 20) {
      canvas.drawLine(Offset(padL, y(t)), Offset(padL + cw, y(t)), rule);
      _text(canvas, '${t.round()}°', Offset(padL - 6, y(t)), label,
          align: Alignment.centerRight);
    }
    for (var hr = 0; hr <= 24; hr += 6) {
      canvas.drawLine(
          Offset(x(hr + 0.0), padT + ch), Offset(x(hr + 0.0), padT + ch + 4), rule);
      _text(canvas, hr.toString().padLeft(2, '0'), Offset(x(hr + 0.0), padT + ch + 7),
          label,
          align: Alignment.topCenter);
    }

    void curve(List<double?> v, Color color, double width) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round;
      Path? path;
      for (var i = 0; i <= n; i++) {
        final t = v[i];
        if (t == null) {
          if (path != null) canvas.drawPath(path, paint);
          path = null;
          continue;
        }
        final o = Offset(x(i * 24.0 / n), y(t));
        if (path == null) {
          path = Path()..moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      if (path != null) canvas.drawPath(path, paint);
    }

    curve(ground, VColors.ember.withValues(alpha: 0.85), 1.1);
    curve(air, VColors.bone, 1.6);

    if (w.nowLtst != null) {
      canvas.drawLine(
        Offset(x(w.nowLtst!), padT - 3),
        Offset(x(w.nowLtst!), padT + ch),
        Paint()
          ..color = VColors.bone
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_DiurnalPainter old) =>
      old.w.ls != w.ls ||
      old.w.evaStart != w.evaStart ||
      old.w.evaEnd != w.evaEnd ||
      old.w.nowLtst != w.nowLtst;
}

// ---- Season dial --------------------------------------------------------------------

/// Mars's orbit to scale (eccentricity 0.093, Sun at the focus). Drag the
/// planet to choose the season as solar longitude Ls.
class SeasonDial extends StatelessWidget {
  const SeasonDial({super.key, required this.ls, required this.onChanged, this.size = 150});
  final double ls;
  final ValueChanged<double> onChanged;
  final double size;

  void _handle(Offset local) {
    final c = _SeasonPainter.sunOffset(Size.square(size));
    final v = local - c;
    var deg = math.atan2(-v.dy, v.dx) * 180 / math.pi;
    if (deg < 0) deg += 360;
    onChanged((deg / 5).round() * 5 % 360);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Season dial, solar longitude ${ls.round()} degrees',
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: GestureDetector(
            onPanDown: (d) => _handle(d.localPosition),
            onPanUpdate: (d) => _handle(d.localPosition),
            child: CustomPaint(
              size: Size.square(size),
              painter: _SeasonPainter(ls),
            ),
          ),
        ),
      );
}

class _SeasonPainter extends CustomPainter {
  _SeasonPainter(this.ls);
  final double ls;

  static const _aphelionAu = 1.6660;

  static double _scale(Size size) => (size.width / 2 - 16) / _aphelionAu;

  /// The Sun sits off-centre so the whole ellipse fits the square.
  static Offset sunOffset(Size size) {
    // Aphelion lies towards Ls = 71°, perihelion towards 251°; shift the Sun
    // by half the difference along that axis.
    const shiftAu = (1.6660 - 1.3814) / 2;
    final a = 251 * math.pi / 180;
    return size.center(Offset.zero) +
        Offset(math.cos(a), -math.sin(a)) * (shiftAu * _scale(size));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sun = sunOffset(size);
    final k = _scale(size);
    Offset at(double lsDeg, [double extra = 0]) {
      final a = lsDeg * math.pi / 180;
      final r = MarsTime.sunDistanceAuFromLs(lsDeg) * k + extra;
      return sun + Offset(math.cos(a) * r, -math.sin(a) * r);
    }

    // Orbit.
    final orbit = Path();
    for (var d = 0; d <= 360; d += 3) {
      final o = at(d.toDouble());
      d == 0 ? orbit.moveTo(o.dx, o.dy) : orbit.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      orbit,
      Paint()
        ..color = VColors.ruleStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Ticks every 30°, labels at the cardinal seasons.
    final tick = Paint()
      ..color = VColors.ash
      ..strokeWidth = 1;
    for (var d = 0; d < 360; d += 30) {
      final major = d % 90 == 0;
      canvas.drawLine(at(d.toDouble(), -3), at(d.toDouble(), major ? 6 : 3), tick);
      if (major) {
        _text(canvas, '$d°', at(d.toDouble(), 15),
            VType.data(8.5, color: VColors.ash),
            align: Alignment.center);
      }
    }
    // Perihelion marker.
    final peri = at(251);
    canvas.drawCircle(
      peri,
      2.5,
      Paint()
        ..color = VColors.dust
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Sun.
    canvas.drawCircle(sun, 4, Paint()..color = VColors.sulfur);
    // Radius vector and planet.
    final mars = at(ls);
    canvas.drawLine(
      sun,
      mars,
      Paint()
        ..color = VColors.oxide.withValues(alpha: 0.55)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(mars, 6, Paint()..color = VColors.oxide);
    canvas.drawCircle(
      mars,
      9.5,
      Paint()
        ..color = VColors.oxide.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SeasonPainter old) => old.ls != ls;
}

// ---- Bars ---------------------------------------------------------------------------

/// Segmented horizontal bar: distance walked on each hazard class.
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.values, required this.colors, this.height = 6});
  final List<double> values;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            if (values[i] > 0)
              Expanded(
                flex: math.max(1, (values[i] / total * 1000).round()),
                child: Container(color: colors[i]),
              ),
        ],
      ),
    );
  }
}

/// Thin gauge with a reserve marker — used for oxygen.
class Gauge extends StatelessWidget {
  const Gauge({
    super.key,
    required this.fraction,
    this.marker,
    this.color = VColors.bone,
    this.height = 5,
  });

  /// Filled fraction 0–1.
  final double fraction;

  /// Optional tick position 0–1 (e.g. reserve line).
  final double? marker;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SizedBox(
          height: height + 6,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 3,
                height: height,
                child: Container(color: VColors.rule),
              ),
              Positioned(
                left: 0,
                top: 3,
                height: height,
                width: c.maxWidth * fraction.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
              if (marker != null)
                Positioned(
                  left: c.maxWidth * marker!.clamp(0.0, 1.0) - 0.5,
                  top: 0,
                  height: height + 6,
                  width: 1,
                  child: Container(color: VColors.bone),
                ),
            ],
          ),
        ),
      );
}
