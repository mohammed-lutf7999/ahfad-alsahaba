import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/models/library_model.dart';
import '../../data/services/library_service.dart';
import '../../core/sound_service.dart';
import 'content_list_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late Future<List<LibrarySection>> _libraryData;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _libraryData = LibraryService.loadLibraryContent();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: AppTheme.accentColor.withAlpha(80),
                                  blurRadius: 10)
                            ],
                          ),
                          child: const Icon(Icons.library_books_rounded,
                              color: AppTheme.primaryDark, size: 22),
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppTheme.accentLight, AppTheme.accentColor],
                          ).createShader(bounds),
                          child: const Text(
                            'مكتبة الأحفاد',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        SoundService().playClick();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.accentColor.withAlpha(80)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppTheme.accentColor, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'واحة المعرفة والإيمان',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),

              const SizedBox(height: 20),

              // Grid
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(35),
                        topRight: Radius.circular(35)),
                    border: Border.all(
                        color: AppTheme.accentColor.withAlpha(60), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.accentColor.withAlpha(30),
                          blurRadius: 20,
                          offset: const Offset(0, -5))
                    ],
                  ),
                  child: FutureBuilder<List<LibrarySection>>(
                    future: _libraryData,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.accentColor));
                      } else if (snapshot.hasError) {
                        return Center(child: Text('خطأ في تحميل المكتبة', style: TextStyle(color: AppTheme.primaryDark)));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                         return const Center(child: Text('لا يوجد محتوى حالياً', style: TextStyle(color: AppTheme.primaryDark)));
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final section = snapshot.data![index];
                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                                final delay = index * 0.1;
                                final animValue = Curves.easeOutCubic.transform(
                                  (_animationController.value - delay).clamp(0.0, 1.0),
                                );
                                return Transform.translate(
                                  offset: Offset(0, 50 * (1 - animValue)),
                                  child: Opacity(opacity: animValue, child: child),
                                );
                            },
                            child: _LibrarySectionCard(
                              section: section,
                              onTap: () {
                                SoundService().playClick();
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => ContentListScreen(section: section))
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySectionCard extends StatelessWidget {
  final LibrarySection section;
  final VoidCallback onTap;

  const _LibrarySectionCard({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.imperialGradient,
              ),
              child: Icon(section.icon, color: AppTheme.accentColor, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              section.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${section.items.length} عنصر',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
