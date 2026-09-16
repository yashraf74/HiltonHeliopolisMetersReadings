import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../data/api/api_client.dart';
import '../data/db/database.dart';
import '../data/models.dart';
import '../state/app_status_controller.dart';
import '../state/connectivity_controller.dart';
import '../state/meters_controller.dart';
import '../state/session_controller.dart';
import '../state/sync_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/meters_screen.dart';
import 'screens/new_reading_screen.dart';
import 'screens/readings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/users_screen.dart';
import 'widgets/status_widgets.dart';

class _Tab {
  const _Tab({required this.label, required this.icon, required this.body});

  final String label;
  final IconData icon;
  final Widget body;
}

/// Role-based navigation. Moderator-only admin screens (settings, users)
/// live in the account menu rather than the dock.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refreshAll() {
    final session = context.read<SessionController>();
    context.read<MetersController>().refresh();
    context.read<SyncController>().sync();
    context.read<AppStatusController>().refresh(
      context.read<ApiClient>(),
      isModerator: session.user?.canManage ?? false,
    );
  }

  // Coming back to the foreground is the moment connectivity most often
  // changed without us hearing about it; re-check and drain the queue.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<ConnectivityController>().recheck();
    _refreshAll();
  }

  List<_Tab> _tabsFor(AuthUser user) => [
    const _Tab(
      label: S.navNewReading,
      icon: Icons.add_circle_outline_rounded,
      body: NewReadingScreen(),
    ),
    if (user.canManage)
      const _Tab(
        label: S.navMeters,
        icon: Icons.speed_rounded,
        body: MetersScreen(),
      ),
    const _Tab(
      label: S.navReadings,
      icon: Icons.list_alt_rounded,
      body: ReadingsScreen(),
    ),
    if (user.canSeeDashboard)
      const _Tab(
        label: S.navDashboard,
        icon: Icons.dashboard_outlined,
        body: DashboardScreen(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user!;
    final tabs = _tabsFor(user);
    if (_index >= tabs.length) _index = 0;
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
              final syncing = context.watch<SyncController>().isRunning;
              return Tooltip(
                message: S.syncNow,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final sync = context.read<SyncController>();
                    if (pending == 0) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text(S.syncAllDone)),
                      );
                      return;
                    }
                    // Always try: the offline flag can be stale, and a real
                    // request is the only reliable test.
                    messenger.showSnackBar(
                      const SnackBar(content: Text(S.syncStarted)),
                    );
                    final synced = await sync.sync();
                    if (synced == 0 && !sync.isRunning) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(S.syncFailedCheckConnection),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        if (pending > 0)
                          Container(
                            margin: const EdgeInsetsDirectional.only(end: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SyncStatus.pending.color.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$pending ${S.syncPending}',
                              style: TextStyle(
                                color: SyncStatus.pending.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (syncing)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            isOnline
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_rounded,
                            color: isOnline
                                ? SyncStatus.synced.color
                                : scheme.outline,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) {
              switch (v) {
                case 'settings':
                  SettingsScreen.open(context);
                case 'users':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UsersScreen()),
                  );
                case 'logout':
                  session.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      user.role.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (user.canManage) ...[
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.tune_rounded),
                    title: Text(S.appSettings),
                  ),
                ),
                const PopupMenuItem(
                  value: 'users',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.group_outlined),
                    title: Text(S.manageUsers),
                  ),
                ),
                const PopupMenuDivider(),
              ],
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
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
