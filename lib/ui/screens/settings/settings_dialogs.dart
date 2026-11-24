import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../data/local/shared_prefs_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/app_snackbar.dart';

void showSettingsResetDialog(
  BuildContext context, {
  required VoidCallback onResetComplete,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_rounded, color: AppTheme.errorColor),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'تأكيد إعادة التعيين',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.primaryDark),
            ),
          ),
        ],
      ),
      content: const Text(
        'سيتم حذف جميع بيانات التقدم والنقاط. هل أنت متأكد؟',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text(
            'إلغاء',
            style: TextStyle(color: AppTheme.accentDark),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            await SharedPrefsService.resetAllProgress();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (!context.mounted) return;
            AppSnackBar.success(context, 'تم إعادة تعيين جميع البيانات بنجاح');
            onResetComplete();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: const Text('حذف', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

void showSettingsPrivacyPolicyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.privacy_tip_rounded, color: AppTheme.accentColor),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'سياسة الخصوصية وأمان البيانات',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'نحن في تطبيق "معركة أحفاد الصحابة" نلتزم بأعلى معايير حماية خصوصيتك وبياناتك وفق سياسات Google Play:\n\n'
              '1. البيانات المجمعة:\n'
              '• الاسم والبريد الإلكتروني (اختيارياً عند تسجيل الدخول بحساب Google لحفظ تقدمك السحابي فقط).\n'
              '• درجات وإنجازات المسابقة وتصنيفك في لوحة الشرف.\n\n'
              '2. اللعب بدون إنترنت:\n'
              '• التطبيق يعمل بالكامل دون الحاجة لإنترنت في نمط اللعب الفردي والتحدي القريب (Nearby).\n\n'
              '3. مشاركة البيانات:\n'
              '• لا نشارك أي بيانات شخصية مع أطراف ثالثة أو شبكات إعلانية.\n'
              '• جميع الاتصالات السحابية مشفرة ببروتوكول HTTPS/WSS الآمن.\n\n'
              '4. التحكم في بياناتك وحذفها:\n'
              '• يمكنك في أي وقت إعادة تعيين بياناتك محلياً أو حذف حسابك وبياناتك السحابية نهائياً من زر "حذف الحساب والبيانات".',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
          ),
          child: const Text(
            'موافق',
            style: TextStyle(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

void showSettingsDeleteAccountDialog(
  BuildContext context, {
  required VoidCallback onDeleteComplete,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'تأكيد حذف الحساب والبيانات',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'سيتم حذف تقدمك السحابي وتصنيفك في لوحة الشرف وبيانات ملفك الشخصي نهائياً وبلا رجعة. هل أنت متأكد؟',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text(
            'إلغاء',
            style: TextStyle(color: AppTheme.accentDark),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            AppSnackBar.info(context, 'جارٍ حذف الحساب والبيانات...');

            await AuthService().deleteAccountAndData();

            if (context.mounted) {
              AppSnackBar.success(
                context,
                'تم حذف الحساب وجميع البيانات بنجاح',
              );
              onDeleteComplete();
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: const Text(
            'حذف نهائي',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
