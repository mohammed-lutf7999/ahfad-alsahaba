import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/question_model.dart';
import '../data/models/category_model.dart';
import '../data/models/level_model.dart';
import '../data/services/question_service.dart';
import '../data/services/cms_cache_service.dart';
import '../data/services/guild_service.dart';
import '../data/services/profile_service.dart';
import '../data/services/progression_service.dart';
import '../data/services/spaced_repetition_service.dart';
import '../core/app_constants.dart';
import '../core/cms_icon_registry.dart';

class GameController extends ChangeNotifier {
  List<Category> _categories = [];
  List<Question> _currentQuestions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  bool _isAnswered = false;
  int? _selectedAnswerIndex;
  String? _currentCategoryId;
  int? _currentLevelNumber;
  bool _isLoading = false;
  String? _error;
  int _lives = 3; // Lives for the current level
  
  // Lifelines State
  bool _hasUsedFiftyFifty = false;
  bool _hasUsedSkip = false;
  bool _hasUsedTimeFreeze = false;
  List<int> _hiddenOptionIndices = []; // Indices of options hidden by 50/50
  
  // Review Data
  final List<Map<String, dynamic>> _userAnswers = [];

  // Question service instance
  final QuestionService _questionService = QuestionService();

  // Getters
  List<Category> get categories => _categories;
  List<Question> get currentQuestions => _currentQuestions;
  List<Map<String, dynamic>> get userAnswers => _userAnswers;
  int get currentQuestionIndex => _currentQuestionIndex;
  Question? get currentQuestion =>
      _currentQuestions.isNotEmpty &&
          _currentQuestionIndex < _currentQuestions.length
      ? _currentQuestions[_currentQuestionIndex]
      : null;
  int get score => _score;
  int get correctAnswers => _correctAnswers;
  bool get isAnswered => _isAnswered;
  int? get selectedAnswerIndex => _selectedAnswerIndex;
  int get totalScore => ProfileService.instance.activeProfile?.totalScore ?? 0;
  int get highScore => ProfileService.instance.activeProfile?.highScore ?? 0;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get lives => _lives;
  bool get hasUsedFiftyFifty => _hasUsedFiftyFifty;
  bool get hasUsedSkip => _hasUsedSkip;
  bool get hasUsedTimeFreeze => _hasUsedTimeFreeze;
  List<int> get hiddenOptionIndices => _hiddenOptionIndices;

  double get progress => _currentQuestions.isEmpty
      ? 0
      : (_currentQuestionIndex + 1) / _currentQuestions.length;

  bool get isLastQuestion =>
      _currentQuestionIndex >= _currentQuestions.length - 1;

  // Helper to get category progress from profile
  int _getCategoryUnlockedLevels(String categoryId) {
    final profile = ProfileService.instance.activeProfile;
    return profile?.getCategoryUnlockedLevels(categoryId) ?? 1;
  }

