import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings.dart';

const maxPhotoBytes = 3 * 1024 * 1024;

/// Opens the camera or gallery, downscales the result, and enforces the
/// same 3 MB cap the server applies. Returns null if cancelled or rejected
/// (a snackbar explains why).
Future<File?> pickAppPhoto(BuildContext context, ImageSource source) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return null;
    final file = File(picked.path);
    if (await file.length() > maxPhotoBytes) {
      messenger.showSnackBar(const SnackBar(content: Text(S.photoTooLarge)));
      return null;
    }
    return file;
  } on PlatformException {
    messenger.showSnackBar(const SnackBar(content: Text(S.photoUnavailable)));
    return null;
  }
}

String contentTypeForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Two large tap targets: camera and gallery.
class PhotoSourceButtons extends StatelessWidget {
  const PhotoSourceButtons({
    super.key,
    required this.onPicked,
    this.compact = false,
  });

  final ValueChanged<File> onPicked;
  final bool compact;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final file = await pickAppPhoto(context, source);
    if (file != null) onPicked(file);
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text(S.takePhoto),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text(S.pickFromGallery),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _BigButton(
            icon: Icons.photo_camera_rounded,
            label: S.takePhoto,
            onTap: () => _pick(context, ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigButton(
            icon: Icons.photo_library_rounded,
            label: S.pickFromGallery,
            onTap: () => _pick(context, ImageSource.gallery),
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
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
