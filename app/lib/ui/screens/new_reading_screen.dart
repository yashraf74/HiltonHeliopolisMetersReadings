import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/strings.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../state/connectivity_controller.dart';
import '../../state/session_controller.dart';
import '../../state/sync_controller.dart';
import '../widgets/status_widgets.dart';
import 'meters_screen.dart';

/// Three-step flow: meter type → meter → photo + value. The reading is
/// written to the local database the moment "save" is tapped, whatever the
/// connectivity, and the sync engine takes it from there.
const maxPhotoBytes = 3 * 1024 * 1024;

class NewReadingScreen extends StatefulWidget {
  const NewReadingScreen({super.key});

  @override
  State<NewReadingScreen> createState() => _NewReadingScreenState();
}

class _NewReadingScreenState extends State<NewReadingScreen> {
  int _step = 0;
  MeterType? _type;
  Meter? _meter;
  File? _photo;
  final _value = TextEditingController();
  final _search = TextEditingController();
  String? _valueError;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    _search.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _step = 0;
      _type = null;
      _meter = null;
      _photo = null;
      _value.clear();
      _search.clear();
      _valueError = null;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return;
      final file = File(picked.path);
      // Mirrors the server's 3 MB cap; the picker's downscaling normally
      // lands far below this, so hitting it means something unusual.
      if (await file.length() > maxPhotoBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(S.photoTooLarge)));
        return;
      }
      setState(() => _photo = file);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(S.photoUnavailable)));
    }
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

    final id = const Uuid().v4();
    // Move the photo into app storage so it survives the picker's temp dir
    // being cleared before the sync engine gets to it.
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'photos'),
    );
    await dir.create(recursive: true);
    final ext = p.extension(_photo!.path).isEmpty
        ? '.jpg'
        : p.extension(_photo!.path);
    final stored = await _photo!.copy(p.join(dir.path, '$id$ext'));

    await db.insertReading(
      ReadingsCompanion.insert(
        id: id,
        meterId: _meter!.id,
        value: value,
        localPhotoPath: Value(stored.path),
        loggedBy: user.id,
        loggedByName: user.fullName,
        loggedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    sync.sync();

    if (!mounted) return;
    setState(() => _saving = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          color: SyncStatus.synced.color,
          size: 44,
        ),
        title: Text(online ? S.readingSavedOnline : S.readingSaved),
        content: Text(
          '${_meter!.location} · ${NumberFormat.decimalPattern('en').format(value)}',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(S.newReadingAgain),
          ),
        ],
      ),
    );
    _reset();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step -= 1);
      },
      child: Column(
        children: [
          _StepHeader(
            step: _step,
            onBack: _step == 0 ? null : () => setState(() => _step -= 1),
          ),
          Expanded(
            child: switch (_step) {
              0 => _buildTypeStep(),
              1 => _buildMeterStep(),
              _ => _buildDetailsStep(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final t in MeterType.values) ...[
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() {
                _type = t;
                _meter = null;
                _step = 1;
              }),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    MeterTypeBadge(t),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        t.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMeterStep() {
    final db = context.read<AppDatabase>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: S.searchMeters,
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
          child: StreamBuilder<List<Meter>>(
            stream: db.watchActiveMeters(type: _type!.name),
            builder: (context, snapshot) {
              final q = _search.text.trim();
              final meters = (snapshot.data ?? const <Meter>[])
                  .where(
                    (m) =>
                        q.isEmpty ||
                        m.location.contains(q) ||
                        (m.description ?? '').contains(q) ||
                        m.floorNumber.toString() == _toWesternDigits(q),
                  )
                  .toList();
              if (meters.isEmpty) {
                return EmptyState(
                  icon: _type!.icon,
                  title: S.noMetersOfType,
                  body: snapshot.data?.isEmpty ?? true
                      ? S.noMetersHintTechnician
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: meters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => MeterTile(
                  meter: meters[i],
                  onTap: () => setState(() {
                    _meter = meters[i];
                    _step = 2;
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    final user = context.read<SessionController>().user!;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        MeterTile(meter: _meter!),
        const SizedBox(height: 20),
        Text(S.photo, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text(S.retakePhoto),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text(S.pickFromGallery),
                ),
              ),
            ],
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _PhotoButton(
                  icon: Icons.photo_camera_rounded,
                  label: S.takePhoto,
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoButton(
                  icon: Icons.photo_library_rounded,
                  label: S.pickFromGallery,
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
        const SizedBox(height: 22),
        TextField(
          controller: _value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
          onChanged: (_) =>
              _valueError == null ? null : setState(() => _valueError = null),
          decoration: InputDecoration(
            labelText: S.readingValue,
            hintText: S.valueHint,
            errorText: _valueError,
            prefixIcon: Icon(_type!.icon, color: _type!.color),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${S.willBeLoggedAs} ${user.fullName} · ${DateFormat('d/M/yyyy HH:mm', 'ar').format(DateTime.now())}',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
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
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, this.onBack});

  final int step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    const titles = [S.stepType, S.stepMeter, S.stepDetails];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: S.back,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[step],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= step
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 4),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(
            children: [
              Icon(icon, size: 34, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
