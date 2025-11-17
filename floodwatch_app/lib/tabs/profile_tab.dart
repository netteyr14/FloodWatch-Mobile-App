import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/curved_header.dart';
import '../theme/app_theme.dart';
import '../screens/onboarding_screen.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';

Future<String?> _fetchUsername() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!snap.exists) return null;
  return snap.data()?['username'];
}


class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        children: [
          const CurvedHeader(
            title: 'Profile',
            subtitle: 'Manage account and preferences.',
            icon: Icons.settings,
            compact: true,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.transparent,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/user.png',
                          fit: BoxFit.contain,
                          width: 36,
                          height: 36,
                        ),
                      ),
                    ),

                    title: FutureBuilder<String?>(
                      future: _fetchUsername(),
                      builder: (context, snapshot) {
                        final firebaseUser = FirebaseAuth.instance.currentUser;

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Loading...');
                        }

                        // First priority: Firestore username
                        String? username = snapshot.data;

                        // Second priority: Firebase Auth displayName
                        username ??= firebaseUser?.displayName;

                        // Final fallback
                        username ??= 'User';

                        return Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),

                    subtitle: Text(
                      FirebaseAuth.instance.currentUser?.email ?? '',
                    ),
                  ),
                  const Divider(height: 0),

                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppTheme.mode,
                    builder: (context, mode, _) {
                      final isDark = mode == ThemeMode.dark;
                      return SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Dark Mode'),
                        value: isDark,
                        onChanged: (v) {
                          AppTheme.mode.value =
                              v ? ThemeMode.dark : ThemeMode.light;
                        },
                      );
                    },
                  ),

                  const Divider(height: 0),
                  const _SettingItem(
                    title: 'Change Password',
                    icon: Icons.lock_reset,
                  ),
                  const _SettingItem(
                    title: 'Support',
                    icon: Icons.help_outline,
                  ),

                  // SIGN OUT
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Color(0xFFEF4444),
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () async {
  // 1) Sign out from Firebase
  await FirebaseAuth.instance.signOut();

  // 2) Hard-redirect back to Onboarding,
  //    clearing Dashboard & other routes from the stack.
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    (route) => false,
  );
},

                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SettingItem({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: hook up actual setting behavior if needed
      },
    );
  }
}
