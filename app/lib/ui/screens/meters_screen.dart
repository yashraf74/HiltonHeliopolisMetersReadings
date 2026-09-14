import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../state/meters_controller.dart';
import '../widgets/status_widgets.dart';
import 'meter_form_screen.dart';

/// Engineer's meter list from the local cache, with add / edit / retire.
class MetersScreen extends StatelessWidget {
  const MetersScreen({super.key});

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
    return StreamBuilder<List<Meter>>(
      stream: db.watchActiveMeters(),
      builder: (context, snapshot) {
        final meters = snapshot.data ?? const <Meter>[];
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => MeterFormScreen.open(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text(S.addMeter),
          ),
          body: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: meters.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                        icon: Icons.speed_rounded,
                        title: S.noMeters,
                        body: S.noMetersHint,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: meters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => MeterTile(
                      meter: meters[i],
                      onTap: () =>
                          MeterFormScreen.open(context, existing: meters[i]),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class MeterTile extends StatelessWidget {
  const MeterTile({super.key, required this.meter, this.onTap});

  final Meter meter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = MeterType.fromApi(meter.type);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              MeterTypeBadge(type),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meter.location,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${type.label} · ${S.floorLabel} ${meter.floorNumber}'
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