  // Initialize categories (merges built-in 6 categories with dynamic CMS categories)
  void initializeCategories() {
    final defaults = <Category>[
      Category(
        id: AppConstants.quranCategory,
        name: 'القرآن الكريم',
        description: 'أسئلة عن القرآن الكريم وعلومه',
        icon: Icons.menu_book,
        totalLevels: AppConstants.levelsPerCategory,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.quranCategory),
        color: const Color(0xFF1B5E20),
        sortOrder: 10,
      ),
      Category(
        id: AppConstants.hadithCategory,
        name: 'الحديث الشريف',
        description: 'أسئلة عن الأحاديث النبوية',
        icon: Icons.format_quote,
        totalLevels: AppConstants.levelsPerCategory,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.hadithCategory),
        color: const Color(0xFF0D47A1),
        sortOrder: 20,
      ),
      Category(
        id: AppConstants.fiqhCategory,
        name: 'الفقه',
        description: 'أسئلة عن أحكام الفقه الإسلامي',
        icon: Icons.balance,
        totalLevels: AppConstants.levelsPerCategory,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.fiqhCategory),
        color: const Color(0xFF4A148C),
        sortOrder: 30,
      ),
      Category(
        id: AppConstants.seerahCategory,
        name: 'السيرة النبوية',
        description: 'أسئلة عن سيرة النبي ﷺ',
        icon: Icons.history_edu,
        totalLevels: AppConstants.levelsPerCategory,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.seerahCategory),
        color: const Color(0xFFBF360C),
        sortOrder: 40,
      ),
      Category(
        id: AppConstants.historyCategory,
        name: 'التاريخ الإسلامي',
        description: 'أسئلة عن تاريخ الحضارة الإسلامية',
        icon: Icons.castle,
        totalLevels: AppConstants.levelsPerCategory,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.historyCategory),
        color: const Color(0xFF006064),
        sortOrder: 50,
      ),
      Category(
        id: AppConstants.aqeedahCategory,
        name: 'العقيدة',
        description: 'أسئلة عن أصول العقيدة الإسلامية',
        icon: Icons.auto_awesome,
        totalLevels: AppConstants.levelsPerCategory,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.aqeedahCategory),
        color: const Color(0xFF311B92),
        sortOrder: 60,
      ),
    ];

    final cms = CmsCacheService.instance.snapshot;
    final mergedById = <String, Category>{
      for (final c in defaults) c.id: c,
    };

    for (final entry in cms.quizCategories.entries) {
      final cloudCat = entry.value;
      final base = mergedById[cloudCat.id];
      final resolvedLevels = cloudCat.totalLevels;
      mergedById[cloudCat.id] = Category(
        id: cloudCat.id,
        name: cloudCat.name.isNotEmpty ? cloudCat.name : (base?.name ?? cloudCat.id),
        description: cloudCat.description.isNotEmpty
            ? cloudCat.description
            : (base?.description ?? ''),
        icon: CmsIconRegistry.resolveIcon(
          cloudCat.iconName,
          fallback: base?.icon ?? Icons.quiz_rounded,
        ),
        totalLevels: resolvedLevels,
        unlockedLevels: _getCategoryUnlockedLevels(cloudCat.id),
        isLocked: cloudCat.isLocked,
        color: CmsIconRegistry.parseHexColor(
          cloudCat.colorHex,
          fallback: base?.color ?? const Color(0xFF1B5E20),
        ),
        sortOrder: cloudCat.sortOrder,
        isVisible: cloudCat.isVisible,
      );
    }

    _categories = mergedById.values.where((c) => c.isVisible).toList()
      ..sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      });
    notifyListeners();
  }

  // Get levels for a category
  List<Level> getLevelsForCategory(String categoryId) {
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(
        id: categoryId,
        name: CmsCacheService.instance.getCategoryDisplayName(categoryId),
        description: '',
        icon: Icons.quiz_rounded,
        totalLevels: CmsCategoryBounds.maxLevelsFor(categoryId),
        unlockedLevels: _getCategoryUnlockedLevels(categoryId),
      ),
    );
    final profile = ProfileService.instance.activeProfile;
    
    return List.generate(category.totalLevels, (index) {
      final levelNumber = index + 1;
      final isLevelUnlocked = profile?.isLevelUnlocked(categoryId, levelNumber) ?? (levelNumber == 1);
      final isCompleted = profile?.isLevelCompleted(categoryId, levelNumber) ?? false;
      final levelScore = profile?.getLevelScore(categoryId, levelNumber) ?? 0;
      final stars = profile?.getLevelStars(categoryId, levelNumber) ?? 0;
      
      return Level(
        id: '${categoryId}_level_$levelNumber',
        categoryId: categoryId,
        levelNumber: levelNumber,
        title: 'المستوى $levelNumber',
        totalQuestions: AppConstants.questionsPerLevel,
        isLocked: !isLevelUnlocked,
        isCompleted: isCompleted,
        highScore: levelScore,
        stars: stars,
      );
    });
  }

  // Load questions for a specific level (async from JSON)
  Future<void> loadQuestionsForLevel(String categoryId, int levelNumber) async {
    _currentCategoryId = categoryId;
    _currentLevelNumber = levelNumber;
    _currentQuestionIndex = 0;
    _score = 0;
    _correctAnswers = 0;
    _lives = 3; // Reset lives
    _isAnswered = false;
    _selectedAnswerIndex = null;
    _isLoading = true;
    _error = null;
    
    // Reset Lifelines for new level
    _hasUsedFiftyFifty = false;
    _hasUsedSkip = false;
    _hasUsedTimeFreeze = false;
    _hiddenOptionIndices = [];
    _userAnswers.clear();
    
    notifyListeners();

    try {
      // Load questions from JSON using QuestionService
      final loaded = await _questionService.loadQuestions(
        categoryId: categoryId,
        levelNumber: levelNumber,
      );
      _currentQuestions = await _injectDueWiseTeacherReviews(
        categoryId: categoryId,
        baseQuestions: loaded,
      );
      _isLoading = false;
      _error = null;
    } catch (e) {
      _isLoading = false;
      _error = 'فشل تحميل الأسئلة: $e';
      _currentQuestions = [];
    }

    notifyListeners();
  }

  /// Prioritizes up to 2 due «المعلم الحكيم» review questions from the same
  /// category while preserving level length and never failing level loads.
  Future<List<Question>> _injectDueWiseTeacherReviews({
    required String categoryId,
    required List<Question> baseQuestions,
  }) async {
    if (baseQuestions.isEmpty ||
        !SpacedRepetitionService.instance.isEffectivelyEnabled) {
      return baseQuestions;
    }
    try {
      await SpacedRepetitionService.instance.init();
      final dueIds =
          SpacedRepetitionService.instance.getDueQuestionIds(categoryId);
      if (dueIds.isEmpty) return baseQuestions;

      final dueSet = dueIds.toSet();
      final baseById = {for (final q in baseQuestions) q.id: q};
      final reviewQuestions = <Question>[];

      for (final id in dueIds) {
        if (reviewQuestions.length >= 2) break;
        final existing = baseById[id];
        if (existing != null) reviewQuestions.add(existing);
      }

      if (reviewQuestions.length < 2) {
        final allCategoryQuestions =
            await _questionService.loadAllQuestionsForCategory(
          categoryId,
          shuffleQuestions: false,
        );
        for (final q in allCategoryQuestions) {
          if (reviewQuestions.length >= 2) break;
          if (dueSet.contains(q.id) &&
              !reviewQuestions.any((r) => r.id == q.id)) {
            reviewQuestions.add(q);
          }
        }
      }

      if (reviewQuestions.isEmpty) return baseQuestions;

      final reviewIds = reviewQuestions.map((q) => q.id).toSet();
      final remaining =
          baseQuestions.where((q) => !reviewIds.contains(q.id)).toList();
      final targetLength = baseQuestions.length;
      final neededFromRemaining =
          (targetLength - reviewQuestions.length).clamp(0, remaining.length);
      return [
        ...reviewQuestions,
        ...remaining.take(neededFromRemaining),
      ];
    } catch (_) {
      return baseQuestions;
    }
  }

  // Answer a question
  void answerQuestion(int selectedIndex) {
    if (_isAnswered) return;

    _isAnswered = true;
    _selectedAnswerIndex = selectedIndex;

    if (currentQuestion != null) {
      if (selectedIndex == currentQuestion!.correctAnswerIndex) {
        _correctAnswers++;
        _score += AppConstants.correctAnswerPoints;
      } else {
        _lives--;
      }
      
      // Record answer
      _userAnswers.add({
        'question': currentQuestion,
        'selectedOptionIndex': selectedIndex,
        'isCorrect': selectedIndex == currentQuestion!.correctAnswerIndex,
      });
    }

    notifyListeners();
  }

  // Move to next question
  bool nextQuestion() {
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      _currentQuestionIndex++;
      _isAnswered = false;
      _selectedAnswerIndex = null;
      _hiddenOptionIndices = []; // Reset hidden options for new question
      notifyListeners();
      return true;
    }
    return false;
  }

  // Complete level
  Future<void> completeLevel() async {
    if (_currentCategoryId == null ||
        _currentLevelNumber == null ||
        _currentQuestions.isEmpty) {
      return;
    }
    
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return;

    final percentage = (_correctAnswers / _currentQuestions.length) * 100;
    final stars = AppConstants.calculateStars(percentage);

    // Save level progress to profile
    profile.setLevelStars(_currentCategoryId!, _currentLevelNumber!, stars);
    profile.setLevelScore(_currentCategoryId!, _currentLevelNumber!, _score);

    // Unlock next level ONLY if passed (clamped cleanly to category's dynamic max levels)
    if (percentage >= AppConstants.passingScore) {
      final currentUnlocked = profile.getCategoryUnlockedLevels(_currentCategoryId!);
      final maxLevels = CmsCategoryBounds.maxLevelsFor(_currentCategoryId!);
      final targetUnlocked = (_currentLevelNumber! + 1).clamp(1, maxLevels);
      if (targetUnlocked >= currentUnlocked) {
        profile.setCategoryUnlockedLevels(_currentCategoryId!, targetUnlocked);
      }
    }

    // Apply progression outcome (XP + Arena coin reward + powerup_xp_banner if owned)
    final outcome = ProgressionService.instance.applyMatchOutcome(
      rawMatchScore: _score,
      correctAnswers: _correctAnswers,
      isWin: percentage >= AppConstants.passingScore,
      isDraw: false,
      updateTrophies: false,
    );
    
    // Save profile locally immediately (< 5ms) and sync to cloud in the background
    await ProfileService.instance.saveActiveProfileLocally(
      triggerBackgroundSync: true,
      syncInventory: outcome.xpBannerConsumed || outcome.shieldConsumed,
    );
    if (_score > 0) {
      unawaited(GuildService.instance.contributeScore(_score));
    }

    // Refresh categories with profile data
    initializeCategories();
  }

  // Reset game state
  void resetGameState() {
    _currentQuestions = [];
    _currentQuestionIndex = 0;
    _score = 0;
    _correctAnswers = 0;
    _isAnswered = false;
    _selectedAnswerIndex = null;
    _currentCategoryId = null;
    _currentLevelNumber = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Clear question cache to free memory
  void clearQuestionCache() {
    _questionService.clearCache();
  }

  // Preload a category for faster loading
  Future<void> preloadCategory(String categoryId) async {
    await _questionService.preloadCategory(categoryId);
  }

  // --- Lifelines Logic ---

  /// Uses the 50/50 lifeline.
  /// Hides two incorrect answers.
  /// Returns check if successful.
  bool useFiftyFifty() {
    if (_hasUsedFiftyFifty || _isAnswered || currentQuestion == null) return false;

    _hasUsedFiftyFifty = true;
    _hiddenOptionIndices = [];

    final correctIndex = currentQuestion!.correctAnswerIndex;
    final totalOptions = currentQuestion!.options.length;
    
    // We want to hide 2 wrong options if possible (typically 4 total)
    // If only 2 or 3 options, hide 1? For now assume standard 4 options.
    
    List<int> wrongIndices = [];
    for (int i = 0; i < totalOptions; i++) {
      if (i != correctIndex) {
        wrongIndices.add(i);
      }
    }
    
    wrongIndices.shuffle();
    
    // Hide up to 2 wrong answers
    int toHide = wrongIndices.length >= 2 ? 2 : (wrongIndices.length == 1 ? 1 : 0);
    
    for (int i = 0; i < toHide; i++) {
        _hiddenOptionIndices.add(wrongIndices[i]);
    }

    notifyListeners();
    return true;
  }

  /// Uses the Skip Question lifeline.
  /// Marks question as answered correctly (or just moves next?).
  /// Let's say it just moves to next without points, OR counts as correct but no points?
  /// A pure skip usually just advances index. But logic expects passing checks.
  /// Let's treat it as "Time Up" but with no life lost?
  /// Or better: Mark as answered correctly but give 0 points?
  /// Let's go with: Mark correctly so level progress count is valid, but 0 points.
  void useSkip() {
    if (_hasUsedSkip || _isAnswered || currentQuestion == null) return;
    
    _hasUsedSkip = true;
    _isAnswered = true;
    
    // Mark the correct answer so user sees it
    _selectedAnswerIndex = currentQuestion!.correctAnswerIndex; 
    
    // We do NOT increment score, but we DO increment correctAnswers count 
    // if we want it to count towards passing the level. 
    // OR we just ignore it. Let's increment correctAnswers to stay friendly.
    _correctAnswers++; 
    
    // No points added to _score
    
    notifyListeners();
  }
  
  /// Registers time freeze usage (UI handles the timer pause, logic tracks state cost)
  bool useTimeFreeze() {
      if (_hasUsedTimeFreeze || _isAnswered) return false;
      _hasUsedTimeFreeze = true;
      notifyListeners();
      return true;
  }

  /// Uses the «بصيرة القائد 💡» (`powerup_insight`) smart power-up from inventory.
  /// Hides two incorrect answers on the current question.
  bool useCommanderInsight() {
    if (_isAnswered ||
        currentQuestion == null ||
        _hiddenOptionIndices.isNotEmpty) {
      return false;
    }

    final correctIndex = currentQuestion!.correctAnswerIndex;
    final totalOptions = currentQuestion!.options.length;
    final List<int> wrongIndices = [];
    for (int i = 0; i < totalOptions; i++) {
      if (i != correctIndex) {
        wrongIndices.add(i);
      }
    }
    wrongIndices.shuffle();
    final int toHide =
        wrongIndices.length >= 2 ? 2 : (wrongIndices.length == 1 ? 1 : 0);
    for (int i = 0; i < toHide; i++) {
      _hiddenOptionIndices.add(wrongIndices[i]);
    }
    notifyListeners();
    return true;
  }
}
