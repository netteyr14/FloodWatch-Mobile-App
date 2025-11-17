import 'package:flutter/material.dart';
import '../widgets/curved_header.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = [
      ('Moderate rainfall expected', 'Today 2:30 PM', 'Watch for localized flooding.'),
      ('Flood level rising', 'Today 7:10 AM', 'In Durian Main St. 0.1 m in last 3 hours.'),
    ];

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: CurvedHeader(title: 'Activity', subtitle: 'Latest alerts and updates.', icon: Icons.notifications_active, compact: true),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final a = alerts[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.12),
                    child: Icon(Icons.notification_important, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(a.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${a.$2} • ${a.$3}'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
            childCount: alerts.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
