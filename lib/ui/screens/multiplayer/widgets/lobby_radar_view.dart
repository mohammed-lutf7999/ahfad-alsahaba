import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';

class LobbyRadarView extends StatelessWidget {
  final AnimationController radarController;
  final String statusText;
  final bool isSearching;
  final bool hasError;
  final VoidCallback onRetry;
  final VoidCallback onPlayOfflineBot;
  final VoidCallback onExit;

  const LobbyRadarView({
    super.key,
    required this.radarController,
    required this.statusText,
    required this.isSearching,
    required this.hasError,
    required this.onRetry,
    required this.onPlayOfflineBot,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 680;
        final radarSize = isCompactHeight ? 220.0 : 300.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  (constraints.maxHeight - 32).clamp(0.0, double.infinity),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'تحدي مباشر',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isCompactHeight ? 24 : 40),
                SizedBox(
                  height: radarSize,
                  width: radarSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(3, (index) {
                        return AnimatedBuilder(
                          animation: radarController,
                          builder: (context, child) {
                            final progress =
                                (radarController.value + (index * 0.33)) % 1.0;
                            return Opacity(
                              opacity: 1.0 - progress,
                              child: Container(
                                width: radarSize * progress,
                                height: radarSize * progress,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.accentColor
                                        .withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentColor,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.accentColor.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.search,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompactHeight ? 24 : 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              SoundService().playClick();
                              onRetry();
                            },
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: AppTheme.primaryDark,
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'إعادة المحاولة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark,
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: onPlayOfflineBot,
                            icon: const Icon(
                              Icons.smart_toy_rounded,
                              color: Colors.white,
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'تحدي الذكاء الاصطناعي 🤖',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              side:
                                  const BorderSide(color: AppTheme.accentColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            SoundService().playClick();
                            onExit();
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white70,
                          ),
                          label: const Text(
                            'العودة للرئيسية',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isSearching)
                  TextButton.icon(
                    onPressed: () {
                      SoundService().playClick();
                      onExit();
                    },
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    label: const Text(
                      'إلغاء',
                      style: TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
