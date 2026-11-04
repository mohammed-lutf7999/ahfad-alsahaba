import 'package:flutter/material.dart';
import '../data/models/question_model.dart';
import '../data/models/category_model.dart';
import '../data/models/level_model.dart';
import '../data/services/question_service.dart';
import '../data/services/profile_service.dart';
import '../core/app_constants.dart';

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

  // Initialize categories
  void initializeCategories() {
    _categories = [
      Category(
        id: AppConstants.quranCategory,
        name: 'القرآن الكريم',
        description: 'أسئلة عن القرآن الكريم وعلومه',
        icon: Icons.menu_book,
        totalLevels: 10,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.quranCategory),
        color: const Color(0xFF1B5E20),
      ),
      Category(
        id: AppConstants.hadithCategory,
        name: 'الحديث الشريف',
        description: 'أسئلة عن الأحاديث النبوية',
        icon: Icons.format_quote,
        totalLevels: 10,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.hadithCategory),
        color: const Color(0xFF0D47A1),
      ),
      Category(
        id: AppConstants.fiqhCategory,
        name: 'الفقه',
        description: 'أسئلة عن أحكام الفقه الإسلامي',
        icon: Icons.balance,
        totalLevels: 10,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.fiqhCategory),
        color: const Color(0xFF4A148C),
      ),
      Category(
        id: AppConstants.seerahCategory,
        name: 'السيرة النبوية',
        description: 'أسئلة عن سيرة النبي ﷺ',
        icon: Icons.history_edu,
        totalLevels: 10,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.seerahCategory),
        color: const Color(0xFFBF360C),
      ),
      Category(
        id: AppConstants.historyCategory,
        name: 'التاريخ الإسلامي',
        description: 'أسئلة عن تاريخ الحضارة الإسلامية',
        icon: Icons.castle,
        totalLevels: 10,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.historyCategory),
        color: const Color(0xFF006064),
      ),
      Category(
        id: AppConstants.aqeedahCategory,
        name: 'العقيدة',
        description: 'أسئلة عن أصول العقيدة الإسلامية',
        icon: Icons.auto_awesome,
        totalLevels: 10,
        unlockedLevels: _getCategoryUnlockedLevels(AppConstants.aqeedahCategory),
        color: const Color(0xFF311B92),
      ),
    ];
    notifyListeners();
  }

  // Get levels for a category
  List<Level> getLevelsForCategory(String categoryId) {
    final category = _categories.firstWhere((c) => c.id == categoryId);
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
    _hasUsedTimeFreeze = false;
    _hiddenOptionIndices = [];
    _userAnswers.clear();
    
    notifyListeners();

    try {
      // Load questions from JSON using QuestionService
      _currentQuestions = await _questionService.loadQuestions(
        categoryId: categoryId,
        levelNumber: levelNumber,
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
    if (_currentCategoryId == null || _currentLevelNumber == null) return;
    
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return;

    final percentage = (_correctAnswers / _currentQuestions.length) * 100;
    int stars = 0;
    if (percentage >= 90) {
      stars = 3;
    } else if (percentage >= 70) {
      stars = 2;
    } else if (percentage >= AppConstants.passingScore) {
      stars = 1;
    }

    // Save level progress to profile
    profile.setLevelStars(_currentCategoryId!, _currentLevelNumber!, stars);
    profile.setLevelScore(_currentCategoryId!, _currentLevelNumber!, _score);

    // Unlock next level ONLY if passed
    if (percentage >= AppConstants.passingScore) {
      final currentUnlocked = profile.getCategoryUnlockedLevels(_currentCategoryId!);
      if (_currentLevelNumber! >= currentUnlocked) {
        profile.setCategoryUnlockedLevels(_currentCategoryId!, _currentLevelNumber! + 1);
      }
    }

    // Update total score in profile
    profile.addScore(_score);
    
    // Save profile locally AND sync to cloud
    await ProfileService.instance.saveActiveProfileAndSync();

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
}
