import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../state/meters_controller.dart';
import '../widgets/photo_picker.dart';
import '../widgets/status_widgets.dart';

/// Add a new meter, or edit / delete an existing one when [existing] is set.
/// The optional reference photo is uploaded on save (moderator-only).
class MeterFormScreen extends StatefulWidget {
  const MeterFormScreen({super.key, this.existing});

  final Meter? existing;

  static Future<void> open(BuildContext context, {Meter? existing}) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MeterFormScreen(existing: existing)),
      );

  @override
  State<MeterFormScreen> createState() => _MeterFormScreenState();
}

class _MeterFormScreenState extends State<MeterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late MeterType _type;
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _number;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _todoOrder;
  late final TextEditingController _exportOrder;
  bool _busy = false;

  // Photo state: an existing server key, a newly picked file, or a request
  // to clear. `_newPhoto` wins over `_photoKey`; `_removePhoto` clears both.
  String? _photoKey;
  File? _newPhoto;
  bool _removePhoto = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _type = m != null ? MeterType.fromApi(m.type) : MeterType.electricity;
    _name = TextEditingController(text: m?.name ?? '');
    _area = TextEditingController(text: m?.area ?? '');
    _number = TextEditingController(text: m?.number ?? '');
    _location = TextEditingController(text: m?.location ?? '');
    _description = TextEditingController(text: m?.description ?? '');
    _todoOrder = TextEditingController(text: m?.todoOrder?.toString() ?? '');
    _exportOrder = TextEditingController(
      text: m?.exportOrder?.toString() ?? '',
    );
    _photoKey = m?.photoKey;
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _number.dispose();
    _location.dispose();
    _description.dispose();
    _todoOrder.dispose();
    _exportOrder.dispose();
    super.dispose();
  }

  int? _orderValue(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final meters = context.read<MetersController>();
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final area = _area.text.trim();
    final number = _number.text.trim();
    final location = _location.text.trim();
    final description = _description.text.trim();
    final todoOrder = _orderValue(_todoOrder);
    final exportOrder = _orderValue(_exportOrder);

    String? error;
    String? uploadedKey;
    try {
      if (_newPhoto != null) {
        uploadedKey = await api.uploadPhoto(
          await _newPhoto!.readAsBytes(),
          contentType: contentTypeForPath(_newPhoto!.path),
          forMeter: true,
        );
      }
    } on NetworkException {
      error = S.onlineRequired;
    } on ApiException catch (e) {
      error = e.message;
    }

    error ??= _isEdit
        ? await meters.updateMeter(
            widget.existing!.id,
            type: _type,
            name: name,
            area: area,
            number: number.isEmpty ? null : number,
            location: location,
            description: description,
            photoKey: uploadedKey,
            clearPhoto: _removePhoto && uploadedKey == null,
            todoOrder: todoOrder,
            exportOrder: exportOrder,
          )
        : await meters.createMeter(
            type: _type,
            name: name,
            area: area,
            number: number.isEmpty ? null : number,
            location: location,
            description: description.isEmpty ? null : description,
            photoKey: uploadedKey,
            todoOrder: todoOrder,
            exportOrder: exportOrder,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(error ?? S.meterSaved)));
    if (error == null) Navigator.of(context).pop();
  }

  Future<void> _retire() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.retireMeter),
        content: const Text(S.retireMeterConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(S.retireMeter),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final error = await context.read<MetersController>().retireMeter(
      widget.existing!.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? S.meterRetired)));
    if (error == null) Navigator.of(context).pop();
  }

  Widget _buildPhotoSection(BuildContext context) {
    final api = context.read<ApiClient>();
    final scheme = Theme.of(context).colorScheme;
    final showExisting =
        _photoKey != null && !_removePhoto && _newPhoto == null;
    final hasAny = showExisting || _newPhoto != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.meterPhoto, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          S.meterPhotoHint,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        if (hasAny) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _newPhoto != null
                  ? Image.file(_newPhoto!, fit: BoxFit.cover)
                  : Image.network(
                      api.photoUri(_photoKey!).toString(),
                      headers: api.authHeaders,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: scheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Text(
                          S.photoLoadFailed,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          PhotoSourceButtons(
            compact: true,
            onPicked: (f) => setState(() => _newPhoto = f),
          ),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _newPhoto = null;
                    _removePhoto = true;
                  }),
            icon: Icon(
              Icons.hide_image_outlined,
              size: 18,
              color: scheme.error,
            ),
            label: Text(S.removePhoto, style: TextStyle(color: scheme.error)),
          ),
        ] else
          PhotoSourceButtons(
            compact: true,
            onPicked: (f) => setState(() {
              _newPhoto = f;
              _removePhoto = false;
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? S.editMeter : S.addMeter),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: S.retireMeter,
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              onPressed: _busy ? null : _retire,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              S.meterType,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in MeterType.values)
                  TypeChip(
                    type: t,
                    selected: _type == t,
                    onSelected: (_) => _busy ? null : setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              contextMenuBuilder: appContextMenuBuilder,
              decoration: const InputDecoration(
                labelText: S.meterName,
                hintText: S.meterNameHint,
                counterText: '',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? S.fieldRequired : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _area,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              contextMenuBuilder: appContextMenuBuilder,
              decoration: const InputDecoration(
                labelText: S.meterArea,
                hintText: S.meterAreaHint,
                counterText: '',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? S.fieldRequired : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _number,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              textDirection: TextDirection.ltr,
              contextMenuBuilder: appContextMenuBuilder,
              decoration: const InputDecoration(
                labelText: S.meterNumber,
                hintText: S.meterNumberHint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _location,
              textInputAction: TextInputAction.next,
              contextMenuBuilder: appContextMenuBuilder,
              decoration: const InputDecoration(
                labelText: S.meterLocation,
                hintText: S.meterLocationHint,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? S.fieldRequired : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              contextMenuBuilder: appContextMenuBuilder,
              decoration: const InputDecoration(
                labelText: S.meterDescription,
                hintText: S.meterDescriptionHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              S.moderatorOnlyFields,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _todoOrder,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    contextMenuBuilder: appContextMenuBuilder,
                    decoration: const InputDecoration(labelText: S.todoOrder),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _exportOrder,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    contextMenuBuilder: appContextMenuBuilder,
                    decoration: const InputDecoration(labelText: S.exportOrder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${S.todoOrderHint}\n${S.exportOrderHint}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _buildPhotoSection(context),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
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
