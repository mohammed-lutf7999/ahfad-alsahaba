import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../core/app_routes.dart';
import '../../data/models/level_model.dart';
import '../../data/services/cms_cache_service.dart';
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
  List<Animation<double>> _itemAnimations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _gameController = GameController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    unawaited(_gameController.preloadCategory(widget.categoryId));
    CmsCacheService.instance.addListener(_onCmsChanged);
    _loadLevels(animate: true);
  }

  void _onCmsChanged() {
    if (mounted) {
      unawaited(_loadLevels(animate: false));
    }
  }

  Future<void> _loadLevels({bool animate = false}) async {
    _gameController.initializeCategories();
    final loadedLevels = _gameController.getLevelsForCategory(widget.categoryId);
    final count = loadedLevels.isEmpty ? 1 : loadedLevels.length;
    final animations = List<Animation<double>>.generate(loadedLevels.length, (index) {
      final start = ((1 / count) * index * 0.45).clamp(0.0, 0.85);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
        ),
      );
    });

    if (mounted) {
      setState(() {
        _levels = loadedLevels;
        _itemAnimations = animations;
        _isLoading = false;
      });
      if (animate) {
        _animationController.forward(from: 0);
      } else if (_animationController.value < 1.0) {
        _animationController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    CmsCacheService.instance.removeListener(_onCmsChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppCustomTheme.of(context).backgroundGradient,
        ),
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
                            CmsCacheService.instance.getCategoryDisplayName(widget.categoryId),
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
                          final animation = index < _itemAnimations.length
                              ? _itemAnimations[index]
                              : _animationController;

                          return RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, 40 * (1 - animation.value)),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: LevelItem(
                                  level: level,
                                  onTap: () async {
                                    SoundService().playClick();
                                    await Navigator.pushNamed(
                                      context,
                                      AppRoutes.quiz,
                                      arguments: {
                                        'categoryId': widget.categoryId,
                                        'levelId': level.id,
                                        'levelNumber': level.levelNumber,
                                      },
                                    );
                                    if (mounted) {
                                      await _loadLevels(animate: false);
                                    }
                                  },
                                ),
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
