import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';
import '../widgets/status_widgets.dart';
import 'user_form_screen.dart';

/// Engineer-only account management. Server-backed; needs connectivity.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await context.read<ApiClient>().fetchUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } on NetworkException {
      if (!mounted) return;
      setState(() => _error = S.usersNeedInternet);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        context.read<SessionController>().markTokenRejected();
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open({AppUser? existing}) async {
    final changed = await UserFormScreen.open(context, existing: existing);
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionController>().user!;
    final active = _users.where((u) => u.isActive).toList();

    return Scaffold(
      appBar: AppBar(title: const Text(S.manageUsers)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(S.addUser),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  EmptyState(icon: Icons.cloud_off_rounded, title: _error!),
                  Center(
                    child: TextButton(
                      onPressed: _load,
                      child: const Text(S.retry),
                    ),
                  ),
                ],
              )
            : _users.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  EmptyState(icon: Icons.group_outlined, title: S.noUsers),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  for (final u in active)
                    _UserTile(
                      user: u,
                      isMe: u.id == me.id,
                      onTap: () => _open(existing: u),
                    ),
                ],
              ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isMe,
    required this.onTap,
  });

  final AppUser user;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isStaff = user.role != UserRole.technician;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (isStaff ? scheme.primary : scheme.tertiary)
                      .withValues(alpha: 0.14),
                  foregroundColor: isStaff ? scheme.primary : scheme.tertiary,
                  child: Icon(
                    user.role == UserRole.moderator
                        ? Icons.admin_panel_settings_rounded
                        : isStaff
                        ? Icons.engineering_rounded
                        : Icons.build_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${S.you})',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '@${user.username} · ${user.role.label}',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!user.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      S.inactive,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Icon(Icons.chevron_left_rounded, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
