import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../state/meters_controller.dart';
import '../widgets/status_widgets.dart';
import 'meter_form_screen.dart';

/// Engineer's meter list from the local cache, filterable by type, with
/// add / edit / retire. Reference photos show only here.
class MetersScreen extends StatefulWidget {
  const MetersScreen({super.key});

  @override
  State<MetersScreen> createState() => _MetersScreenState();
}

class _MetersScreenState extends State<MetersScreen> {
  MeterType? _filter;

  Future<void> _refresh(BuildContext context) async {
    final ok = await context.read<MetersController>().refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? S.metersRefreshed : S.metersRefreshFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => MeterFormScreen.open(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(S.addMeter),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text(S.filterAll),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final t in MeterType.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(t.label),
                    avatar: Icon(
                      t.icon,
                      size: 18,
                      color: _filter == t ? Colors.white : t.color,
                    ),
                    selected: _filter == t,
                    selectedColor: t.color,
                    labelStyle: TextStyle(
                      color: _filter == t ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _filter = t),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Meter>>(
              stream: db.watchActiveMeters(type: _filter?.name),
              builder: (context, snapshot) {
                final meters = snapshot.data ?? const <Meter>[];
                return RefreshIndicator(
                  onRefresh: () => _refresh(context),
                  child: meters.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 100),
                            EmptyState(
                              icon: _filter?.icon ?? Icons.speed_rounded,
                              title: _filter == null
                                  ? S.noMeters
                                  : S.noMetersForFilter,
                              body: _filter == null ? S.noMetersHint : null,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: meters.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => MeterTile(
                            meter: meters[i],
                            showPhoto: true,
                            onTap: () => MeterFormScreen.open(
                              context,
                              existing: meters[i],
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared meter row. [showPhoto] renders the engineer's reference photo in
/// place of the type badge; it is false everywhere except the meters tab so
/// the reading flow and readings lists never show it.
class MeterTile extends StatelessWidget {
  const MeterTile({
    super.key,
    required this.meter,
    this.onTap,
    this.showPhoto = false,
  });

  final Meter meter;
  final VoidCallback? onTap;
  final bool showPhoto;

  @override
  Widget build(BuildContext context) {
    final type = MeterType.fromApi(meter.type);
    final scheme = Theme.of(context).colorScheme;
    final photoKey = showPhoto ? meter.photoKey : null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (photoKey != null)
                _MeterThumb(photoKey: photoKey, type: type)
              else
                MeterTypeBadge(type),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meter.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${meter.location} · ${type.label} · ${S.floorLabel} ${meter.floorNumber}'
                      '${meter.description?.isNotEmpty == true ? ' · ${meter.description}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_left_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeterThumb extends StatelessWidget {
  const _MeterThumb({required this.photoKey, required this.type});

  final String photoKey;
  final MeterType type;

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              api.photoUri(photoKey).toString(),
              headers: api.authHeaders,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => MeterTypeBadge(type),
            ),
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: type.color,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(8),
                  ),
                ),
                child: Icon(type.icon, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
