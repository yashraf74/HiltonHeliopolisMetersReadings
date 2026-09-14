import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';
import '../widgets/status_widgets.dart';

/// The current user's own readings from the local database, with their sync
/// state — so a technician can see before leaving whether anything is still
/// waiting to upload.
class MyReadingsScreen extends StatelessWidget {
  const MyReadingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final userId = context.watch<SessionController>().user?.id ?? '';
    final dateFormat = DateFormat('d/M/yyyy · HH:mm', 'ar');

    return StreamBuilder<List<Reading>>(
      stream: db.watchReadingsBy(userId),
      builder: (context, snapshot) {
        final readings = snapshot.data ?? const <Reading>[];
        if (readings.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: S.noReadings,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: readings.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = readings[i];
            return FutureBuilder<Meter?>(
              future: db.meterById(r.meterId),
              builder: (context, meterSnap) {
                final meter = meterSnap.data;
                final type = meter != null
                    ? MeterType.fromApi(meter.type)
                    : null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        if (type != null) MeterTypeBadge(type, compact: true),
                        if (type != null) const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meter?.location ?? r.meterId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                dateFormat.format(
                                  DateTime.parse(r.loggedAt).toLocal(),
                                ),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              NumberFormat.decimalPattern('en').format(r.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SyncStatusChip(SyncStatus.fromDb(r.syncStatus)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
