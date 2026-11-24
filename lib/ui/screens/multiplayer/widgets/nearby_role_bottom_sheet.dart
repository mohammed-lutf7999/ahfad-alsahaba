import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/services/nearby_service.dart';

/// Requests local Bluetooth/Nearby permissions with an explanatory dialog if denied.
Future<bool> requestNearbyPermissionsWithDialog(BuildContext context) async {
  final result = await NearbyService.instance.requestPermissionsDetailed();
  if (result.isGranted) return true;
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'أذونات التقارب المحلي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لتشغيل وضع التحدي المحلي بدون إنترنت، يلزم:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '✓ تفعيل البلوتوث للأجهزة القريبة',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Cairo',
              fontSize: 12,
            ),
          ),
          const Text(
            '✓ السماح بأذونات البحث والمزامنة',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Cairo',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.isPermanentlyDenied
                ? 'تم حظر الأذونات مسبقاً من إعدادات النظام؛ يرجى فتح الإعدادات لتمكينها يدوياً.'
                : 'يمكنك المحاولة مجدداً أو تمكينها من إعدادات التطبيق.',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 11,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'إلغاء',
            style: TextStyle(color: Colors.white60, fontFamily: 'Cairo'),
          ),
        ),
        if (result.isPermanentlyDenied)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            icon: const Icon(Icons.settings_rounded, size: 16),
            label: const Text(
              'فتح الإعدادات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'حسناً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    ),
  );
  return false;
}

/// Shows the offline local Bluetooth challenge role picker bottom sheet (Host vs Guest).
void showNearbyRoleBottomSheet(
  BuildContext context, {
  required VoidCallback onHostSelected,
  required VoidCallback onGuestSelected,
}) {
  SoundService().playClick();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bluetooth_searching_rounded,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تحدي البلوتوث المحلي 📡',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          'تنافس بدون إنترنت مع الأجهزة القريبة',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _LocalOptionCard(
                icon: Icons.add_circle_outline_rounded,
                title: 'إنشاء تحدي جديد (مضيف 👑)',
                subtitle: 'كن القائد وحدد نوع الأسئلة وعددها',
                color: AppTheme.accentColor,
                onTap: () async {
                  Navigator.pop(ctx);
                  final granted =
                      await requestNearbyPermissionsWithDialog(context);
                  if (granted && context.mounted) onHostSelected();
                },
              ),
              const SizedBox(height: 12),
              _LocalOptionCard(
                icon: Icons.search_rounded,
                title: 'البحث عن تحدي والانضمام (ضيف 🔍)',
                subtitle: 'ابحث عن مجالس التحدي المجاورة وشارك فوراً',
                color: const Color(0xFF00E676),
                onTap: () async {
                  Navigator.pop(ctx);
                  final granted =
                      await requestNearbyPermissionsWithDialog(context);
                  if (granted && context.mounted) onGuestSelected();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LocalOptionCard extends StatelessWidget {
  const _LocalOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
