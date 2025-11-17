import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

/// ─────────────────────────────────────────────────────────
/// AUTH GATE
/// Decides which screen should show on app startup:
/// - Dashboard if user is already logged in
/// - Onboarding if not logged in
/// ─────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Firebase will emit a User if logged in, null if logged out
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {
        // ─────────────────────────────────────────────────────────
        // STILL LOADING USER AUTH STATE
        // Show splash/loading to avoid flashing screens
        // ─────────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ─────────────────────────────────────────────────────────
        // USER LOGGED IN → GO TO DASHBOARD
        // ─────────────────────────────────────────────────────────
        if (snapshot.hasData) {
          return const Dashboard();
        }

        // ─────────────────────────────────────────────────────────
        // USER NOT LOGGED IN → SHOW ONBOARDING SCREEN
        // ─────────────────────────────────────────────────────────
        return const OnboardingScreen();
      },
    );
  }
}
