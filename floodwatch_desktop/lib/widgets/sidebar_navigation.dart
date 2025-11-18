// lib/widgets/sidebar_navigation.dart
import 'package:flutter/material.dart';
import '../app_theme.dart';

class SidebarNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelect;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  // Reuse lighten/darken logic from curved header
  Color _lighten(Color c, double amount, {double sat = 0}) {
    final h = HSLColor.fromColor(c);
    return h
        .withLightness((h.lightness + amount).clamp(0, 1))
        .withSaturation((h.saturation + sat).clamp(0, 1))
        .toColor();
  }

  Color _darken(Color c, double amount, {double sat = 0}) {
    final h = HSLColor.fromColor(c);
    return h
        .withLightness((h.lightness - amount).clamp(0, 1))
        .withSaturation((h.saturation + sat).clamp(0, 1))
        .toColor();
  }

  Color _withBlackScrim(Color c, double opacity) =>
      Color.alphaBlend(Colors.black.withOpacity(opacity), c);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = isCollapsed ? 72.0 : 230.0;

    final Color brand = Theme.of(context).colorScheme.primary;

    // ---- Match CurvedHeader’s gradient behavior ----
    final Color base = isDark
        ? _withBlackScrim(_lighten(brand, 0.03, sat: -0.02), 0.04)
        : _lighten(brand, 0.14, sat: 0.06);

    final Color g1 = isDark ? _lighten(base, 0.04) : _lighten(base, 0.08);
    final Color g2 = isDark ? _darken(base, 0.10) : _darken(base, 0.04);

    final Color bubbleColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.14);

    final Color footerTextColor =
        isDark ? AppTheme.darkSidebarText : Colors.black54;

    final Color toggleColor =
        isDark ? AppTheme.darkSidebarText : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [g1, g2],
        ),
      ),
      child: Stack(
        children: [
          // Soft background bubbles (matches CurvedHeader)
          Positioned.fill(child: CustomPaint(painter: _SidebarBubbles(bubbleColor))),

          Column(
            children: [
              const SizedBox(height: 24),

              // App icon / logo area
              if (!isCollapsed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: const [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.water_drop, color: Colors.black87),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'FloodWatch',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.water_drop, color: Colors.black87),
                ),

              const SizedBox(height: 24),

              // NAV ITEMS
              _NavItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                index: 0,
                selected: selectedIndex == 0,
                collapsed: isCollapsed,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: Icons.engineering,
                label: 'Operations',
                index: 1,
                selected: selectedIndex == 1,
                collapsed: isCollapsed,
                onTap: () => onSelect(1),
              ),
              _NavItem(
                icon: Icons.person,
                label: 'Profile',
                index: 2,
                selected: selectedIndex == 2,
                collapsed: isCollapsed,
                onTap: () => onSelect(2),
              ),

              const Spacer(),

              if (!isCollapsed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "FloodWatch v1.0",
                      style: TextStyle(
                        fontSize: 12,
                        color: footerTextColor,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Align(
                  alignment:
                      isCollapsed ? Alignment.center : Alignment.centerRight,
                  child: IconButton(
                    onPressed: onToggleCollapse,
                    icon: Icon(
                      isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 24,
                      color: toggleColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// NAV ITEM
// =============================================================================

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color accent = Color(0xFFBADA75); // softer for header match

    final Color color = selected
        ? accent
        : (isDark ? AppTheme.darkSidebarText : Colors.black87);

    final Color bg = selected
        ? accent.withOpacity(0.14)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: 16,
          horizontal: collapsed ? 0 : 20,
        ),
        color: bg,
        child: collapsed
            ? Center(child: Icon(icon, size: 22, color: color))
            : Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// Gradient bubble painter (like CurvedHeader)
// =============================================================================

class _SidebarBubbles extends CustomPainter {
  final Color color;
  const _SidebarBubbles(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;

    canvas.drawCircle(Offset(size.width * .65, size.height * .10), 26, p);
    canvas.drawCircle(Offset(size.width * .30, size.height * .32), 22, p);
    canvas.drawCircle(Offset(size.width * .75, size.height * .55), 18, p);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
