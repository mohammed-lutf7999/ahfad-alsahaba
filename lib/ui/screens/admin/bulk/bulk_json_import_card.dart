import 'package:flutter/material.dart';

import '../../../../data/services/admin/bulk_question_json_validator.dart';
import '../widgets/admin_ui_kit.dart';

class BulkJsonImportCard extends StatelessWidget {
  final bool isBusy;
  final String sourceLabel;
  final BulkQuestionValidationResult? validation;
  final VoidCallback onPickFile;
  final VoidCallback onPasteClipboard;

  const BulkJsonImportCard({
    super.key,
    required this.isBusy,
    required this.sourceLabel,
    required this.validation,
    required this.onPickFile,
    required this.onPasteClipboard,
  });

  @override
  Widget build(BuildContext context) {
    final val = validation;
    return AdminSectionCard(
      title: '2. تحميل وفحص ملف الأسئلة (JSON فقط)',
      icon: Icons.upload_file_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                key: const Key('btn_pick_json_file'),
                onPressed: isBusy ? null : onPickFile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text(
                  'اختيار ملف JSON',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('btn_paste_json_clipboard'),
                onPressed: isBusy ? null : onPasteClipboard,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text(
                  'لصق من الحافظة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                ),
              ),
            ],
          ),
          if (sourceLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sourceLabel,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
          if (val != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: val.isValid
                      ? const Color(0xFF10B981).withValues(alpha: 0.6)
                      : Colors.redAccent.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    val.isValid
                        ? '✅ جاهز للرفع: ${val.normalizedQuestions.length} سؤالاً عبر ${val.distinctLevelsCount} مستوى (أعلى مستوى: ${val.maxLevel})'
                        : '❌ يوجد ${val.errors.length} خطأ يمنع الرفع:',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: val.isValid
                          ? const Color(0xFF34D399)
                          : Colors.redAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  for (final err in val.errors.take(6))
                    Text(
                      '• $err',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                  if (val.warnings.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '⚠️ تنبيهات (${val.warnings.length}): ${val.warnings.take(2).join(' | ')}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.amberAccent,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
