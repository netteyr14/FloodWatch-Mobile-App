import 'package:flutter/material.dart';

class CurvedHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;

  const CurvedHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.compact = false,
  });

  // ---- Color helpers --------------------------------------------------------
  Color _lighten(Color c, double amount, {double sat = 0}) {
    final h = HSLColor.fromColor(c);
    return h
        .withLightness((h.lightness + amount).clamp(0.0, 1.0))
        .withSaturation((h.saturation + sat).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color c, double amount, {double sat = 0}) {
    final h = HSLColor.fromColor(c);
    return h
        .withLightness((h.lightness - amount).clamp(0.0, 1.0))
        .withSaturation((h.saturation + sat).clamp(0.0, 1.0))
        .toColor();
  }

  // Blends a color with black for guaranteed dark tone in dark mode.
  Color _withBlackScrim(Color c, double opacity) =>
      Color.alphaBlend(Colors.black.withOpacity(opacity), c);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = compact ? 180.0 : 260.0;

    // ── Pick a base tone for the header that “feels” right per mode ──────────
    // NOTE:
    // - In light mode we start from primary and brighten a touch.
    // - In dark mode we *force* a darker tone than scheme.primary by first
    //   darkening and then blending a tiny black scrim to avoid “glow”.
    final Color brand = scheme.primary;
    final Color baseForHeader = isDark
        ? _withBlackScrim(_darken(brand, 0.28, sat: -0.04), 0.10)
        : _lighten(brand, 0.10, sat: 0.05);

    // Build a two-stop gradient around that base.
    final Color g1 = isDark
        ? _darken(baseForHeader, 0.06) // darkest corner
        : _lighten(baseForHeader, 0.06);
    final Color g2 = isDark
        ? _darken(baseForHeader, 0.16) // slightly lighter end (still dark)
        : _darken(baseForHeader, 0.03);

    // Text/icon colors per mode.
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    final Color iconBg =
        isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    // Vignette/bubbles tint
    final Color bubbleColor =
        isDark ? Colors.white.withOpacity(0.055) : Colors.white.withOpacity(0.12);

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Background gradient
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g1, g2],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(48),
              ),
            ),
          ),

          // Extra scrim in dark mode to ensure “a little darker” feel.
          if (isDark)
            Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(48),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // ↑ lower 0.10 if you want slightly brighter dark header
                  colors: [Colors.black.withOpacity(0.10), Colors.transparent],
                ),
              ),
            ),

          // Soft bubbles
          Positioned.fill(child: CustomPaint(painter: _BubblesPainter(bubbleColor))),

          // Content row
          Positioned(
            left: 20,
            right: 20,
            bottom: compact ? 20 : 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: bubbleColor,
                  child: Icon(icon, color: textColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Subtitle
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
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
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final Color color;
  const _BubblesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final circles = [
      Offset(size.width * .20, size.height * .25),
      Offset(size.width * .75, size.height * .18),
      Offset(size.width * .60, size.height * .45),
    ];
    for (var i = 0; i < circles.length; i++) {
      canvas.drawCircle(circles[i], 36 - i * 8, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
