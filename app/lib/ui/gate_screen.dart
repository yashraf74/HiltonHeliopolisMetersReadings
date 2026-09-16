import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/api/api_client.dart';
import '../state/app_status_controller.dart';
import '../state/session_controller.dart';

/// Shown instead of the app when the server says this build is too old, or
/// the app is in maintenance for this role. "Check again" re-reads the
/// server config.
class GateScreen extends StatelessWidget {
  const GateScreen({super.key, required this.upgrade});

  final bool upgrade;

  static const releasesUrl =
      'github.com/yashraf74/HiltonHeliopolisMetersReadings/releases/latest';

  @override
  Widget build(BuildContext context) {
    final status = context.read<AppStatusController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    upgrade
                        ? Icons.system_update_alt_rounded
                        : Icons.engineering_rounded,
                    color: AppColors.accent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  upgrade ? S.updateRequiredTitle : S.maintenanceTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  upgrade ? S.updateRequiredBody : S.maintenanceBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
                if (upgrade) ...[
                  const SizedBox(height: 14),
                  SelectableText(
                    releasesUrl,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${S.currentVersion}: ${status.appVersion}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: scheme.outline, fontSize: 12.5),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () {
                    final session = context.read<SessionController>();
                    status.refresh(
                      context.read<ApiClient>(),
                      isModerator: session.user?.canManage ?? false,
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(S.checkAgain),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
