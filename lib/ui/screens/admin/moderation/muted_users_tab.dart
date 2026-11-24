import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import 'diwan_reports_tab.dart';

class MutedUsersTab extends StatelessWidget {
  final List<AdminMutedUser> mutedUsers;
  final void Function(String targetUserId) onUnmuteUser;

  const MutedUsersTab({
    super.key,
    required this.mutedUsers,
    required this.onUnmuteUser,
  });

  @override
  Widget build(BuildContext context) {
    if (mutedUsers.isEmpty) {
      return const ModerationEmptyState(
        icon: Icons.speaker_notes_rounded,
        title: 'لا يوجد لاعبون مكتومون 🕊️',
        subtitle: 'ديوان الأحفاد هادئ ولا يوجد أي لاعب مقيد بالكتم حالياً.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: mutedUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final u = mutedUsers[index];
        final remaining = u.mutedUntil != null
            ? u.mutedUntil!.difference(DateTime.now().toUtc())
            : Duration.zero;
        final hoursLeft = remaining.inHours;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                AppCustomTheme.of(context).surfaceCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.amberAccent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.volume_off_rounded,
                  color: Colors.amberAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.displayName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'كود: ${u.playerCode ?? u.userId.substring(0, 8)} • متبقي: ${hoursLeft > 0 ? "$hoursLeft ساعة" : "أقل من ساعة"}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white60,
                        fontSize: 11.5,
                      ),
                    ),
                    if (u.reason.isNotEmpty)
                      Text(
                        'السبب: ${u.reason}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.amberAccent,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: Key('unmute_user_btn_${u.userId}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: () => onUnmuteUser(u.userId),
                icon: const Icon(Icons.volume_up_rounded, size: 16),
                label: const Text(
                  'فك الكتم',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
