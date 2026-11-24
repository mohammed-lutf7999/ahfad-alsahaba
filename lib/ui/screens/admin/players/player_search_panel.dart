import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';

class PlayerSearchPanel extends StatelessWidget {
  final TextEditingController searchController;
  final bool isSearching;
  final List<AdminPlayerSearchResult> players;
  final AdminPlayerDetail? selectedDetail;
  final VoidCallback onSearch;
  final VoidCallback onExportCsv;
  final ValueChanged<AdminPlayerSearchResult> onSelectPlayer;

  const PlayerSearchPanel({
    super.key,
    required this.searchController,
    required this.isSearching,
    required this.players,
    required this.selectedDetail,
    required this.onSearch,
    required this.onExportCsv,
    required this.onSelectPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return AdminSectionCard(
      title: 'البحث في الحسابات والضيوف',
      icon: Icons.person_search_rounded,
      child: Column(
        children: [
          AdminTextField(
            controller: searchController,
            label: 'الاسم، البريد، أو كود SAH-XXXX',
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (_) => onSearch(),
            suffixIcon: IconButton(
              icon: Icon(Icons.search_rounded, color: accent),
              onPressed: onSearch,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('btn_export_players_csv'),
              onPressed: players.isEmpty ? null : onExportCsv,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 17),
              label: Text(
                'تصدير CSV (${players.length})',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: accent),
            )
          else if (players.isEmpty)
            const Text(
              'لا توجد نتائج مطابقة.',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
            )
          else
            for (final p in players.take(12)) ...[
              _PlayerRowTile(
                player: p,
                isSelected: (selectedDetail?.userId != null &&
                        selectedDetail?.userId == p.userId) ||
                    (selectedDetail?.playerCode != null &&
                        selectedDetail?.playerCode == p.playerCode),
                onTap: () => onSelectPlayer(p),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _PlayerRowTile extends StatelessWidget {
  final AdminPlayerSearchResult player;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlayerRowTile({
    required this.player,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accent
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    '${player.isGuest ? "ضيف" : (player.email ?? "Google")} • 🏆 ${player.trophies} • م${player.playerLevel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white60,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}
