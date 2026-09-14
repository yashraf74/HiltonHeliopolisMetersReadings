import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where reading photos live on the device, and how stored paths resolve.
///
/// Paths are stored relative to the app documents directory ("photos/x.jpg")
/// because on iOS the absolute container path changes whenever the app is
/// reinstalled or updated — an absolute path saved today may not exist
/// tomorrow even though the file does.
class PhotoStore {
  PhotoStore._();

  static const _folder = 'photos';

  static Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, _folder));
    await d.create(recursive: true);
    return d;
  }

  /// Copies [source] into the store and returns the relative path to save.
  static Future<String> store(File source, String id) async {
    final ext = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path);
    final target = p.join((await dir()).path, '$id$ext');
    await source.copy(target);
    return '$_folder/$id$ext';
  }

  /// Resolves a stored path (relative, or a legacy absolute one) to a file
  /// that exists, or null if the photo is gone.
  static Future<File?> resolve(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    if (p.isAbsolute(stored)) {
      final direct = File(stored);
      if (await direct.exists()) return direct;
      // Legacy absolute path from a previous container: try by file name.
      stored = '$_folder/${p.basename(stored)}';
    }
    final base = await getApplicationDocumentsDirectory();
    final file = File(p.join(base.path, stored));
    return await file.exists() ? file : null;
  }
}
