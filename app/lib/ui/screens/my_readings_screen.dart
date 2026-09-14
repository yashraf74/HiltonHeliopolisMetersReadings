import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';
import '../../state/sync_controller.dart';
import '../widgets/status_widgets.dart';

/// The current user's own readings from the local database, with their sync
/// state — so a technician can see before leaving whether anything is still
/// waiting to upload, and retry anything that failed.
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
          itemBuilder: (context, i) =>
              _ReadingRow(reading: readings[i], dateFormat: dateFormat),
        );
      },
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading, required this.dateFormat});

  final Reading reading;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final scheme = Theme.of(context).colorScheme;
    final status = SyncStatus.fromDb(reading.syncStatus);
    final photo = reading.localPhotoPath != null
        ? File(reading.localPhotoPath!)
        : null;

    return FutureBuilder<Meter?>(
      future: db.meterById(reading.meterId),
      builder: (context, meterSnap) {
        final meter = meterSnap.data;
        final type = meter != null ? MeterType.fromApi(meter.type) : null;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: photo != null && photo.existsSync()
                            ? Image.file(photo, fit: BoxFit.cover)
                            : Container(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  type?.icon ?? Icons.image_outlined,
                                  color: type?.color ?? scheme.outline,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meter?.location ?? reading.meterId,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${type?.label ?? ''}${meter != null ? ' · ${S.floorLabel} ${meter.floorNumber}' : ''}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            dateFormat.format(
                              DateTime.parse(reading.loggedAt).toLocal(),
                            ),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
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
                          NumberFormat.decimalPattern('en')
                              .format(reading.value),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SyncStatusChip(status),
                      ],
                    ),
                  ],
                ),
                if (status == SyncStatus.failed) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${S.lastErrorLabel}: ${reading.lastError ?? '—'}',
                          style: TextStyle(color: scheme.error, fontSize: 12.5),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            context.read<SyncController>().retry(reading.id),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(S.retrySync),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
