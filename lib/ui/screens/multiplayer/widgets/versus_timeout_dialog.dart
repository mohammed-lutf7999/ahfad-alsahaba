import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../data/models/player_level_model.dart';
import '../../../../data/services/app_control_service.dart';
import '../../../../data/services/multiplayer_service.dart';
import '../../../../data/services/profile_service.dart';
import '../versus_screen.dart';

/// Launches a Ghost or Local AI fallback match when an online opponent disconnects on [VersusScreen].
Future<void> launchVersusAiOrGhostFallback(BuildContext context) async {
  final profile = ProfileService.instance.activeProfile;
  if (AppControlService.instance.featureFlagsNotifier.value.ghostMatches) {
    try {
      final ghostResult = await MultiplayerService.instance
          .findOrCreateGhostMatch(trophies: profile?.trophies ?? 1000)
          .timeout(const Duration(seconds: 4));
      if (ghostResult.success &&
          ghostResult.matchId != null &&
          context.mounted) {
        if (ghostResult.isHumanMatch) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => VersusScreen(
                matchId: ghostResult.matchId!,
                opponentId: ghostResult.ghostUserId ?? '',
                seed: ghostResult.seed ?? 1000,
                isFriendly: ghostResult.isFriendly,
                questionIds: ghostResult.questionIds,
              ),
            ),
          );
          return;
        }
        final ghostLevel = ghostResult.ghostLevel ?? 5;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VersusScreen(
              matchId: ghostResult.matchId!,
              opponentId: ghostResult.ghostUserId ??
                  'ghost_${DateTime.now().millisecondsSinceEpoch}',
              seed: ghostResult.seed ?? 1000,
              isGhost: true,
              isFriendly: ghostResult.isFriendly,
              ghostTimeline: ghostResult.timeline,
              initialOpponentData: {
                'display_name': ghostResult.ghostName ?? 'فارس الأندلس',
                'avatar_index': ghostResult.ghostAvatarIndex ?? 0,
                'equipped_frame': ghostResult.ghostFrame ?? 'frame_wood',
                'player_level': ghostLevel,
                'trophies': ghostResult.ghostTrophies ?? 1000,
                'score': PlayerLevelInfo.cumulativeXpForLevel(ghostLevel),
              },
              questionIds: ghostResult.questionIds,
            ),
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Versus timeout ghost fallback failed: $e');
    }
  }

  final botResult = await MultiplayerService.instance.createBotMatch();
  if (!context.mounted) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => VersusScreen(
        matchId: botResult.matchId!,
        opponentId: botResult.opponentId!,
        seed: botResult.seed!,
        isBot: true,
        questionIds: botResult.questionIds,
      ),
    ),
  );
}

/// Shows the 15-second opponent timeout dialog with an instant AI/Ghost fallback action.
void showVersusOpponentTimeoutDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.primaryDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'الخصم غير متصل',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: const Text(
        'يبدو أن الخصم غادر الغرفة أو فقد الاتصال بالإنترنت.\nهل ترغب في بدء جولة فورية ضد الذكاء الاصطناعي؟',
        style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop();
          },
          child: const Text(
            'العودة',
            style: TextStyle(color: Colors.white60, fontFamily: 'Cairo'),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            foregroundColor: AppTheme.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () {
            Navigator.of(ctx).pop();
            unawaited(launchVersusAiOrGhostFallback(context));
          },
          icon: const Icon(Icons.smart_toy_rounded),
          label: const Text(
            'تحدي الذكاء الاصطناعي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
