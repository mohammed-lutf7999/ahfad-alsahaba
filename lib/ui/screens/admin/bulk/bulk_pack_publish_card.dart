import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../widgets/admin_ui_kit.dart';

class BulkPackPublishCard extends StatelessWidget {
  final bool isBusy;
  final bool canUpload;
  final String progressLog;
  final VoidCallback onUpload;
  final VoidCallback onSaveConfig;
  final VoidCallback onPublishGzip;

  const BulkPackPublishCard({
    super.key,
    required this.isBusy,
    required this.canUpload,
    required this.progressLog,
    required this.onUpload,
    required this.onSaveConfig,
    required this.onPublishGzip,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return AdminSectionCard(
      title: '3. التنفيذ والنشر السحابي (Gzip CDN)',
      icon: Icons.cloud_upload_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('btn_mobile_bulk_upload'),
              onPressed: (isBusy || !canUpload) ? null : onUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.upload_rounded, size: 19),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'رفع الأسئلة للقاعدة (دفعات 200)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('btn_mobile_save_config'),
              onPressed: isBusy ? null : onSaveConfig,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 19),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'حفظ إعدادات المستويات والنمط للقسم',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('btn_mobile_publish_gzip'),
              onPressed: isBusy ? null : onPublishGzip,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF10B981)),
                foregroundColor: const Color(0xFF34D399),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.archive_rounded, size: 19),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'ضغط ونشر حزمة Gzip CDN للقسم',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (progressLog.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              progressLog,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
