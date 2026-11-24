import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// Reads a `.json` file via `FileType.any` (Android 11–16 SAF compatible so
/// WhatsApp/Telegram JSON files are never grayed out).
Future<({String? rawText, String? label, String? error})>
    pickBulkJsonFileSource() async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );
  if (picked == null || picked.files.isEmpty) {
    return (rawText: null, label: null, error: null);
  }
  final file = picked.files.first;
  if (!file.name.toLowerCase().endsWith('.json')) {
    return (
      rawText: null,
      label: null,
      error: 'يرجى اختيار ملف بامتداد .json فقط (الملف المختار: ${file.name}).',
    );
  }
  if (file.bytes != null) {
    return (
      rawText: utf8.decode(file.bytes!),
      label: 'ملف: ${file.name}',
      error: null,
    );
  }
  if (file.path != null && file.path!.isNotEmpty) {
    final text = await File(file.path!).readAsString();
    return (rawText: text, label: 'ملف: ${file.name}', error: null);
  }
  return (rawText: null, label: null, error: 'تعذر قراءة محتوى الملف.');
}

Future<({String? rawText, String? label, String? error})>
    readBulkJsonClipboardSource() async {
  final data = await Clipboard.getData('text/plain');
  final text = data?.text?.trim() ?? '';
  if (text.isEmpty) {
    return (
      rawText: null,
      label: null,
      error: 'الحافظة فارغة — انسخ نص JSON أولاً.',
    );
  }
  return (
    rawText: text,
    label: 'نص من الحافظة (${text.length} حرف)',
    error: null,
  );
}
