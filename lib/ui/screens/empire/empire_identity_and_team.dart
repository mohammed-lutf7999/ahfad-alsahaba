import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmpireImperialBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const EmpireImperialBackButton({
    super.key,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFFFFD700) : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(Icons.arrow_forward_ios_rounded, color: color),
      ),
    );
  }
}

class EmpireDesignerIdentityCard extends StatelessWidget {
  final bool isDark;

  const EmpireDesignerIdentityCard({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.02),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFAFA),
                ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700)
                .withValues(alpha: isDark ? 0.05 : 0.2),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/images/logo.png'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'م. محمد أكرم لطف',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Software Engineer & Creative Designer',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'متخصص في بناء إمبراطوريات رقمية تجمع بين القيم، الجمال، والتقنية.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              height: 1.5,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _ImperialSocialBtn(
                Icons.email_rounded,
                'Email',
                'mailto:dia666111@gmail.com',
                isDark,
              ),
              _ImperialSocialBtn(
                Icons.call_rounded,
                'WhatsApp',
                'https://wa.me/967778537999',
                isDark,
              ),
              _ImperialSocialBtn(
                Icons.code_rounded,
                'GitHub',
                'https://github.com/Start-0',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImperialSocialBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final bool isDark;

  const _ImperialSocialBtn(this.icon, this.label, this.url, this.isDark);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.black38 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.amber.shade700, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmpireTeamMemberTile extends StatelessWidget {
  final String name;
  final String role;
  final String details;
  final String? imagePath;
  final IconData? icon;
  final bool isDark;

  const EmpireTeamMemberTile({
    super.key,
    required this.name,
    required this.role,
    required this.details,
    this.imagePath,
    this.icon,
    required this.isDark,
  });

  void _showBio(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151515) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: const Border(
            top: BorderSide(color: Color(0xFFFFD700), width: 3),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                imagePath != null
                    ? CircleAvatar(
                        radius: 40,
                        backgroundImage: AssetImage(imagePath!),
                      )
                    : CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            isDark ? Colors.white10 : Colors.black12,
                        child: Icon(icon, color: Colors.orange, size: 30),
                      ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  role,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.amber : Colors.deepOrange,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  details,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.6,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBio(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          boxShadow: [
            if (!isDark) const BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            imagePath != null
                ? CircleAvatar(backgroundImage: AssetImage(imagePath!))
                : CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(icon, color: Colors.orange),
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    role,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.info_outline_rounded,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}
