import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';

class QuizErrorView extends StatelessWidget {
  final Gradient backgroundGradient;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const QuizErrorView({
    super.key,
    required this.backgroundGradient,
    required this.errorMessage,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.accentColor, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage ?? 'تعذّر تحميل أسئلة هذا المستوى',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              SoundService().playClick();
                              onRetry();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'إعادة المحاولة',
                                style: TextStyle(height: 1.2),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              SoundService().playClick();
                              onBack();
                            },
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'العودة',
                                style: TextStyle(height: 1.2),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showQuizWarningToast(BuildContext context) {
  SoundService().playAlert();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 2),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'تبقت لك محاولة واحدة!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showQuizGameOverDialog(
  BuildContext context, {
  required VoidCallback onRetry,
  required VoidCallback onExit,
}) {
  SoundService().playDefeat();
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (ctx, anim1, anim2) {
      return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double dialogWidth =
                (constraints.maxWidth * 0.88).clamp(0.0, 380.0);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim1,
                    curve: Curves.elasticOut,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: dialogWidth,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF311B92), Color(0xFF673AB7)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF9575CD),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF311B92)
                                .withValues(alpha: 0.6),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 1.0, end: 0.5),
                            duration: const Duration(seconds: 1),
                            builder: (context, value, child) =>
                                Opacity(opacity: value, child: child),
                            child: const Text(
                              'حسرت المسابقة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'هل ترغب في إعادة المحاولة؟',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFFFFD700),
                              height: 1.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    onRetry();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7E57C2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 8,
                                    shadowColor: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.4),
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'إعادة المحاولة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    onExit();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFF210857),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF9575CD),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'خروج',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
