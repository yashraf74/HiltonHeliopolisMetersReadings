import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../data/api/api_client.dart';
import '../state/session_controller.dart';

// Edit / delete of a server reading, shared by the readings list and the
// dashboard's reading popup. Each shows its own dialog and result snackbar.

double? _parseValue(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final raw = text.trim().replaceAll('٫', '.').replaceAll(',', '.');
  final western = raw.runes.map((c) {
    final i = arabic.indexOf(String.fromCharCode(c));
    return i >= 0 ? '$i' : String.fromCharCode(c);
  }).join();
  return double.tryParse(western);
}

void _showApiError(BuildContext context, ApiException e, String fallback) {
  if (e.isUnauthorized) context.read<SessionController>().markTokenRejected();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message.isEmpty ? fallback : e.message)),
  );
}

/// Asks for a new value and saves it. Returns the new value once saved.
Future<double?> editReadingValue(
  BuildContext context, {
  required String id,
  required num current,
}) async {
  final controller = TextEditingController(text: '$current');
  final value = await showDialog<double>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(S.editReading),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,٠-٩٫]')),
            ],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: S.editReadingHint,
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () {
                final v = _parseValue(controller.text);
                if (v == null) {
                  setLocal(() => error = S.valueInvalid);
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: Text(S.save),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (value == null || !context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<ApiClient>().updateReadingValue(id, value);
    messenger.showSnackBar(SnackBar(content: Text(S.readingUpdated)));
    return value;
  } on NetworkException {
    messenger.showSnackBar(SnackBar(content: Text(S.editNeedsInternet)));
  } on ApiException catch (e) {
    if (context.mounted) _showApiError(context, e, S.editReading);
  }
  return null;
}

/// Confirms, then deletes the reading and its photo. Returns true once done.
Future<bool> deleteReadingConfirmed(BuildContext context, String id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.deleteReading),
      content: Text(S.deleteReadingConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(S.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(S.deleteReading),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<ApiClient>().deleteReading(id);
    messenger.showSnackBar(SnackBar(content: Text(S.readingDeleted)));
    return true;
  } on NetworkException {
    messenger.showSnackBar(SnackBar(content: Text(S.deleteNeedsInternet)));
  } on ApiException catch (e) {
    if (!context.mounted) return false;
    if (e.code == 'delete_disabled') {
      messenger.showSnackBar(SnackBar(content: Text(S.deleteDisabledByAdmin)));
    } else {
      _showApiError(context, e, S.deleteReading);
    }
  }
  return false;
}
