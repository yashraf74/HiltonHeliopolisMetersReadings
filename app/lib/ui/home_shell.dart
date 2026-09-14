import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../data/db/database.dart';
import '../data/models.dart';
import '../state/connectivity_controller.dart';
import '../state/meters_controller.dart';
import '../state/session_controller.dart';
import 'screens/meters_screen.dart';
import 'screens/my_readings_screen.dart';
import 'screens/placeholder_screen.dart';
import 'widgets/status_widgets.dart';

class _Tab {
  const _Tab({required this.label, required this.icon, required this.body, this.enabled = true});

  final String label;
  final IconData icon;
  final Widget body;
  final bool enabled;
}

/// Role-based navigation. The dashboard entry is present for both roles but
/// disabled, as a visible placeholder for phase 2.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Warm the meter cache on entry; a failure just keeps the cached list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MetersController>().refresh();
    });
  }

  List<_Tab> _tabsFor(AuthUser user) => [
        const _Tab(
          label: S.navNewReading,
          icon: Icons.add_circle_outline_rounded,
          body: PlaceholderScreen(icon: Icons.add_a_photo_outlined),
        ),
        if (user.isEngineer)
          const _Tab(label: S.navMeters, icon: Icons.speed_rounded, body: MetersScreen()),
        if (user.isEngineer)
          const _Tab(
            label: S.navReadings,
            icon: Icons.list_alt_rounded,
            body: PlaceholderScreen(icon: Icons.list_alt_rounded),
          )
        else
          const _Tab(label: S.navMyReadings, icon: Icons.history_rounded, body: MyReadingsScreen()),
        const _Tab(
          label: S.navDashboard,
          icon: Icons.dashboard_outlined,
          body: SizedBox.shrink(),
          enabled: false,
        ),
      ];

  void _onSelect(List<_Tab> tabs, int i) {
    if (!tabs[i].enabled) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(S.dashboardComingSoon)));
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user!;
    final tabs = _tabsFor(user);
    final isOnline = context.watch<ConnectivityController>().isOnline;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_index].label),
        actions: [
          StreamBuilder<int>(
            stream: context.read<AppDatabase>().watchPendingCount(),
            builder: (context, snap) {
              final pending = snap.data ?? 0;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Row(
                  children: [
                    if (pending > 0)
                      Container(
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: SyncStatus.pending.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pending ${S.syncPending}',
                          style: TextStyle(color: SyncStatus.pending.color, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    Tooltip(
                      message: isOnline ? S.online : S.offline,
                      child: Icon(
                        isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_rounded,
                        color: isOnline ? SyncStatus.synced.color : scheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) {
              if (v == 'logout') session.signOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(user.fullName, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                    Text(user.role.label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded),
                  title: Text(S.logout),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const StatusBanners(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: tabs.map((t) => t.body).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => _onSelect(tabs, i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: t.enabled ? null : scheme.outline),
              label: t.enabled ? t.label : '${t.label} (${S.comingSoon})',
            ),
        ],
      ),
    );
  }
}
