// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../widgets/curved_header.dart';
import '../app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const placeholderName = "Admin";
    final isDark = ThemeController.themeMode.value == ThemeMode.dark;

    return Column(
      children: [
        const CurvedHeader(
          title: 'PROFILE',
          subtitle: 'Your information and settings',
          icon: Icons.person,
          compact: true,
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // USER CARD
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.person,
                            size: 40,
                            color: Theme.of(context).iconTheme.color),
                      ),
                      const SizedBox(width: 18),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            placeholderName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Administrator",
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // SETTINGS TITLE
                const Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                const _SettingItem(title: "Account Details", icon: Icons.person_outline),
                const _SettingItem(title: "Change Password", icon: Icons.lock_outline),
                const _SettingItem(title: "Appearance", icon: Icons.palette_outlined),
                const _SettingItem(title: "Notifications", icon: Icons.notifications_outlined),
                const _SettingItem(title: "Help & Support", icon: Icons.help_outline),

                // DARK MODE TOGGLE
                SwitchListTile(
                  title: const Text("Dark Mode"),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: isDark,
                  onChanged: (value) {
                    ThemeController.toggleTheme(value);
                  },
                ),

                const SizedBox(height: 30),

                // LOGOUT
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login', // <-- Make sure this matches your route name
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      "Logout",
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      onTap: () {},
    );
  }
}
