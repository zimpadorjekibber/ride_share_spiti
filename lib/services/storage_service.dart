import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_service.dart';

/// Uploads a local image file to Firebase Storage and returns its download URL.
///
/// Graceful: if Firebase isn't ready, the file is missing, the device is
/// offline, or Storage isn't enabled/permitted, it simply returns the original
/// local path so the app keeps working (the card then shows the local file).
class StorageService {
  /// Upload many photos; returns a list of URLs (or local paths on failure),
  /// preserving order. Already-uploaded URLs are passed through unchanged.
  static Future<List<String>> uploadPhotos(List<String> localPaths, String folder) async {
    final out = <String>[];
    for (final p in localPaths) {
      out.add(await uploadPhoto(p, folder));
    }
    return out;
  }

  static Future<String> uploadPhoto(String localPath, String folder) async {
    if (localPath.isEmpty) return '';
    if (localPath.startsWith('http')) return localPath; // already a URL
    if (!FirebaseService.isInitialized) return localPath;

    final file = File(localPath);
    if (!file.existsSync()) return localPath;

    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}_${localPath.split(Platform.pathSeparator).last}';
      final ref = FirebaseStorage.instance.ref().child('$folder/$name');
      // Timeouts so the save button never hangs forever when offline or on a
      // flaky connection. Both the upload AND the URL fetch are bounded.
      await ref.putFile(file).timeout(const Duration(seconds: 25));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Storage not enabled / no permission / offline / slow → keep local path
      // so the photo still shows on this device and the save completes.
      return localPath;
    }
  }
}
