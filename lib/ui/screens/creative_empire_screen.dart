import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/size_config.dart';
import '../../data/models/empire_model.dart';
import '../../data/local/empire_data.dart';
import 'dart:math' as math;

class CreativeEmpireScreen extends StatefulWidget {
  const CreativeEmpireScreen({super.key});

  @override
  State<CreativeEmpireScreen> createState() => _CreativeEmpireScreenState();
}

class _CreativeEmpireScreenState extends State<CreativeEmpireScreen> with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _entranceController;
  bool _isDarkMode = true; // Default to dark mode

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _entranceController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)..forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  Color get _backgroundColor => _isDarkMode ? const Color(0xFF001020) : const Color(0xFFF5F5F5);
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _goldColor => const Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleTheme,
          backgroundColor: _goldColor,
          child: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.black87),
        ),
        body: Stack(
          children: [
            // 1. Background
            if (_isDarkMode) const _LegendaryBackground() else const _LightBackground(),

            // 2. Main Content
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header Spacer
                SliverToBoxAdapter(child: SizedBox(height: getProportionateScreenHeight(40))),

                // Back Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerRight, // RTL: Right is start
                      child: _ImperialBackButton(
                        onTap: () => Navigator.pop(context),
                        isDark: _isDarkMode,
                      ),
                    ),
                  ),
                ),

                // Imperial Header / Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: FadeTransition(
                      opacity: _entranceController,
                      child: Column(
                        children: [
                          Icon(Icons.verified_user_rounded, color: _goldColor, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            "الإمبراطورية الإبداعية",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _goldColor,
                              shadows: [
                                BoxShadow(
                                    color: _goldColor.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5)
                              ],
                            ),
                          ),
                          Text(
                            "Legacy of Excellence",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              letterSpacing: 3,
                              color: _textColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Designer Identity
                SliverToBoxAdapter(
                  child: _DesignerIdentityImperial(isDark: _isDarkMode),
                ),

                SliverToBoxAdapter(child: SizedBox(height: getProportionateScreenHeight(40))),

                // Portfolio Sections
                _buildSectionTitle("صرح الإنجازات"),
                
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ImperialPavilion(
                        section: EmpireData.sections[index],
                        isDark: _isDarkMode,
                      ),
                      childCount: EmpireData.sections.length,
                    ),
                  ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: getProportionateScreenHeight(40))),

                // Team Section
                _buildSectionTitle("فريق الإمبراطورية"),
                
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                       _TeamMemberTile(
                          name: "م. محمد أكرم لطف",
                          role: "القائد التقني والمصمم",
                          details: "مهندس البرمجيات المسؤول عن تخطيط وتطوير النظام بالكامل، وتصميم تجربة المستخدم، وضمان جودة الأداء.",
                          imagePath: "assets/images/logo.png",
                          isDark: _isDarkMode,
                       ),
                       const SizedBox(height: 16),
                        _TeamMemberTile(
                          name: "م. فهمي القعاري",
                          role: "مهندس الصوت والإبداع",
                          details: "المسؤول عن الإنتاج الصوتي، التعليق الصوتي، وإضافة اللمسات الفنية السمعية التي تضفي روحاً على التطبيق.",
                          icon: Icons.mic_rounded,
                          isDark: _isDarkMode,
                       ),
                    ]),
                  ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: getProportionateScreenHeight(80))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Align(
          alignment: Alignment.centerRight, // Align Right
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: _goldColor, width: 4)), // Right Border
              // borderRadius: BorderRadius.circular(8),
              // color: _isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: _isDarkMode ? _goldColor : Colors.black87,
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Widgets & Models
// -----------------------------------------------------------------------------

// _ProjectData class removed - now using EmpireProject from empire_model.dart

class _ImperialBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _ImperialBackButton({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFFFFD700) : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(Icons.arrow_forward_ios_rounded, color: color), // RTL Arrow
      ),
    );
  }
}

class _DesignerIdentityImperial extends StatelessWidget {
  final bool isDark;
  const _DesignerIdentityImperial({required this.isDark});

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
          colors: isDark ? [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ] : [
             Colors.white,
             const Color(0xFFFAFAFA),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(isDark ? 0.05 : 0.2),
            blurRadius: 30,
            spreadRadius: 0,
          )
        ],
      ),
      child: Column(
        children: [
          // Glowing Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
            ),
            child: const CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/images/logo.png'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "م. محمد أكرم لطف",
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
              color: const Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Software Engineer & Creative Designer",
              style: TextStyle(
                color: Color(0xFFFFD700), // Always GOLD
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
           const SizedBox(height: 16),
           Text(
             "متخصص في بناء إمبراطوريات رقمية تجمع بين القيم، الجمال، والتقنية.",
             textAlign: TextAlign.center,
             style: TextStyle(color: textColor.withOpacity(0.7), height: 1.5, fontFamily: 'Cairo'),
           ),
           const SizedBox(height: 24),
           // Actions
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
             children: [
               _ImperialSocialBtn(Icons.email_rounded, "Email", "mailto:dia666111@gmail.com", isDark),
               _ImperialSocialBtn(Icons.call_rounded, "WhatsApp", "https://wa.me/967778537999", isDark),
               _ImperialSocialBtn(Icons.code_rounded, "GitHub", "https://github.com/Start-0", isDark),
             ],
           )
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
              style: TextStyle(color: isDark ? Colors.white.withOpacity(0.7) : Colors.black54, fontSize: 10),
            )
          ],
        ),
      ),
    );
  }
}

class _ImperialPavilion extends StatelessWidget {
  final EmpireSection section;
  final bool isDark;

