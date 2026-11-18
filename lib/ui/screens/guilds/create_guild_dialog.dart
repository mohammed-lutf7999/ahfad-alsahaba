import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/services/guild_service.dart';

class CreateGuildDialog extends StatefulWidget {
  const CreateGuildDialog({super.key});

  @override
  State<CreateGuildDialog> createState() => _CreateGuildDialogState();
}

class _CreateGuildDialogState extends State<CreateGuildDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  int _selectedBanner = 0;
  bool _isSubmitting = false;
  String? _error;

  static const List<IconData> bannerIcons = [
    Icons.shield_rounded,
    Icons.mosque_rounded,
    Icons.military_tech_rounded,
    Icons.auto_awesome_rounded,
    Icons.flag_rounded,
    Icons.star_rounded,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final err = await GuildService.instance.createGuild(
      name: _nameCtrl.text,
      description: _descCtrl.text,
      bannerIcon: _selectedBanner,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      SoundService().playClick();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: customTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: accent.withValues(alpha: 0.45)),
        ),
        title: Text(
          'تأسيس راية وكتيبة جديدة 🛡️',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: accent,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر شعار الكتيبة:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(bannerIcons.length, (i) {
                  final selected = i == _selectedBanner;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedBanner = i),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? accent : Colors.white12,
                        ),
                      ),
                      child: Icon(
                        bannerIcons[i],
                        size: 20,
                        color: selected ? AppTheme.primaryDark : Colors.white,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('create_guild_name_field'),
                controller: _nameCtrl,
                maxLength: 30,
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'اسم الكتيبة (3-30 حرفاً)',
                  hintText: 'مثال: فرسان الهدى',
                  labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                  hintStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white38),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('create_guild_desc_field'),
                controller: _descCtrl,
                maxLength: 100,
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'رسالة أو وصف مختصر (اختياري)',
                  labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.amberAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
            ),
          ),
          ElevatedButton(
            key: const Key('create_guild_submit_btn'),
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'تأسيس الراية',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
