import 'package:material_ui/material_ui.dart';

import '../../mission/mission_plan.dart';
import '../../science/provenance.dart';
import '../../theme/vivited_theme.dart';

/// 1 px rule.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color = VColors.rule, this.vertical = false});
  final Color color;
  final bool vertical;

  @override
  Widget build(BuildContext context) => vertical
      ? Container(width: 1, color: color)
      : Container(height: 1, color: color);
}

/// Numbered section heading: "02  TERRAIN ————".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.index, this.title, {super.key, this.trailing});
  final String index;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Row(
          children: [
            Text(index, style: VType.label(color: VColors.oxide)),
            const SizedBox(width: 10),
            Text(title.toUpperCase(), style: VType.label(color: VColors.bone)),
            const SizedBox(width: 12),
            const Expanded(child: Hairline()),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      );
}

/// Label on the left, monospaced value on the right.
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key, this.valueColor, this.note});
  final String label;
  final String value;
  final Color? valueColor;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: LayoutBuilder(
          builder: (context, box) => Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(label, style: VType.body(12.5, color: VColors.dust)),
              ),
              const SizedBox(width: 10),
              // The value keeps its natural width up to ~60 % of the row,
              // then wraps; the label takes what is left.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.62),
                child: Text.rich(
                  TextSpan(
                    text: value,
                    style: VType.data(12.5, color: valueColor ?? VColors.bone),
                    children: [
                      if (note != null)
                        TextSpan(
                          text: '  $note',
                          style: VType.data(10.5, color: VColors.ash),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Large serif numeral with unit and caption — the atlas "figure".
class Figure extends StatelessWidget {
  const Figure({
    super.key,
    required this.value,
    required this.caption,
    this.unit,
    this.size = 34,
    this.color = VColors.bone,
  });

  final String value;
  final String? unit;
  final String caption;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: VType.display(size, color: color)),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!, style: VType.data(11, color: VColors.dust)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(caption.toUpperCase(), style: VType.label(size: 9)),
        ],
      );
}

/// Flat rectangular button. [primary] fills with the signal colour.
class VButton extends StatefulWidget {
  const VButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.dense = false,
    this.active = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool dense;
  final bool active;
  final String? tooltip;

  @override
  State<VButton> createState() => _VButtonState();
}

class _VButtonState extends State<VButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final filled = widget.primary || widget.active;
    final bg = !enabled
        ? Colors.transparent
        : filled
            ? (_hover ? VColors.bone : VColors.oxide)
            : (_hover ? VColors.raised : Colors.transparent);
    final fg = !enabled
        ? VColors.ash
        : filled
            ? VColors.ink
            : VColors.bone;
    final child = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? 10 : 14,
            vertical: widget.dense ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
              color: filled && enabled ? bg : VColors.ruleStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.dense ? 13 : 15, color: fg),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  widget.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: VType.label(color: fg, size: widget.dense ? 9.5 : 10.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: widget.tooltip == null
          ? child
          : Tooltip(message: widget.tooltip!, child: child),
    );
  }
}

/// Square icon button used on the map chrome.
class VIconButton extends StatefulWidget {
  const VIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
    this.size = 34,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool active;
  final double size;

  @override
  State<VIconButton> createState() => _VIconButtonState();
}

class _VIconButtonState extends State<VIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: Semantics(
          button: true,
          label: widget.tooltip,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.active
                      ? VColors.oxide
                      : _hover
                          ? VColors.raised
                          : VColors.basalt,
                  border: Border.all(
                    color: widget.active ? VColors.oxide : VColors.rule,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 16,
                  color: widget.active ? VColors.ink : VColors.bone,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Row with a square check mark — layer toggles.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
    this.swatch,
    this.radio = false,
  });

  final String label;
  final String? caption;
  final bool value;
  final VoidCallback onChanged;
  final Color? swatch;
  final bool radio;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: value,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onChanged,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: radio ? BoxShape.circle : BoxShape.rectangle,
                      color: value ? (swatch ?? VColors.oxide) : Colors.transparent,
                      border: Border.all(
                        color: value ? (swatch ?? VColors.oxide) : VColors.ash,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: VType.body(
                            13,
                            color: value ? VColors.bone : VColors.dust,
                            weight: value ? 500 : 400,
                          ),
                        ),
                        if (caption != null)
                          Text(
                            caption!,
                            style: VType.data(10, color: VColors.ash),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Labelled slider with a live read-out.
class ParamSlider extends StatelessWidget {
  const ParamSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.divisions,
    this.note,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String display;
  final String? note;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: VType.body(12.5, color: VColors.dust)),
                ),
                Text(display, style: VType.data(12.5)),
              ],
            ),
            SizedBox(
              height: 26,
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                semanticFormatterCallback: (_) => '$label $display',
              ),
            ),
            if (note != null)
              Text(note!, style: VType.data(10, color: VColors.ash)),
          ],
        ),
      );
}

Color checkColor(CheckStatus s) => switch (s) {
      CheckStatus.pass => VColors.lichen,
      CheckStatus.warn => VColors.sulfur,
      CheckStatus.fail => VColors.alarm,
      CheckStatus.info => VColors.ice,
    };

String checkWord(CheckStatus s) => switch (s) {
      CheckStatus.pass => 'GO',
      CheckStatus.warn => 'CAUTION',
      CheckStatus.fail => 'NO-GO',
      CheckStatus.info => 'NOTE',
    };

/// One line of the go / no-go board.
class CheckRow extends StatelessWidget {
  const CheckRow(this.check, {super.key});
  final PlanCheck check;

  @override
  Widget build(BuildContext context) {
    final c = checkColor(check.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 2, height: 30, color: c),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.title, style: VType.body(12.5, weight: 600)),
                Text(checkWord(check.status), style: VType.label(color: c, size: 8.5)),
              ],
            ),
          ),
          Expanded(
            child: Text(
              check.detail,
              style: VType.body(12, color: VColors.dust, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small bordered tag.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = VColors.dust});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(text.toUpperCase(), style: VType.label(color: color, size: 8.5)),
      );
}

/// NASA DATA / SCIENTIFIC INTERPRETATION / SIMULATION chip.
class ProvenanceChip extends StatelessWidget {
  const ProvenanceChip(this.klass, {super.key, this.compact = false});
  final SourceClass klass;
  final bool compact;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: klass.caption,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 7,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: klass.color.withValues(alpha: 0.55)),
          ),
          child: Text(
            klass.label,
            style: VType.label(color: klass.color, size: compact ? 7.5 : 8.5),
          ),
        ),
      );
}

/// Formats seconds as "1 h 05 m" / "42 m".
String formatDuration(double seconds) {
  if (!seconds.isFinite) return '—';
  final m = (seconds / 60).round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} m';
}

/// Formats seconds as H:MM:SS mission-elapsed time.
String formatMet(double seconds) {
  final s = seconds.round();
  return '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

String formatDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(2)} km'
    : '${meters.round()} m';
