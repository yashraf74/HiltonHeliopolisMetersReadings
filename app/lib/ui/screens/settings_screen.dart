import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../state/app_status_controller.dart';
import '../../state/session_controller.dart';
import '../widgets/status_widgets.dart';

/// Moderator-only runtime switches, stored server-side (KV). Every switch
/// is enforced by the API; the app only mirrors it.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minVersion = TextEditingController();
  final _retention = TextEditingController();
  final _tokenDays = TextEditingController();
  final _prices = {
    for (final t in MeterType.values) t: TextEditingController(),
  };
  bool _maintenance = false;
  bool _deleteEnabled = true;
  bool _exportEnabled = true;
  bool _profileEditing = true;
  ExportSettings _export = const ExportSettings();
  String? _latestVersion;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static final _versionRe = RegExp(r'^\d+(\.\d+){0,2}$');

  /// Everything the form holds, to spot edits when leaving.
  String get _current =>
      '$_maintenance|$_deleteEnabled|$_exportEnabled|$_profileEditing|'
      '${_minVersion.text}|${_retention.text}|${_tokenDays.text}|'
      '${jsonEncode(_export.toJson())}|'
      '${[for (final t in MeterType.values) _prices[t]!.text].join(',')}';
  String _saved = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _minVersion.dispose();
    _retention.dispose();
    _tokenDays.dispose();
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(AppSettings s) {
    _snapshotAfterBuild();
    for (final c in [_minVersion, _retention, _tokenDays, ..._prices.values]) {
      c.removeListener(_onFieldChanged);
      c.addListener(_onFieldChanged);
    }
    _minVersion.text = s.minAppVersion;
    _retention.text = '${s.photoRetentionDays}';
    _tokenDays.text = '${s.tokenLifetimeDays}';
    _maintenance = s.maintenanceMode;
    _deleteEnabled = s.readingDeleteEnabled;
    _exportEnabled = s.exportEnabled;
    _profileEditing = s.profileEditingEnabled;
    _export = s.export;
    _latestVersion = s.latestAppVersion ?? _latestVersion;
    for (final t in MeterType.values) {
      final p = s.prices[t] ?? 0;
      _prices[t]!.text = p == p.roundToDouble() ? '${p.toInt()}' : '$p';
    }
  }

  /// The controllers are written to during _apply; snapshot once that and
  /// the rebuild are done.
  void _snapshotAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _saved = _current);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await context.read<ApiClient>().fetchSettings();
      if (!mounted) return;
      setState(() => _apply(s));
    } on NetworkException {
      if (mounted) setState(() => _error = S.settingsNeedInternet);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_export.columns.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.exportAtLeastOneColumn)));
      return;
    }
    setState(() => _saving = true);
    final api = context.read<ApiClient>();
    final status = context.read<AppStatusController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final saved = await api.saveSettings(
        AppSettings(
          minAppVersion: _minVersion.text.trim(),
          maintenanceMode: _maintenance,
          readingDeleteEnabled: _deleteEnabled,
          exportEnabled: _exportEnabled,
          photoRetentionDays: int.parse(_retention.text.trim()),
          tokenLifetimeDays: int.parse(_tokenDays.text.trim()),
          profileEditingEnabled: _profileEditing,
          export: _export,
          prices: {
            for (final t in MeterType.values)
              t: double.parse(_prices[t]!.text.trim()),
          },
        ),
      );
      if (!mounted) return;
      setState(() => _apply(saved));
      await status.refresh(api, isModerator: true);
      messenger.showSnackBar(SnackBar(content: Text(S.settingsSaved)));
      // Saved: back to where the user came from.
      if (mounted) navigator.pop();
    } on NetworkException {
      messenger.showSnackBar(SnackBar(content: Text(S.settingsNeedInternet)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = context.read<AppStatusController>().appVersion;
    return UnsavedChangesGuard(
      dirty: !_loading && _error == null && _current != _saved,
      onSave: _save,
      child: Scaffold(
        appBar: AppBar(title: Text(S.appSettings)),
        // Sticky, so the save button is always in reach on a long form.
        bottomNavigationBar: _loading || _error != null
            ? null
            : StickySaveBar(saving: _saving, onSave: _save),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Column(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(icon: Icons.cloud_off_rounded, title: _error!),
                  TextButton(onPressed: _load, child: Text(S.retry)),
                ],
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        S.settingMaintenance,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        S.settingMaintenanceHint,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                      value: _maintenance,
                      activeThumbColor: scheme.error,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _maintenance = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        S.settingDeleteEnabled,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      value: _deleteEnabled,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _deleteEnabled = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        S.settingExportEnabled,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      value: _exportEnabled,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _exportEnabled = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        S.settingProfileEditing,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        S.settingProfileEditingHint,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                      value: _profileEditing,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _profileEditing = v),
                    ),
                    const Divider(height: 32),
                    _ExportSection(
                      settings: _export,
                      enabled: !_saving,
                      onChanged: (v) => setState(() => _export = v),
                    ),
                    const Divider(height: 32),
                    TextFormField(
                      controller: _minVersion,
                      textDirection: TextDirection.ltr,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      contextMenuBuilder: appContextMenuBuilder,
                      decoration: InputDecoration(
                        labelText: S.settingMinVersion,
                        helperText: [
                          S.settingMinVersionHint,
                          if (_latestVersion != null)
                            '${S.latestVersion}: $_latestVersion',
                          '${S.thisDeviceVersion}: $version',
                        ].join(' · '),
                        helperMaxLines: 2,
                      ),
                      validator: (v) => _versionRe.hasMatch((v ?? '').trim())
                          ? null
                          : S.versionInvalid,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _retention,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      contextMenuBuilder: appContextMenuBuilder,
                      decoration: InputDecoration(
                        labelText: S.settingRetention,
                        helperText: S.settingRetentionHint,
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return n == null || n < 7 || n > 3650
                            ? S.retentionInvalid
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tokenDays,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      contextMenuBuilder: appContextMenuBuilder,
                      decoration: InputDecoration(
                        labelText: S.settingTokenLifetime,
                        helperText: S.settingTokenLifetimeHint,
                        helperMaxLines: 2,
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return n == null || n < 1 || n > 365
                            ? S.tokenLifetimeInvalid
                            : null;
                      },
                    ),
                    const Divider(height: 40),
                    Text(
                      S.settingPrices,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.settingPricesHint,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final t in MeterType.values) ...[
                      TextFormField(
                        controller: _prices[t],
                        textDirection: TextDirection.ltr,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        contextMenuBuilder: appContextMenuBuilder,
                        decoration: InputDecoration(
                          labelText: '${t.label} (${S.currency} / ${t.unit})',
                          prefixIcon: Icon(t.icon, color: t.color),
                        ),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').trim());
                          return n == null || n < 0 || n > 100000
                              ? S.priceInvalid
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// Excel export options: which columns, in what order, the sheet direction,
/// date and number formats, and one sheet per meter type.
class _ExportSection extends StatelessWidget {
  const _ExportSection({
    required this.settings,
    required this.enabled,
    required this.onChanged,
  });

  final ExportSettings settings;
  final bool enabled;
  final ValueChanged<ExportSettings> onChanged;

  /// Selected columns first (in export order), then the unselected ones.
  List<ExportColumn> get _ordered => [
    ...settings.columns,
    ...ExportColumn.values.where((c) => !settings.columns.contains(c)),
  ];

  void _toggle(ExportColumn column, bool selected) {
    final columns = [...settings.columns];
    if (selected) {
      columns.add(column);
    } else {
      columns.remove(column);
    }
    onChanged(settings.copyWith(columns: columns));
  }

  void _reorder(int oldIndex, int newIndex) {
    final ordered = _ordered;
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    // Keep the selected ones only, in their new order.
    onChanged(
      settings.copyWith(
        columns: ordered.where(settings.columns.contains).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.settingExport,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(S.settingExportHint, style: muted),
        const SizedBox(height: 14),
        Text(
          S.exportColumns,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(S.exportColumnsHint, style: muted),
        const SizedBox(height: 4),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: _reorder,
          children: [
            for (final (i, column) in _ordered.indexed)
              CheckboxListTile(
                key: ValueKey(column),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: settings.columns.contains(column),
                onChanged: enabled ? (v) => _toggle(column, v ?? false) : null,
                title: Text(column.label),
                secondary: ReorderableDragStartListener(
                  index: i,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          S.exportDirection,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SegmentedButton<ExportDirection>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity(horizontal: -2, vertical: -2),
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontFamily: 'Cairo'),
            ),
          ),
          segments: [
            ButtonSegment(
              value: ExportDirection.auto,
              label: Text(S.exportDirectionAuto),
            ),
            ButtonSegment(
              value: ExportDirection.rtl,
              label: Text(S.exportDirectionRtl),
            ),
            ButtonSegment(
              value: ExportDirection.ltr,
              label: Text(S.exportDirectionLtr),
            ),
          ],
          selected: {settings.direction},
          onSelectionChanged: enabled
              ? (s) => onChanged(settings.copyWith(direction: s.first))
              : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: settings.dateFormat,
          decoration: InputDecoration(labelText: S.exportDateFormat),
          items: [
            for (final f in ExportSettings.dateFormats)
              DropdownMenuItem(
                value: f,
                child: Text(f, textDirection: TextDirection.ltr),
              ),
          ],
          onChanged: enabled
              ? (v) => onChanged(settings.copyWith(dateFormat: v))
              : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: settings.decimals,
          decoration: InputDecoration(labelText: S.exportDecimals),
          items: [
            for (var d = 0; d <= 3; d++)
              DropdownMenuItem(
                value: d,
                child: Text(
                  d == 0 ? '0' : '0.${'0' * d}',
                  textDirection: TextDirection.ltr,
                ),
              ),
          ],
          onChanged: enabled
              ? (v) => onChanged(settings.copyWith(decimals: v))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(S.exportThousands),
          value: settings.thousandsSeparator,
          onChanged: enabled
              ? (v) => onChanged(settings.copyWith(thousandsSeparator: v))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(S.exportSheetPerType),
          subtitle: Text(S.exportSheetPerTypeHint, style: muted),
          value: settings.sheetPerType,
          onChanged: enabled
              ? (v) => onChanged(settings.copyWith(sheetPerType: v))
              : null,
        ),
      ],
    );
  }
}
