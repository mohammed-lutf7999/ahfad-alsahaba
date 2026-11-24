import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';

class PlayerPermissionsCard extends StatelessWidget {
  final AdminPlayerDetail detail;
  final bool isBanned;
  final int? banHours;
  final TextEditingController banReasonController;
  final TextEditingController permNotesController;
  final bool canUseOnline;
  final bool canUseDiwan;
  final bool canUseGuilds;
  final bool? canHostLiveArenas;
  final bool isSaving;
  final ValueChanged<bool> onBanChanged;
  final ValueChanged<int?> onBanHoursChanged;
  final ValueChanged<bool> onOnlineChanged;
  final ValueChanged<bool> onDiwanChanged;
  final ValueChanged<bool> onGuildsChanged;
  final ValueChanged<bool?> onHostLiveArenasChanged;
  final VoidCallback onQuickUnmute;
  final VoidCallback onSave;

  const PlayerPermissionsCard({
    super.key,
    required this.detail,
    required this.isBanned,
    required this.banHours,
    required this.banReasonController,
    required this.permNotesController,
    required this.canUseOnline,
    required this.canUseDiwan,
    required this.canUseGuilds,
    required this.canHostLiveArenas,
    required this.isSaving,
    required this.onBanChanged,
    required this.onBanHoursChanged,
    required this.onOnlineChanged,
    required this.onDiwanChanged,
    required this.onGuildsChanged,
    required this.onHostLiveArenasChanged,
    required this.onQuickUnmute,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      key: const Key('player_permissions_card'),
      title: 'الصلاحيات والحظر الفردي 🛡️',
      icon: Icons.security_rounded,
      accentColor: const Color(0xFF38BDF8),
      child: detail.canManagePermissions
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  key: const Key('player_ban_switch'),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.redAccent,
                  title: const Text(
                    'حظر الحساب بالكامل 🚫',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    isBanned
                        ? 'اللاعب محظور حالياً ويمنع من دخول اللعبة'
                        : 'الحساب نشط وغير محظور',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isBanned ? Colors.redAccent : Colors.white60,
                      fontSize: 11.5,
                    ),
                  ),
                  value: isBanned,
                  onChanged: onBanChanged,
                ),
                if (isBanned) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    key: const Key('player_ban_duration_dropdown'),
                    isExpanded: true,
                    value: banHours,
                    dropdownColor: AppCustomTheme.of(context).surfaceCard,
                    decoration: const InputDecoration(
                      labelText: 'مدة الحظر',
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem<int?>(
                        value: 24,
                        child: Text(
                          '24 ساعة (يوم واحد)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem<int?>(
                        value: 168,
                        child: Text(
                          '7 أيام (أسبوع)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem<int?>(
                        value: 720,
                        child: Text(
                          '30 يوماً (شهر)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'حظر دائم ⛔',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onBanHoursChanged,
                  ),
                  const SizedBox(height: 8),
                  AdminTextField(
                    key: const Key('player_ban_reason_input'),
                    controller: banReasonController,
                    label: 'سبب الحظر (يظهر للاعب)',
                  ),
                ],
                const Divider(color: Colors.white24, height: 24),
                const Text(
                  'التحكم الدقيق في الميزات:',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SwitchListTile.adaptive(
                  key: const Key('perm_switch_online'),
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF38BDF8),
                  title: const Text(
                    'المعارك الجماعية أونلاين ⚔️',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  value: canUseOnline,
                  onChanged: onOnlineChanged,
                ),
                SwitchListTile.adaptive(
                  key: const Key('perm_switch_diwan'),
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF38BDF8),
                  title: const Text(
                    'ديوان الأحفاد والمحادثة 💬',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  value: canUseDiwan,
                  onChanged: onDiwanChanged,
                ),
                SwitchListTile.adaptive(
                  key: const Key('perm_switch_guilds'),
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF38BDF8),
                  title: const Text(
                    'الكتائب والمساهمة 🛡️',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  value: canUseGuilds,
                  onChanged: onGuildsChanged,
                ),
                const SizedBox(height: 8),
                const Text(
                  'صلاحية استضافة البطولات الحية (Live Arena):',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<bool?>(
                  key: const Key('player_perm_host_arena_dropdown'),
                  isExpanded: true,
                  value: canHostLiveArenas,
                  dropdownColor: AppCustomTheme.of(context).surfaceCard,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem<bool?>(
                      value: null,
                      child: Text(
                        'حسب السياسة العامة (افتراضي)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DropdownMenuItem<bool?>(
                      value: true,
                      child: Text(
                        'تفويض معلم — مسموح دائماً 🎓',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                    DropdownMenuItem<bool?>(
                      value: false,
                      child: Text(
                        'ممنوع فردياً 🚫',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onHostLiveArenasChanged,
                ),
                if (detail.permissions.isEffectivelyDiwanMutedNow ||
                    detail.diwanModeration != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amberAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.volume_off_rounded,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'اللاعب مكتوم حالياً في الديوان',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.amberAccent,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          key: const Key('btn_quick_unmute_player'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                          ),
                          onPressed: onQuickUnmute,
                          child: const Text(
                            'فك الكتم',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                AdminTextField(
                  controller: permNotesController,
                  label: 'ملاحظات إدارية خاصة (لا تظهر للاعب)',
                ),
                const SizedBox(height: 14),
                AdminPrimaryButton(
                  key: const Key('btn_save_player_permissions'),
                  label: 'حفظ الصلاحيات والحظر',
                  icon: Icons.save_rounded,
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.white,
                  isLoading: isSaving,
                  onPressed: onSave,
                ),
              ],
            )
          : const Text(
              'حساب ضيف محلي غير مربوط بحساب سحابي؛ لا يمكن فرض حظر أو صلاحيات سحابية عليه قبل ربط Google.',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.amberAccent),
            ),
    );
  }
}
