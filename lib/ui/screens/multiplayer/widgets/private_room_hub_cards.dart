import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import 'pin_code_boxes_widget.dart';

/// Create-room & Join-room cards rendered inside [PrivateRoomHubScreen].
class PrivateRoomCreateCard extends StatelessWidget {
  const PrivateRoomCreateCard({
    super.key,
    required this.isCreating,
    required this.onCreate,
  });

  final bool isCreating;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _HubCardHeader(
            icon: Icons.add_home_work_rounded,
            color: AppTheme.accentColor,
            title: 'إنشاء غرفة جديدة',
            subtitle: 'أنشئ كوداً وادعُ صديقك عبر واتساب',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.primaryDark,
                elevation: 3,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isCreating ? null : onCreate,
              icon: isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryDark,
                      ),
                    )
                  : const Icon(Icons.castle_rounded, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isCreating ? 'جاري إنشاء الغرفة...' : 'إنشاء غرفة خاصة 🏰',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Cairo',
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivateRoomJoinCard extends StatelessWidget {
  const PrivateRoomJoinCard({
    super.key,
    required this.pinController,
    required this.pinFocusNode,
    required this.isJoining,
    required this.onPinChanged,
    required this.onPasteCode,
    required this.onJoin,
  });

  final TextEditingController pinController;
  final FocusNode pinFocusNode;
  final bool isJoining;
  final ValueChanged<String> onPinChanged;
  final VoidCallback onPasteCode;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          const _HubCardHeader(
            icon: Icons.vpn_key_rounded,
            color: Colors.blueAccent,
            title: 'الانضمام إلى غرفة صديق',
            subtitle: 'أدخل الرمز السداسي الذي أرسله لك صديقك',
          ),
          const SizedBox(height: 16),
          PinCodeInputBoxes(
            controller: pinController,
            focusNode: pinFocusNode,
            onChanged: onPinChanged,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onPasteCode,
              icon: const Icon(
                Icons.paste_rounded,
                size: 16,
                color: AppTheme.accentColor,
              ),
              label: const Text(
                'لصق الكود من الحافظة',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 3,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isJoining ? null : onJoin,
              icon: isJoining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sports_kabaddi_rounded, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isJoining ? 'جاري الانضمام...' : 'دخول المعركة الآن ⚔️',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Cairo',
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubCardHeader extends StatelessWidget {
  const _HubCardHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
