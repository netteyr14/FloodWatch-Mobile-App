// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FloodwatchAdminApp());
}

class FloodwatchAdminApp extends StatelessWidget {
  const FloodwatchAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'FloodWatch Admin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,

          home: const LoginScreen(),

          // ✅ Needed for logout navigation
          routes: {
            '/login': (context) => const LoginScreen(),
          },
        );
      },
    );
  }
}
