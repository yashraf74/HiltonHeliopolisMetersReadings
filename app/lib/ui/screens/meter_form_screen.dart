import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../state/meters_controller.dart';

/// Add a new meter, or edit / retire an existing one when [existing] is set.
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
  late final TextEditingController _location;
  late final TextEditingController _floor;
  late final TextEditingController _description;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _type = m != null ? MeterType.fromApi(m.type) : MeterType.electricity;
    _location = TextEditingController(text: m?.location ?? '');
    _floor = TextEditingController(text: m?.floorNumber.toString() ?? '');
    _description = TextEditingController(text: m?.description ?? '');
  }

  @override
  void dispose() {
    _location.dispose();
    _floor.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final meters = context.read<MetersController>();
    final location = _location.text.trim();
    final floor = int.parse(_floor.text.trim());
    final description = _description.text.trim();

    final error = _isEdit
        ? await meters.updateMeter(
            widget.existing!.id,
            type: _type,
            location: location,
            floorNumber: floor,
            description: description,
          )
        : await meters.createMeter(
            type: _type,
            location: location,
            floorNumber: floor,
            description: description.isEmpty ? null : description,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? S.meterSaved)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? S.editMeter : S.addMeter),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: S.retireMeter,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
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
                  ChoiceChip(
                    label: Text(t.label),
                    avatar: Icon(
                      t.icon,
                      size: 18,
                      color: _type == t ? Colors.white : t.color,
                    ),
                    selected: _type == t,
                    selectedColor: t.color,
                    labelStyle: TextStyle(
                      color: _type == t ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: _busy ? null : (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _location,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: S.meterLocation,
                hintText: S.meterLocationHint,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? S.fieldRequired : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _floor,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
              ],
              decoration: const InputDecoration(labelText: S.meterFloor),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return S.fieldRequired;
                return int.tryParse(v!.trim()) == null ? S.floorInvalid : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: S.meterDescription,
                hintText: S.meterDescriptionHint,
                alignLabelWithHint: true,
              ),
            ),
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
