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
  bool _maintenance = false;
  bool _deleteEnabled = true;
  bool _exportEnabled = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static final _versionRe = RegExp(r'^\d+(\.\d+){0,2}$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _minVersion.dispose();
    _retention.dispose();
    super.dispose();
  }

  void _apply(AppSettings s) {
    _minVersion.text = s.minAppVersion;
    _retention.text = '${s.photoRetentionDays}';
    _maintenance = s.maintenanceMode;
    _deleteEnabled = s.readingDeleteEnabled;
    _exportEnabled = s.exportEnabled;
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
    setState(() => _saving = true);
    final api = context.read<ApiClient>();
    final status = context.read<AppStatusController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await api.saveSettings(
        AppSettings(
          minAppVersion: _minVersion.text.trim(),
          maintenanceMode: _maintenance,
          readingDeleteEnabled: _deleteEnabled,
          exportEnabled: _exportEnabled,
          photoRetentionDays: int.parse(_retention.text.trim()),
        ),
      );
      if (!mounted) return;
      setState(() => _apply(saved));
      await status.refresh(api, isModerator: true);
      messenger.showSnackBar(const SnackBar(content: Text(S.settingsSaved)));
    } on NetworkException {
      messenger.showSnackBar(
        const SnackBar(content: Text(S.settingsNeedInternet)),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text(S.appSettings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Column(
              children: [
                const SizedBox(height: 80),
                EmptyState(icon: Icons.cloud_off_rounded, title: _error!),
                TextButton(onPressed: _load, child: const Text(S.retry)),
              ],
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
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
                    title: const Text(
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
                    title: const Text(
                      S.settingExportEnabled,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: _exportEnabled,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _exportEnabled = v),
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
                      helperText:
                          '${S.settingMinVersionHint} · ${S.currentVersion}: $version',
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
                    decoration: const InputDecoration(
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
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(S.save),
                  ),
                ],
              ),
            ),
    );
  }
}
