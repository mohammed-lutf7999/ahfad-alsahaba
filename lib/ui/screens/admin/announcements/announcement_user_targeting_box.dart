import 'package:flutter/material.dart';

import '../../../../core/sound_service.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';

class AnnouncementUserTargetingBox extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController manualPlayerCodeController;
  final bool isSearching;
  final List<AdminPlayerSearchResult> searchResults;
  final AdminPlayerSearchResult? selectedPlayer;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<String> onManualCodeChanged;
  final ValueChanged<AdminPlayerSearchResult> onSelectPlayer;
  final VoidCallback onClearSelectedPlayer;

  const AnnouncementUserTargetingBox({
    super.key,
    required this.searchController,
    required this.manualPlayerCodeController,
    required this.isSearching,
    required this.searchResults,
    required this.selectedPlayer,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onManualCodeChanged,
    required this.onSelectPlayer,
    required this.onClearSelectedPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: customTheme.sovereignAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminTextField(
            key: const Key('admin_user_search_field'),
            controller: searchController,
            label: 'ابحث بالاسم أو البريد أو كود الضيف (SAH-XXXX)',
            onChanged: onSearchChanged,
            suffixIcon: IconButton(
              icon: isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              onPressed: onSearchSubmitted,
            ),
          ),
          const SizedBox(height: 8),
          AdminTextField(
            controller: manualPlayerCodeController,
            label: 'أو أدخل كود اللاعب يدوياً (اختياري)',
            hint: 'SAH-XXXX',
            onChanged: onManualCodeChanged,
          ),
          if (selectedPlayer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'المستهدف: ${selectedPlayer!.displayName}'
                      '${selectedPlayer!.playerCode != null ? ' (${selectedPlayer!.playerCode})' : ''}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                    onPressed: onClearSelectedPlayer,
                  ),
                ],
              ),
            ),
          ],
          if (searchResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...searchResults.map((player) {
              final isSelected = selectedPlayer?.userId == player.userId &&
                  selectedPlayer?.playerCode == player.playerCode;
              return ListTile(
                dense: true,
                enabled: player.isTargetable,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: isSelected
                    ? customTheme.sovereignAccent.withValues(alpha: 0.16)
                    : null,
                leading: Icon(
                  player.isGuest
                      ? Icons.person_outline_rounded
                      : Icons.verified_user_rounded,
                  color: player.isGuest
                      ? Colors.amberAccent
                      : const Color(0xFF38BDF8),
                ),
                title: Text(
                  player.displayName,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${player.isGuest ? 'ضيف 🎭' : (player.email ?? 'حساب Google')}'
                  '${player.playerCode != null ? ' • ${player.playerCode}' : ''}'
                  ' • 🏆 ${player.trophies}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
                trailing: player.isTargetable
                    ? Text(
                        isSelected ? 'مختار' : 'اختيار',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: customTheme.sovereignAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : const Text(
                        'بلا معرّف',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                onTap: player.isTargetable
                    ? () {
                        SoundService().playClick();
                        onSelectPlayer(player);
                      }
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }
}
