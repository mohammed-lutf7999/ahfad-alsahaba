import 'package:flutter/material.dart';

import '../../../../core/app_routes.dart';
import '../../../../core/sound_service.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';
import 'announcement_user_targeting_box.dart';

class AnnouncementComposerCard extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController ctaLabelCtrl;
  final TextEditingController ctaRouteCtrl;
  final TextEditingController minVersionCtrl;
  final TextEditingController maxVersionCtrl;
  final TextEditingController searchCtrl;
  final TextEditingController manualPlayerCodeCtrl;
  final AnnouncementType messageType;
  final String targetScope;
  final bool isDismissible;
  final DateTime? expiresAt;
  final bool isSearching;
  final bool isPublishing;
  final List<AdminPlayerSearchResult> searchResults;
  final AdminPlayerSearchResult? selectedPlayer;
  final ValueChanged<AnnouncementType> onMessageTypeChanged;
  final ValueChanged<String> onTargetScopeChanged;
  final ValueChanged<bool> onDismissibleChanged;
  final VoidCallback onPickExpiry;
  final VoidCallback onClearExpiry;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<String> onManualCodeChanged;
  final ValueChanged<AdminPlayerSearchResult> onSelectPlayer;
  final VoidCallback onClearSelectedPlayer;
  final VoidCallback onSubmit;

  const AnnouncementComposerCard({
    super.key,
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.ctaLabelCtrl,
    required this.ctaRouteCtrl,
    required this.minVersionCtrl,
    required this.maxVersionCtrl,
    required this.searchCtrl,
    required this.manualPlayerCodeCtrl,
    required this.messageType,
    required this.targetScope,
    required this.isDismissible,
    required this.expiresAt,
    required this.isSearching,
    required this.isPublishing,
    required this.searchResults,
    required this.selectedPlayer,
    required this.onMessageTypeChanged,
    required this.onTargetScopeChanged,
    required this.onDismissibleChanged,
    required this.onPickExpiry,
    required this.onClearExpiry,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onManualCodeChanged,
    required this.onSelectPlayer,
    required this.onClearSelectedPlayer,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return AdminSectionCard(
      title: 'إنشاء وإرسال رسالة جديدة',
      icon: Icons.campaign_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'نوع الرسالة',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeChip(
                AnnouncementType.normal,
                'عادية',
                customTheme.sovereignAccent,
              ),
              _buildTypeChip(
                AnnouncementType.mandatory,
                'إجبارية مقفلة',
                Colors.redAccent,
              ),
              _buildTypeChip(
                AnnouncementType.admin,
                'إدارية',
                const Color(0xFF38BDF8),
              ),
              _buildTypeChip(
                AnnouncementType.motivational,
                'تحفيزية',
                const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'نطاق الاستهداف',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  key: const Key('scope_all_chip'),
                  label: const Center(
                    child: Text(
                      'جميع اللاعبين',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                    ),
                  ),
                  selected: targetScope == 'all',
                  selectedColor:
                      customTheme.sovereignAccent.withValues(alpha: 0.25),
                  onSelected: (_) => onTargetScopeChanged('all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  key: const Key('scope_single_user_chip'),
                  label: const Center(
                    child: Text(
                      'لاعب محدد 🎯',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                    ),
                  ),
                  selected: targetScope == 'single_user',
                  selectedColor:
                      customTheme.sovereignAccent.withValues(alpha: 0.25),
                  onSelected: (_) => onTargetScopeChanged('single_user'),
                ),
              ),
            ],
          ),
          if (targetScope == 'single_user') ...[
            const SizedBox(height: 12),
            AnnouncementUserTargetingBox(
              searchController: searchCtrl,
              manualPlayerCodeController: manualPlayerCodeCtrl,
              isSearching: isSearching,
              searchResults: searchResults,
              selectedPlayer: selectedPlayer,
              onSearchChanged: onSearchChanged,
              onSearchSubmitted: onSearchSubmitted,
              onManualCodeChanged: onManualCodeChanged,
              onSelectPlayer: onSelectPlayer,
              onClearSelectedPlayer: onClearSelectedPlayer,
            ),
          ],
          const SizedBox(height: 12),
          AdminTextField(
            controller: titleCtrl,
            label: 'عنوان الرسالة',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: bodyCtrl,
            label: 'نص الرسالة',
            maxLines: 3,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminTextField(
                  controller: ctaLabelCtrl,
                  label: 'نص زر الإجراء (اختياري)',
                  hint: 'مثال: افتح المتجر',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminTextField(
                  controller: ctaRouteCtrl,
                  label: 'المسار أو الرابط (اختياري)',
                  hint: AppRoutes.knightsStore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildQuickRouteChip('المتجر', AppRoutes.knightsStore),
              _buildQuickRouteChip('التحدي', AppRoutes.challenge),
              _buildQuickRouteChip('المجد', AppRoutes.gloryRoad),
              _buildQuickRouteChip('المكتبة', AppRoutes.library),
              _buildQuickRouteChip('البريد', AppRoutes.royalInbox),
              _buildQuickRouteChip('الديوان', '/diwan'),
              _buildQuickRouteChip('الكتائب', AppRoutes.guilds),
              _buildQuickRouteChip('البطولة الحية', AppRoutes.liveArena),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminTextField(
                  controller: minVersionCtrl,
                  label: 'من رقم بناء (اختياري)',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminTextField(
                  controller: maxVersionCtrl,
                  label: 'إلى رقم بناء (اختياري)',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: customTheme.sovereignAccent,
                    side: BorderSide(
                      color:
                          customTheme.sovereignAccent.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: onPickExpiry,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    expiresAt == null
                        ? 'انتهاء الصلاحية: مفتوحة'
                        : 'تنتهي: ${formatAdminDateTime(expiresAt)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                ),
              ),
              if (expiresAt != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onClearExpiry,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  tooltip: 'مسح التاريخ',
                ),
              ],
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.redAccent,
            title: const Text(
              'منع الإغلاق العادي (قفل التخطي)',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              messageType == AnnouncementType.mandatory
                  ? 'مفعّل تلقائياً لأن النوع إجباري'
                  : 'يطلب من اللاعب ضغط زر الموافقة',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
            value: messageType == AnnouncementType.mandatory
                ? true
                : !isDismissible,
            onChanged: messageType == AnnouncementType.mandatory
                ? null
                : (locked) => onDismissibleChanged(!locked),
          ),
          const SizedBox(height: 12),
          AdminPrimaryButton(
            key: const Key('admin_send_announcement_btn'),
            label: 'إرسال ونشر الرسالة 🚀',
            icon: Icons.send_rounded,
            isLoading: isPublishing,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(AnnouncementType type, String label, Color color) {
    final selected = messageType == type;
    return ChoiceChip(
      key: Key('ann_type_${type.wireName}'),
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          color: selected ? Colors.white : Colors.white70,
        ),
      ),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.35),
      side: BorderSide(
        color: selected ? color : Colors.white.withValues(alpha: 0.2),
      ),
      onSelected: (_) {
        SoundService().playClick();
        onMessageTypeChanged(type);
      },
    );
  }

  Widget _buildQuickRouteChip(String label, String route) {
    return ActionChip(
      label: Text(
        '$label ($route)',
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
      ),
      onPressed: () {
        ctaRouteCtrl.text = route;
        if (ctaLabelCtrl.text.trim().isEmpty) {
          ctaLabelCtrl.text = 'انتقل إلى $label';
        }
      },
    );
  }
}
