import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../data/models/level_model.dart';
import '../../logic/game_controller.dart';
import '../widgets/level_item.dart';
import '../../core/sound_service.dart';

class LevelsScreen extends StatefulWidget {
  final String categoryId;

  const LevelsScreen({super.key, required this.categoryId});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> with SingleTickerProviderStateMixin {
  late GameController _gameController;
  late AnimationController _animationController;
  List<Level> _levels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _gameController = GameController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    _gameController.initializeCategories();
    _levels = _gameController.getLevelsForCategory(widget.categoryId);
    if (mounted) {
      setState(() => _isLoading = false);
      _animationController.forward();
    }
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
        decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Align to Right (Start in RTL)
                        children: [
                          Text(
                            widget.categoryId == 'islamic_history' ? 'التاريخ الإسلامي' :
                            widget.categoryId == 'quran' ? 'القرآن الكريم' :
                            widget.categoryId == 'prophets' ? 'الأنبياء والرسل' : 'السيرة النبوية',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'اختار المستوى',
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                         SoundService().playClick();
                         Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accentColor.withAlpha(60)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.accentColor, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // Levels List
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _levels.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final level = _levels[index];
                          // Staggered Animation
                          final Animation<double> animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Interval((1 / _levels.length) * index * 0.5, 1.0, curve: Curves.easeOutBack),
                            ),
                          );

                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, 50 * (1 - animation.value)),
                                child: Opacity(
                                  opacity: animation.value,
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12), // Reduced spacing
                              child: LevelItem(
                                level: level,
                                onTap: () {
                                  SoundService().playClick(); // Click sound on Level Item
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.quiz,
                                    arguments: {
                                      'categoryId': widget.categoryId,
                                      'levelId': level.id,
                                      'levelNumber': level.levelNumber,
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
