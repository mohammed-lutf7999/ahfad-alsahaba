import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/services/cms_cache_service.dart';
import '../../../../data/services/profile_service.dart';
import 'quiz_review_dialog.dart';

class ResultActionButtons extends StatelessWidget {
  final String categoryId;
  final int currentLevelNumber;
  final bool isPassed;
  final bool isSmall;
  final List<Map<String, dynamic>>? userAnswers;

  const ResultActionButtons({
    super.key,
    required this.categoryId,
    required this.currentLevelNumber,
    required this.isPassed,
    required this.isSmall,
    this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final nextRes = CmsCacheService.instance.resolveNextVisibleLevel(
      categoryId,
      currentLevelNumber,
    );
    final nextLevelNumber = nextRes.levelNumber;
    final nextLevelId = nextLevelNumber != null
        ? '${categoryId}_level_$nextLevelNumber'
        : null;
    final currentCanonicalLevelId = '${categoryId}_level_$currentLevelNumber';
    final profile = ProfileService.instance.activeProfile;
    final isNextPlayableUnlocked = nextRes.isPlayable &&
        nextLevelNumber != null &&
        (isPassed ||
            (profile?.isLevelUnlocked(categoryId, nextLevelNumber) ?? false));
    final showNextComingSoon =
        isPassed && nextRes.hasNext && nextRes.isComingSoon;

    return Column(
      children: [
        if (showNextComingSoon) ...[
          InkWell(
            onTap: () {
              SoundService().playClick();
              final msg = nextRes.message.trim().isNotEmpty
                  ? nextRes.message.trim()
                  : 'المستوى ${nextRes.levelNumber} قادم قريباً بإذن الله ⏳';
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      msg,
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: isSmall ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.55),
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: isSmall ? 17 : 19,
                    color: AppTheme.accentDark,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'المستوى القادم قريباً ⏳',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmall ? 12.5 : 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentDark,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isSmall ? 10 : 12),
        ],
        if (userAnswers != null && userAnswers!.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                SoundService().playClick();
                QuizReviewDialog.show(context, userAnswers: userAnswers!);
              },
              icon: Icon(
                Icons.visibility_rounded,
                size: isSmall ? 18 : 20,
                color: AppTheme.accentColor,
              ),
              label: Text(
                'مراجعة الإجابات',
                style: TextStyle(
                  fontSize: isSmall ? 14 : 16,
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isSmall ? 8 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppTheme.accentColor, width: 2),
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          SizedBox(height: isSmall ? 10 : 15),
        ],
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () {
                  SoundService().playClick();
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.levels,
                      arguments: {'categoryId': categoryId},
                    );
                  }
                },
                icon: Icon(
                  Icons.grid_view_rounded,
                  size: isSmall ? 16 : 18,
                  color: AppTheme.accentDark,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'المستويات',
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      color: AppTheme.accentDark,
                      height: 1.2,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: isSmall ? 8 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: AppTheme.accentColor.withAlpha(150),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AppTheme.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withAlpha(80),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    SoundService().playClick();
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.quiz,
                      arguments: {
                        'categoryId': categoryId,
                        'levelId': isNextPlayableUnlocked
                            ? nextLevelId!
                            : currentCanonicalLevelId,
                        'levelNumber': isNextPlayableUnlocked
                            ? nextLevelNumber
                            : currentLevelNumber,
                      },
                    );
                  },
                  icon: Icon(
                    isNextPlayableUnlocked
                        ? Icons.arrow_forward_rounded
                        : Icons.refresh_rounded,
                    size: isSmall ? 16 : 18,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isNextPlayableUnlocked
                          ? 'المستوى التالي'
                          : (isPassed ? 'إعادة المستوى' : 'حاول مرة أخرى'),
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 12.5,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppTheme.primaryDark,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isSmall ? 8 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