  const _ImperialPavilion({
    required this.section,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // RTL
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start, // RTL
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: section.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: section.color),
                  ),
                  child: Icon(section.icon, color: section.color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      section.subtitle,
                      style: TextStyle(color: section.color.withOpacity(0.8), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: section.projects.length,
            itemBuilder: (context, index) {
              return _AnimatedProjectCard(project: section.projects[index], color: section.color, isDark: isDark);
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedProjectCard extends StatefulWidget {
  final EmpireProject project;
  final Color color;
  final bool isDark;
  const _AnimatedProjectCard({required this.project, required this.color, required this.isDark});

  @override
  State<_AnimatedProjectCard> createState() => _AnimatedProjectCardState();
}

class _AnimatedProjectCardState extends State<_AnimatedProjectCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    // Continuous floating animation
    _controller = AnimationController(duration: Duration(milliseconds: 2000 + math.Random().nextInt(1000)), vsync: this)..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showDetails(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Material(
          color: Colors.transparent,
          child: _ProjectPopup(project: widget.project, color: widget.color, isDark: widget.isDark),
        ),
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return Transform.scale(
          scale: Curves.elasticOut.transform(anim.value),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_floatAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => _showDetails(context),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
            boxShadow: [
               BoxShadow(
                 color: widget.color.withOpacity(widget.isDark ? 0.2 : 0.1),
                 blurRadius: 15,
                 spreadRadius: 2,
                 offset: const Offset(0, 4),
               )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Decoration corner
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(widget.isDark ? 0.3 : 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.project.icon, size: 36, color: widget.color),
                      const SizedBox(height: 16),
                      Text(
                        widget.project.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.project.shortDesc,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectPopup extends StatelessWidget {
  final EmpireProject project;
  final Color color;
  final bool isDark;
  const _ProjectPopup({required this.project, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(
               color: color.withOpacity(0.1),
               shape: BoxShape.circle,
             ),
             child: Icon(project.icon, size: 60, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            project.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: color,
               borderRadius: BorderRadius.circular(20)
             ),
            child: Text(
              project.shortDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 40),
          Text(
            project.fullDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
              height: 1.6,
              fontSize: 16,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: const Text("إغلاق", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  final String name;
  final String role;
  final String details;
  final String? imagePath;
  final IconData? icon;
  final bool isDark;

  const _TeamMemberTile({
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151515) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: const Border(top: BorderSide(color: Color(0xFFFFD700), width: 3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            imagePath != null
                ? CircleAvatar(radius: 40, backgroundImage: AssetImage(imagePath!))
                : CircleAvatar(radius: 40, backgroundColor: isDark ? Colors.white10 : Colors.black12, child: Icon(icon, color: Colors.orange, size: 30)),
            const SizedBox(height: 16),
            Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo')),
            Text(role, style: TextStyle(fontSize: 14, color: isDark ? Colors.amber : Colors.deepOrange)),
            const SizedBox(height: 24),
            Text(details, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, height: 1.6, fontSize: 16)),
            const SizedBox(height: 40),
          ],
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
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          boxShadow: [if(!isDark) BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          children: [
             imagePath != null
                ? CircleAvatar(backgroundImage: AssetImage(imagePath!))
                : CircleAvatar(backgroundColor: Colors.grey.shade200, child: Icon(icon, color: Colors.orange)),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                   Text(role, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                 ],
               ),
             ),
             Icon(Icons.info_outline_rounded, color: isDark ? Colors.white30 : Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _LegendaryBackground extends StatefulWidget {
  const _LegendaryBackground();

  @override
  State<_LegendaryBackground> createState() => _LegendaryBackgroundState();
}

class _LegendaryBackgroundState extends State<_LegendaryBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 20), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Dynamic Gradient
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    0.5 * math.cos(_controller.value * 2 * math.pi),
                    0.5 * math.sin(_controller.value * 2 * math.pi),
                  ),
                  radius: 1.5,
                  colors: const [
                    Color(0xFF0D47A1), // Blue
                    Color(0xFF001020), // Dark
                    Color(0xFF000000), // Black
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            );
          },
        ),
        // Particles
        Positioned.fill(
           child: CustomPaint(painter: _ParticlePainter(_controller, Colors.white)),
        ),
      ],
    );
  }
}

class _LightBackground extends StatefulWidget {
  const _LightBackground();

  @override
  State<_LightBackground> createState() => _LightBackgroundState();
}

class _LightBackgroundState extends State<_LightBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 20), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Dynamic Gradient
        Container(
          decoration: const BoxDecoration(
             gradient: LinearGradient(
               colors: [Color(0xFFF5F5F5), Color(0xFFE0F7FA)],
               begin: Alignment.topCenter,
               end: Alignment.bottomCenter
             )
          ),
        ),
        // Particles
        Positioned.fill(
           child: CustomPaint(painter: _ParticlePainter(_controller, Colors.teal)),
        ),
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  _ParticlePainter(this.animation, this.color) : super(repaint: animation);

  // Use fixed random set
  final List<Offset> _stars = List.generate(50, (index) => Offset(math.Random(index).nextDouble(), math.Random(index).nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.3);
    
    for (int i = 0; i < _stars.length; i++) {
        var offset = _stars[i];
        // Move stars slowly
        double dy = (offset.dy + animation.value * (0.2 + (i%5)/10)) % 1.0;
        double dx = offset.dx;
        
        // Blink effect
        double opacity = (math.sin(animation.value * 20 + i) + 1) / 2 * 0.5;
        paint.color = color.withOpacity(opacity);
        
        canvas.drawCircle(Offset(dx * size.width, dy * size.height), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
