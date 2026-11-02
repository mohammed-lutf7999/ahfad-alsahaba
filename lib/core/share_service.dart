import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Shares an image (from bytes) with a caption text.
  static Future<void> shareImage(Uint8List imageBytes, String text) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/quiz_result.png').create();
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
      );
    } catch (e) {
      debugPrint('Error sharing image: $e');
    }
  }

  /// Shares valid text only.
  static Future<void> shareText(String text) async {
    await Share.share(text);
  }
}
