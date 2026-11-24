import 'package:flutter/material.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/store_item_model.dart';
import '../../../../data/services/store_service.dart';
import '../../../widgets/animated_avatar_frame.dart';

class StoreItemCard extends StatelessWidget {
  final StoreItemModel item;
  final AppCustomTheme customTheme;
  final int playerLevel;
  final VoidCallback onAction;

  const StoreItemCard({
    super.key,
    required this.item,
    required this.customTheme,
    required this.playerLevel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isOwned = StoreService.instance.isItemOwned(item);
    final isEquipped = StoreService.instance.isItemEquipped(item);
    final isLevelLocked = !isOwned && playerLevel < item.minLevel;

    final String buttonText;
    if (isEquipped) {
      buttonText = item.category == StoreItemCategory.powerup
          ? 'مفعّل في خزانتك ⚡'
          : 'مُفعّل حالياً ✓';
    } else if (isOwned) {
      buttonText = 'تفعيل مجاناً';
    } else if (item.priceGems > 0) {
      buttonText = '${item.priceCoins} 🪙 + ${item.priceGems} 💎';
    } else {
      buttonText = 'اقتناء بـ ${item.priceCoins} 🪙';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEquipped
            ? customTheme.surfaceCard
            : customTheme.surfaceCard.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEquipped
              ? customTheme.sovereignAccent
              : item.previewColor.withValues(alpha: 0.45),
          width: isEquipped ? 2.0 : 1.1,
        ),
        boxShadow: isEquipped
            ? [
                BoxShadow(
                  color: customTheme.sovereignAccent.withValues(alpha: 0.24),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _buildLeadingPreview(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isLevelLocked
                            ? const Color(0xFFBE123C).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'يتطلب المستوى ${item.minLevel}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: isLevelLocked
                              ? const Color(0xFFFDA4AF)
                              : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (!item.isVisible && isOwned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: customTheme.sovereignAccent
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'مقتنى خاص (مخفي)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: customTheme.sovereignAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            height: 1.15,
                          ),
                        ),
                      ),
                    if (isOwned && !isEquipped)
                      const Text(
                        'مملوك ✓',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Color(0xFF6EE7B7),
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          height: 1.15,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                key: Key('store_action_${item.id}'),
                onPressed: isEquipped ? null : onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOwned
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF3C644),
                  foregroundColor:
                      isOwned ? Colors.white : const Color(0xFF140B29),
                  disabledBackgroundColor: Colors.black.withValues(alpha: 0.35),
                  disabledForegroundColor: const Color(0xFF6EE7B7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingPreview() {
    if (item.category == StoreItemCategory.frame) {
      return AnimatedAvatarFrame(
        frameKey: item.assetKey,
        size: 56,
        showStreakBadge: false,
        child: Container(
          color: customTheme.deepBackground,
          child: Icon(item.icon, color: item.previewColor, size: 24),
        ),
      );
    }

    if (item.category == StoreItemCategory.theme) {
      final themeSpec = AppCustomTheme.fromId(item.assetKey);
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [themeSpec.deepBackground, themeSpec.surfaceCard],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: themeSpec.sovereignAccent, width: 2.0),
        ),
        child: Center(
          child: Icon(item.icon, color: themeSpec.sovereignAccent, size: 26),
        ),
      );
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: item.previewColor.withValues(alpha: 0.18),
        border: Border.all(
          color: item.previewColor.withValues(alpha: 0.75),
          width: 1.5,
        ),
      ),
      child: Icon(item.icon, color: item.previewColor, size: 26),
    );
  }
}
