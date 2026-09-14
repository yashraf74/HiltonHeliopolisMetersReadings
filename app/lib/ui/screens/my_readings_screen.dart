import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../data/photo_store.dart';
import '../../state/session_controller.dart';
import '../../state/sync_controller.dart';
import '../widgets/status_widgets.dart';

/// The current user's own readings from the local database, with their sync
/// state. Each row expands to the same detail layout the engineer sees:
/// meter details, the attached photo, and notes when present.
class MyReadingsScreen extends StatelessWidget {
  const MyReadingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final userId = context.watch<SessionController>().user?.id ?? '';

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
          itemBuilder: (context, i) => _LocalReadingCard(reading: readings[i]),
        );
      },
    );
  }
}

class _LocalReadingCard extends StatelessWidget {
  const _LocalReadingCard({required this.reading});

  final Reading reading;

  Future<(Meter?, File?)> _load(AppDatabase db) async => (
    await db.meterById(reading.meterId),
    await PhotoStore.resolve(reading.localPhotoPath),
  );

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final api = context.read<ApiClient>();
    final userName = context.read<SessionController>().user?.fullName ?? '';
    final scheme = Theme.of(context).colorScheme;
    final status = SyncStatus.fromDb(reading.syncStatus);
    final fmt = DateFormat('d/M/yyyy · HH:mm', 'ar');
    final loggedAt = DateTime.parse(reading.loggedAt).toLocal();
    final syncedAt = reading.syncedAt != null
        ? DateTime.parse(reading.syncedAt!).toLocal()
        : null;
    final value = NumberFormat.decimalPattern('en').format(reading.value);

    return FutureBuilder<(Meter?, File?)>(
      future: _load(db),
      builder: (context, snap) {
        final meter = snap.data?.$1;
        final photo = snap.data?.$2;
        final type = meter != null ? MeterType.fromApi(meter.type) : null;

        // Local file first; once synced, the server copy is the fallback
        // (e.g. after an iOS reinstall moved the app container).
        Widget photoWidget({required Widget placeholder}) {
          if (photo != null) return Image.file(photo, fit: BoxFit.cover);
          if (reading.photoKey != null) {
            return Image.network(
              api.photoUri(reading.photoKey!).toString(),
              headers: api.authHeaders,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            );
          }
          return placeholder;
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: type == null
                  ? const SizedBox(width: 44, height: 44)
                  : PhotoThumb(
                      type: type,
                      image: photo != null
                          ? FileImage(photo)
                          : reading.photoKey != null
                          ? NetworkImage(
                              api.photoUri(reading.photoKey!).toString(),
                              headers: api.authHeaders,
                            )
                          : null,
                    ),
              title: Text(
                meter?.name ?? reading.meterId,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                fmt.format(loggedAt),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SyncStatusChip(status),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (type != null) DetailRow(S.meterType, type.label),
                      if (meter != null)
                        DetailRow(S.meterLocation, meter.location),
                      if (meter != null)
                        DetailRow(S.meterFloor, '${meter.floorNumber}'),
                      if (meter?.description?.isNotEmpty == true)
                        DetailRow(S.meterDescription, meter!.description!),
                      DetailRow(S.loggedBy, userName),
                      DetailRow(S.loggedAt, fmt.format(loggedAt)),
                      if (syncedAt != null)
                        DetailRow(S.syncedAtLabel, fmt.format(syncedAt)),
                      DetailRow(S.readingId, reading.id, mono: true),
                      NotesBlock(reading.notes),
                      if (status == SyncStatus.failed) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${S.lastErrorLabel}: ${reading.lastError ?? '—'}',
                                style: TextStyle(
                                  color: scheme.error,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => context
                                  .read<SyncController>()
                                  .retry(reading.id),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(S.retrySync),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: photoWidget(
                            placeholder: Container(
                              color: scheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: Text(
                                S.photoLoadFailed,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
