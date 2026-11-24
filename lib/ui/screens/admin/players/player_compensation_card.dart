import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';

Future<bool> showConfirmCompensationDialog(
  BuildContext context, {
  required String playerName,
  required int coins,
  required int gems,
  required int xp,
  required String reason,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppCustomTheme.of(ctx).surfaceCard,
        title: const Text(
          'تأكيد منح التعويض',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
        ),
        content: Text(
          'اللاعب: $playerName\n'
          'دنانير: $coins | ياقوت: $gems | خبرة: $xp\n'
          'السبب: $reason',
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'تأكيد ومنح',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return confirmed == true;
}

class PlayerCompensationCard extends StatelessWidget {
  final AdminPlayerDetail detail;
  final GlobalKey<FormState> formKey;
  final TextEditingController coinsController;
  final TextEditingController gemsController;
  final TextEditingController xpController;
  final TextEditingController reasonController;
  final bool isCompensating;
  final VoidCallback onSubmit;

  const PlayerCompensationCard({
    super.key,
    required this.detail,
    required this.formKey,
    required this.coinsController,
    required this.gemsController,
    required this.xpController,
    required this.reasonController,
    required this.isCompensating,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: 'تعويض آمن بسقف رقابي',
      icon: Icons.card_giftcard_rounded,
      accentColor: const Color(0xFF10B981),
      child: detail.canReceiveCompensation
          ? Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'السقف: حتى 10,000 دينار، 100 ياقوتة، و5,000 خبرة لكل معاملة.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AdminTextField(
                          controller: coinsController,
                          label: 'دنانير',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim()) ?? -1;
                            return (n < 0 || n > 10000) ? '0..10000' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AdminTextField(
                          controller: gemsController,
                          label: 'ياقوت',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim()) ?? -1;
                            return (n < 0 || n > 100) ? '0..100' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AdminTextField(
                          controller: xpController,
                          label: 'خبرة XP',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim()) ?? -1;
                            return (n < 0 || n > 5000) ? '0..5000' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AdminTextField(
                    controller: reasonController,
                    label: 'سبب التعويض (إلزامي للتدقيق)',
                    validator: (v) => (v ?? '').trim().length < 3
                        ? 'اكتب سبباً واضحاً (3 أحرف على الأقل)'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AdminPrimaryButton(
                    key: const Key('btn_grant_player_compensation'),
                    label: 'منح التعويض وتسجيله',
                    icon: Icons.verified_rounded,
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    isLoading: isCompensating,
                    onPressed: onSubmit,
                  ),
                ],
              ),
            )
          : const Text(
              'حساب ضيف محلي غير مربوط بحساب سحابي؛ لا يمكن شحن رصيده سحابياً قبل ربط Google.',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.amberAccent),
            ),
    );
  }
}
