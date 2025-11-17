import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../tabs/home_tab.dart';
import '../tabs/activity_tab.dart';
import '../tabs/profile_tab.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  static const route = '/dashboard';

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    // ─────────────────────────────────────────────────────────
    // AUTH CHECK
    // If currentUser == null → guest (from "Continue without account")
    // If not null → logged-in user with full features
    // ─────────────────────────────────────────────────────────
    final user = FirebaseAuth.instance.currentUser;
    final bool isGuest = user == null;

    // Pages depending on auth state
    final pages = isGuest
        ? const [
            HomeTab(isGuest: true),
            ActivityTab(),
          ]
        : const [
            HomeTab(isGuest: false),
            ActivityTab(),
            ProfileTab(),
          ];

    // Keep index safe
    int safeIndex = index;
    if (safeIndex >= pages.length) {
      safeIndex = 0;
    }

    // Bottom dock items depending on auth state
    final items = isGuest
        ? const [
            DockItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
            ),
            DockItem(
              icon: Icons.list_alt_outlined,
              activeIcon: Icons.list_alt,
              label: 'Activity',
            ),
          ]
        : const [
            DockItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
            ),
            DockItem(
              icon: Icons.list_alt_outlined,
              activeIcon: Icons.list_alt,
              label: 'Activity',
            ),
            DockItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
          ];

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1200;
    final double dockWidth =
        (size.width * 0.96).clamp(280.0, isDesktop ? 1280.0 : double.infinity);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Current page
          Positioned.fill(child: pages[safeIndex]),

          // Glassy bottom dock + optional guest banner
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: dockWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─────────────────────────────────────────
                      // GUEST MODE BANNER
                      // Visible only when user is not logged in
                      // ─────────────────────────────────────────
                      if (isGuest)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Guest mode · Limited features',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      SizedBox(
                        height: 66,
                        child: Docker(
                          currentIndex: safeIndex,
                          onTap: (i) => setState(() => index = i),
                          items: items,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data model for each dock button
class DockItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const DockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Glassy rounded dock with animated selection pill
class Docker extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<DockItem> items;

  const Docker({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware dock colors
    final Color dockBg =
        isDark ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.45);
    final Color dockBorder =
        isDark ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.60);
    final Color shadowClr =
        isDark ? Colors.black.withOpacity(0.40) : Colors.black.withOpacity(0.10);

    final Color inactive =
        isDark ? Colors.white.withOpacity(.80) : Colors.black.withOpacity(.65);
    final Color active = scheme.primary;
    final Color selectedPill =
        isDark ? Colors.white.withOpacity(.12) : Colors.black.withOpacity(.18);

    return SizedBox(
      height: 66,
      child: ClipRrectAndBlur(
        blurSigma: 30,
        borderRadius: 24,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: dockBg,
            border: Border.all(color: dockBorder),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: shadowClr, blurRadius: 25, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == currentIndex;

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected ? selectedPill : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          size: 24,
                          color: selected ? active : inactive,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: SizedBox(width: selected ? 8 : 0),
                        ),
                        AnimatedOpacity(
                          opacity: selected ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: selected
                              ? Text(
                                  item.label,
                                  style: TextStyle(
                                    color: active,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Small helper: clip first, then apply a confined backdrop blur
class ClipRrectAndBlur extends StatelessWidget {
  final double blurSigma;
  final double borderRadius;
  final Widget child;
  const ClipRrectAndBlur({
    super.key,
    required this.blurSigma,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: const SizedBox.expand(),
          ),
          child,
        ],
      ),
    );
  }
}
