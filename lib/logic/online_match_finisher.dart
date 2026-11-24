import 'dart:async';

import '../data/services/achievement_service.dart';
import '../data/services/ghost_playback_service.dart';
import '../data/services/guild_service.dart';
import '../data/services/multiplayer_service.dart';
import '../data/services/profile_service.dart';
import '../data/services/progression_service.dart';

/// Encapsulates the final resolved match outcome to hand off to UI celebrations/dialogs.
class OnlineMatchFinishSummary {
  const OnlineMatchFinishSummary({
    required this.winnerId,
    required this.isWinner,
    required this.isDraw,
    required this.myScore,
    required this.opponentScore,
    required this.preSnapshot,
    required this.trophiesDelta,
    required this.totalTrophies,
    required this.coinsEarned,
    required this.shieldConsumed,
    required this.xpBannerConsumed,
  });

  final String? winnerId;
  final bool isWinner;
  final bool isDraw;
  final int myScore;
  final int opponentScore;
  final ProgressionSnapshot? preSnapshot;
  final int? trophiesDelta;
  final int? totalTrophies;
  final int coinsEarned;
  final bool shieldConsumed;
  final bool xpBannerConsumed;
}

/// Resolves online/ghost/bot match completion, progression, guild contribution, and achievements.
class OnlineMatchFinisher {
  static Future<OnlineMatchFinishSummary> finalize({
    required String matchId,
    required String opponentId,
    required bool isBot,
    required bool isGhost,
    required bool isFriendly,
    required bool enableSideEffects,
    required int myScore,
    required int opponentScore,
    required int myCorrectAnswersCount,
    required List<Map<String, dynamic>> myAnswerTimelines,
    required List<Map<String, dynamic>>? ghostTimeline,
  }) async {
    int finalMyScore = myScore;
    int finalOppScore = opponentScore;
    String? winnerId;
    int? trophiesDelta;
    int? totalTrophies;
    final myId =
        enableSideEffects ? MultiplayerService.instance.currentUserId : 'local';

    if (isBot || !enableSideEffects) {
      if (finalMyScore > finalOppScore) {
        winnerId = myId;
      } else if (finalOppScore > finalMyScore) {
        winnerId = opponentId;
      }
    } else {
      if (opponentId.isNotEmpty) {
        MultiplayerService.instance.lastOpponentId = opponentId;
      }
      final result = await MultiplayerService.instance.finishMatch(matchId);
      finalOppScore =
          (result['opponentScore'] as num?)?.toInt() ?? finalOppScore;
      if (isGhost && result['opponentScore'] == null && ghostTimeline != null) {
        finalOppScore = ghostTimeline.fold<int>(
          0,
          (acc, rec) => acc + GhostPlaybackService.computeScoreForRecord(rec),
        );
      }
      finalMyScore = (result['myScore'] as num?)?.toInt() ?? finalMyScore;
      winnerId = result['winnerId'] as String?;
      trophiesDelta = result['trophiesDelta'] as int?;
      totalTrophies = result['totalTrophies'] as int?;

      if (myAnswerTimelines.length == 5) {
        unawaited(
          MultiplayerService.instance.saveGhostTimeline(
            matchId: matchId,
            timeline: myAnswerTimelines,
          ),
        );
      }
    }

    final isWinner = winnerId != null
        ? (winnerId == myId)
        : (finalMyScore > finalOppScore);
    final isDraw = (winnerId == null && finalMyScore == finalOppScore) ||
        (!isWinner && finalMyScore == finalOppScore);

    ProgressionSnapshot? preSnapshot;
    int coinsEarned = 0;
    bool shieldConsumed = false;
    bool xpBannerConsumed = false;
    int? finalTrophiesDelta = trophiesDelta;
    int? finalTotalTrophies = totalTrophies;

    if (enableSideEffects) {
      preSnapshot = ProgressionService.instance.captureSnapshot();
      final outcome = ProgressionService.instance.applyMatchOutcome(
        rawMatchScore: finalMyScore,
        correctAnswers: myCorrectAnswersCount,
        isWin: isWinner,
        isDraw: isDraw,
        serverTotalTrophies: isFriendly ? null : totalTrophies,
        serverTrophiesDelta: isFriendly ? 0 : trophiesDelta,
        updateTrophies: !isFriendly,
      );
      finalTrophiesDelta = outcome.trophiesDelta;
      finalTotalTrophies =
          ProfileService.instance.activeProfile?.trophies ?? totalTrophies;
      coinsEarned = outcome.coinsEarned;
      shieldConsumed = outcome.shieldConsumed;
      xpBannerConsumed = outcome.xpBannerConsumed;

      await ProfileService.instance.saveActiveProfileAndSync();
      if (finalMyScore > 0) {
        unawaited(GuildService.instance.contributeScore(finalMyScore));
      }
      await AchievementService.instance.reconcileAchievements();
    }

    return OnlineMatchFinishSummary(
      winnerId: winnerId,
      isWinner: isWinner,
      isDraw: isDraw,
      myScore: finalMyScore,
      opponentScore: finalOppScore,
      preSnapshot: preSnapshot,
      trophiesDelta: finalTrophiesDelta,
      totalTrophies: finalTotalTrophies,
      coinsEarned: coinsEarned,
      shieldConsumed: shieldConsumed,
      xpBannerConsumed: xpBannerConsumed,
    );
  }
}
