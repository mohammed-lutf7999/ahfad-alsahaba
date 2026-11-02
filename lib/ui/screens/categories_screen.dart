import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../logic/game_controller.dart';
import '../../core/sound_service.dart';
import '../widgets/category_item.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late GameController _gameController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _gameController = GameController();
    _gameController.initializeCategories();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
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
        decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title and Icon (Right - Start in RTL)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 10)],
                          ),
                          child: const Icon(Icons.category_rounded, color: AppTheme.primaryDark, size: 22),
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppTheme.accentLight, AppTheme.accentColor],
                          ).createShader(bounds),
                          child: const Text(
                            'الأقسام',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    // Back button (Left - End in RTL)
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
                          border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.accentColor, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'اختر القسم الذي تريد اختبار معلوماتك فيه',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14),
                ),
              ),

              const SizedBox(height: 20),

              // Categories grid
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
                    border: Border.all(color: AppTheme.accentColor.withAlpha(60), width: 1.5),
                    boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(30), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 45, height: 4,
                        decoration: BoxDecoration(color: AppTheme.accentColor.withAlpha(100), borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _gameController.categories.length,
                          itemBuilder: (context, index) {
                            final category = _gameController.categories[index];
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
                              child: CategoryItem(
                                category: category,
                                onTap: () {
                                  if (!category.isLocked) {
                                    SoundService().playClick();
                                    Navigator.pushNamed(context, AppRoutes.levels, arguments: {
                                      'categoryId': category.id,
                                      'categoryName': category.name,
                                    });
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
