import 'package:flutter/material.dart';
import '../widgets/curved_header.dart';
import 'sign_in_screen.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  static const route = '/onboarding';

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: Column(
        children: [
          // ─────────────────────────────────────────────
          // HEADER + OPTIONAL BACK BUTTON
          // ─────────────────────────────────────────────
          Stack(
            children: [
              const CurvedHeader(
                title: 'FloodWatch App',
                subtitle: 'Real-time flood monitoring for your community.',
                icon: Icons.link,
              ),
              if (canPop)
                SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay Ahead of Rising Waters',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track flood levels, rainfall, and alerts. Get notified before risks escalate.',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, SignInScreen.route),
                  child: const Text('Sign In'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, Dashboard.route),
                    child: const Text('Continue without account'),
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
