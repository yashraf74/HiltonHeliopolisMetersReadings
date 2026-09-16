import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/strings.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../data/photo_store.dart';
import '../../state/connectivity_controller.dart';
import '../../state/meters_controller.dart';
import '../../state/session_controller.dart';
import '../../state/sync_controller.dart';
import '../widgets/photo_picker.dart';
import '../widgets/status_widgets.dart';
import 'meters_screen.dart';

/// Daily to-do list of meters. A meter counts as "done today" when the
/// server's newest reading for it (by anyone) or a reading still queued on
/// this device falls on today's calendar day. Meters not yet done come
/// first, then by the moderator's to-do order (unset last), then by name.
/// Tapping a meter opens the photo + value step; the reading is saved
/// locally the moment "save" is tapped.
class NewReadingScreen extends StatefulWidget {
  const NewReadingScreen({super.key});

  @override
  State<NewReadingScreen> createState() => _NewReadingScreenState();
}

class _NewReadingScreenState extends State<NewReadingScreen> {
  MeterType? _filter;
  final _search = TextEditingController();
  Meter? _meter;
  File? _photo;
  final _value = TextEditingController();
  String? _valueError;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    _value.dispose();
    super.dispose();
  }

  void _backToList() {
    setState(() {
      _meter = null;
      _photo = null;
      _value.clear();
      _valueError = null;
    });
  }

  static bool _isToday(String? iso) {
    if (iso == null) return false;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  static String _toWesternDigits(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final i = arabic.indexOf(String.fromCharCode(ch));
      buf.write(i >= 0 ? i.toString() : String.fromCharCode(ch));
    }
    return buf.toString();
  }

  Future<void> _save() async {
    final raw = _value.text.trim().replaceAll('٫', '.').replaceAll(',', '.');
    final value = double.tryParse(_toWesternDigits(raw));
    if (_photo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(S.photoRequired)));
      return;
    }
    if (raw.isEmpty) {
      setState(() => _valueError = S.valueRequired);
      return;
    }
    if (value == null) {
      setState(() => _valueError = S.valueInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _valueError = null;
    });

    final db = context.read<AppDatabase>();
    final user = context.read<SessionController>().user!;
    final sync = context.read<SyncController>();
    final online = context.read<ConnectivityController>().isOnline;
    final meter = _meter!;
    final type = MeterType.fromApi(meter.type);

    final id = const Uuid().v4();
    final storedPath = await PhotoStore.store(_photo!, id);
    await db.insertReading(
      ReadingsCompanion.insert(
        id: id,
        meterId: meter.id,
        value: value,
        localPhotoPath: Value(storedPath),
        loggedBy: user.id,
        loggedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    sync.sync();

    if (!mounted) return;
    setState(() => _saving = false);
    await _showSavedPopup(
      title: online ? S.readingSavedOnline : S.readingSaved,
      detail:
          '${meter.name} · ${NumberFormat.decimalPattern('en').format(value)} ${type.unit}',
    );
    _backToList();
  }

  /// Brief confirmation: closes itself after two seconds, or on any tap.
  Future<void> _showSavedPopup({
    required String title,
    required String detail,
  }) async {
    var closed = false;
    Timer? timer;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        timer = Timer(const Duration(seconds: 2), () {
          if (!closed && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(ctx).pop(),
          child: AlertDialog(
            icon: Icon(
              Icons.check_circle_rounded,
              color: SyncStatus.synced.color,
              size: 44,
            ),
            title: Text(title, textAlign: TextAlign.center),
            content: Text(
              detail,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      },
    );
    closed = true;
    timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final meter = _meter;
    return PopScope(
      canPop: meter == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToList();
      },
      child: meter == null ? _buildList() : _buildDetails(meter),
    );
  }

  // ---- step 1: the daily list ---------------------------------------------

  Widget _buildList() {
    final db = context.read<AppDatabase>();
    final userId = context.read<SessionController>().user!.id;
    final scheme = Theme.of(context).colorScheme;

    return Column(
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
                TypeChip(
                  type: t,
                  selected: _filter == t,
                  onSelected: (_) => setState(() => _filter = t),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            contextMenuBuilder: appContextMenuBuilder,
            decoration: InputDecoration(
              hintText: S.searchMeters,
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Reading>>(
            stream: db.watchQueue(userId),
            builder: (context, queueSnap) {
              final queuedToday = <String>{
                for (final r in queueSnap.data ?? const <Reading>[])
                  if (_isToday(r.loggedAt)) r.meterId,
              };
              return StreamBuilder<List<Meter>>(
                stream: db.watchActiveMeters(type: _filter?.name),
                builder: (context, snapshot) {
                  final all = snapshot.data ?? const <Meter>[];
                  bool done(Meter m) =>
                      queuedToday.contains(m.id) || _isToday(m.lastLoggedAt);
                  final q = _search.text.trim();
                  final meters =
                      all
                          .where(
                            (m) =>
                                q.isEmpty ||
                                m.name.contains(q) ||
                                m.area.contains(q) ||
                                (m.number ?? '').contains(q) ||
                                m.location.contains(q) ||
                                (m.description ?? '').contains(q),
                          )
                          .toList()
                        ..sort((a, b) {
                          final d = (done(a) ? 1 : 0) - (done(b) ? 1 : 0);
                          if (d != 0) return d;
                          final oa = a.todoOrder ?? 1 << 30;
                          final ob = b.todoOrder ?? 1 << 30;
                          if (oa != ob) return oa - ob;
                          return a.name.toLowerCase().compareTo(
                            b.name.toLowerCase(),
                          );
                        });
                  final doneCount = all.where(done).length;

                  return RefreshIndicator(
                    onRefresh: () => context.read<MetersController>().refresh(),
                    child: meters.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 100),
                              EmptyState(
                                icon: _filter?.icon ?? Icons.speed_rounded,
                                title: all.isEmpty
                                    ? S.noMeters
                                    : S.noMetersForFilter,
                                body: all.isEmpty
                                    ? S.noMetersHintTechnician
                                    : null,
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: meters.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                final allDone =
                                    all.isNotEmpty && doneCount == all.length;
                                return Row(
                                  children: [
                                    Icon(
                                      allDone
                                          ? Icons.task_alt_rounded
                                          : Icons.today_rounded,
                                      size: 18,
                                      color: allDone
                                          ? SyncStatus.synced.color
                                          : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        allDone
                                            ? S.allDoneToday
                                            : S.todoProgress
                                                  .replaceFirst(
                                                    '{done}',
                                                    '$doneCount',
                                                  )
                                                  .replaceFirst(
                                                    '{total}',
                                                    '${all.length}',
                                                  ),
                                        style: TextStyle(
                                          color: allDone
                                              ? SyncStatus.synced.color
                                              : scheme.onSurfaceVariant,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              final m = meters[i - 1];
                              return MeterTile(
                                meter: m,
                                doneToday: done(m),
                                onTap: () => setState(() => _meter = m),
                              );
                            },
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- step 2: photo + value ----------------------------------------------

  Widget _buildDetails(Meter meter) {
    final user = context.read<SessionController>().user!;
    final scheme = Theme.of(context).colorScheme;
    final type = MeterType.fromApi(meter.type);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _backToList,
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: S.back,
              ),
              const Expanded(
                child: Text(
                  S.stepDetails,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              MeterTile(meter: meter),
              const SizedBox(height: 20),
              Text(
                S.photo,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (_photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(_photo!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
                PhotoSourceButtons(
                  compact: true,
                  onPicked: (f) => setState(() => _photo = f),
                ),
              ] else
                PhotoSourceButtons(onPicked: (f) => setState(() => _photo = f)),
              const SizedBox(height: 22),
              TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                contextMenuBuilder: appContextMenuBuilder,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
                onChanged: (_) => _valueError == null
                    ? null
                    : setState(() => _valueError = null),
                decoration: InputDecoration(
                  labelText: S.readingValue,
                  hintText: S.valueHint,
                  errorText: _valueError,
                  prefixIcon: Icon(type.icon, color: type.color),
                  suffixText: type.unit,
                  suffixStyle: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${S.willBeLoggedAs} ${user.fullName} · ${DateFormat('d/M/yyyy HH:mm', 'ar').format(DateTime.now())}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text(S.saveReading),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
