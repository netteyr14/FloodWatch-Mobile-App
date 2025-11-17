import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final double? trend;        // ← make nullable
  final IconData icon;
  final bool showTrend;       // ← new flag (default true)

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.trend,               // ← optional now
    this.showTrend = true,    // ← default keeps old behavior
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final up = (trend ?? 0) >= 0;
    final chipColor = up ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primary.withOpacity(isDark ? 0.20 : 0.10),
                  child: Icon(icon, color: scheme.primary),
                ),
                const Spacer(),
                // Trend chip only when requested AND trend provided
                if (showTrend && trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipColor.withOpacity(.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(up ? Icons.north_east : Icons.south_east, size: 16, color: chipColor),
                        const SizedBox(width: 4),
                        Text(
                          '${(trend!.abs() * 100).toStringAsFixed(0)}%',
                          style: TextStyle(color: chipColor, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(isDark ? 0.7 : 0.55),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
