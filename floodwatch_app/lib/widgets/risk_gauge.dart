import 'package:flutter/material.dart';
import 'dart:math' as math;

class RiskGauge extends StatelessWidget {
  final double value;
  final double? thickness;

  const RiskGauge({super.key, required this.value, this.thickness});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 140.0;
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
        final t = thickness ?? h.clamp(80, 220) * 0.12;

        return CustomPaint(
          size: Size(w, h),
          painter: _GaugePainter(
            color: color,
            value: value,
            thickness: t,
            bgColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(value * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Overall risk',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(isDark ? 0.80 : 0.65),
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final Color color;
  final double value;
  final double thickness;
  final Color bgColor;

  _GaugePainter({
    required this.color,
    required this.value,
    required this.thickness,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const start = math.pi;
    const sweep = math.pi;

    final pad = thickness / 2 + 8;
    final radius = math.min((size.width - pad * 2) / 2, size.height - pad);
    final center = Offset(size.width / 2, size.height - pad);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..shader = LinearGradient(colors: [color.withOpacity(.4), color]).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, start, sweep, false, bg);
    canvas.drawArc(rect, start, sweep * value.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color || old.thickness != thickness || old.bgColor != bgColor;
}
