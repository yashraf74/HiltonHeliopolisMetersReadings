import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings.dart';
import 'status_widgets.dart';

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
      messenger.showSnackBar(SnackBar(content: Text(S.photoTooLarge)));
      return null;
    }
    return file;
  } on PlatformException {
    messenger.showSnackBar(SnackBar(content: Text(S.photoUnavailable)));
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
              label: Text(S.takePhoto),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(S.pickFromGallery),
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

/// Round photo preview with camera / gallery buttons and "remove", shared by
/// the moderator's user form and the user's own profile page so both look
/// and behave the same. Tapping the photo opens it full size.
class UserPhotoField extends StatelessWidget {
  const UserPhotoField({
    super.key,
    required this.image,
    required this.onPicked,
    required this.onRemoved,
    this.enabled = true,
  });

  final ImageProvider? image;
  final ValueChanged<File> onPicked;
  final VoidCallback onRemoved;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = image;
    final avatar = CircleAvatar(
      radius: 44,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: photo,
      child: Icon(
        Icons.person_rounded,
        size: 44,
        color: scheme.onPrimaryContainer,
      ),
    );
    return Column(
      children: [
        if (photo == null)
          avatar
        else
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PhotoViewerScreen(image: photo),
                fullscreenDialog: true,
              ),
            ),
            child: avatar,
          ),
        const SizedBox(height: 6),
        Text(
          S.userPhoto,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        PhotoSourceButtons(compact: true, onPicked: onPicked),
        if (photo != null)
          TextButton.icon(
            onPressed: enabled ? onRemoved : null,
            icon: Icon(
              Icons.hide_image_outlined,
              size: 18,
              color: scheme.error,
            ),
            label: Text(S.removePhoto, style: TextStyle(color: scheme.error)),
          ),
      ],
    );
  }
}
