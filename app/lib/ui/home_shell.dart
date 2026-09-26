import 'dart:async';

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
import '../state/app_events.dart';
import '../state/language_controller.dart';
import 'screens/about_screen.dart';
import 'screens/profile_screen.dart';
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
  // Held from initState: providers can't be looked up during dispose.
  late final AppEvents _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = context.read<AppEvents>();
    _events.addListener(_onAppEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events.removeListener(_onAppEvent);
    super.dispose();
  }

  /// Another screen asked to show the dashboard (the export warning).
  void _onAppEvent() {
    if (!_events.wantsDashboard) return;
    final tabs = _tabsFor(context.read<SessionController>().user!);
    final index = tabs.indexWhere((t) => t.body is DashboardScreen);
    if (index >= 0 && index != _index) setState(() => _index = index);
  }

  void _refreshAll() {
    final session = context.read<SessionController>();
    final api = context.read<ApiClient>();
    context.read<MetersController>().refresh();
    context.read<SyncController>().sync();
    context.read<AppStatusController>().refresh(
      api,
      isModerator: session.user?.canManage ?? false,
    );
    _refreshProfile(api, session);
  }

  /// Picks up a photo, email or mobile number a moderator changed since this
  /// device signed in, so the account icon and profile page stay right.
  Future<void> _refreshProfile(ApiClient api, SessionController session) async {
    try {
      final me = await api.fetchMe();
      await session.updateProfile(
        email: me.email,
        phone: me.phone,
        photoKey: me.photoKey,
      );
    } on NetworkException {
      // Offline: keep what sign-in stored.
    } on ApiException {
      // Signed out or rejected: handled by the request that matters.
    }
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
    _Tab(
      label: S.navNewReading,
      icon: Icons.add_circle_outline_rounded,
      body: NewReadingScreen(),
    ),
    if (user.canManage)
      _Tab(label: S.navMeters, icon: Icons.speed_rounded, body: MetersScreen()),
    _Tab(
      label: S.navReadings,
      icon: Icons.list_alt_rounded,
      body: ReadingsScreen(),
    ),
    if (user.canSeeDashboard)
      _Tab(
        label: S.navDashboard,
        icon: Icons.dashboard_outlined,
        body: DashboardScreen(),
      ),
  ];

  /// Switches language after the menu has closed, behind a brief loading
  /// overlay (at least half a second) so the change never happens under the
  /// user's finger.
  Future<void> _switchLanguage(BuildContext context) async {
    final language = context.read<LanguageController>();
    final api = context.read<ApiClient>();
    final target = S.isEnglish ? AppLanguage.ar : AppLanguage.en;
    final navigator = Navigator.of(context, rootNavigator: true);
    // Let the popup menu finish closing first.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!context.mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Theme.of(context).colorScheme.surface,
        builder: (_) => const _LanguageSplash(),
      ),
    );
    await Future.wait([
      language.choose(target, api: api),
      Future<void>.delayed(const Duration(milliseconds: 500)),
    ]);
    navigator.pop();
  }

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
                        SnackBar(content: Text(S.syncAllDone)),
                      );
                      return;
                    }
                    // Always try: the offline flag can be stale, and a real
                    // request is the only reliable test.
                    messenger.showSnackBar(
                      SnackBar(content: Text(S.syncStarted)),
                    );
                    final synced = await sync.sync();
                    if (synced == 0 && !sync.isRunning) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(S.syncFailedCheckConnection)),
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
          // Keeps the avatar off the screen edge.
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            padding: const EdgeInsetsDirectional.only(end: 8),
            icon: _AccountIcon(photoKey: user.photoKey),
            onSelected: (v) {
              switch (v) {
                case 'settings':
                  SettingsScreen.open(context);
                case 'users':
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const UsersScreen()))
                  // Accounts may have changed: the readings filter list
                  // (which hides some users) reloads.
                  .then((_) {
                    if (context.mounted) {
                      context.read<AppEvents>().usersChanged();
                    }
                  });
                case 'profile':
                  ProfileScreen.open(context);
                case 'about':
                  AboutScreen.open(context);
                case 'language':
                  _switchLanguage(context);
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
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.tune_rounded),
                    title: Text(S.appSettings),
                  ),
                ),
                PopupMenuItem(
                  value: 'users',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.group_outlined),
                    title: Text(S.manageUsers),
                  ),
                ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(S.aboutApp),
                ),
              ),
              if (context
                  .read<AppStatusController>()
                  .config
                  .profileEditingEnabled)
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(S.myProfile),
                  ),
                ),
              PopupMenuItem(
                value: 'language',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(S.switchLanguage),
                ),
              ),
              PopupMenuItem(
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

/// The account button: the user's photo when they have one.
class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.photoKey});

  final String? photoKey;

  @override
  Widget build(BuildContext context) {
    final key = photoKey;
    if (key == null) return const Icon(Icons.account_circle_outlined);
    final api = context.read<ApiClient>();
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 15,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: NetworkImage(
        api.photoUri(key).toString(),
        headers: api.authHeaders,
      ),
      onForegroundImageError: (_, _) {},
      child: Icon(
        Icons.account_circle_outlined,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}

/// Shown while the language changes. [Material] gives the text the app's
/// styling; bare text on a dialog barrier gets Flutter's yellow-underlined
/// fallback instead.
class _LanguageSplash extends StatelessWidget {
  const _LanguageSplash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                S.changingLanguage,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
