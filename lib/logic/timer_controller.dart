import 'dart:async';
import 'package:flutter/foundation.dart';
// Updated to support onTick callback
import '../data/local/shared_prefs_service.dart';
import '../core/app_constants.dart';

class TimerController extends ChangeNotifier {
  Timer? _timer;
  int _remainingTime = AppConstants.defaultQuestionTime;
  int _totalTime = AppConstants.defaultQuestionTime;
  bool _isRunning = false;
  VoidCallback? _onTimeUp;

  int get remainingTime => _remainingTime;
  int get totalTime => _totalTime;
  bool get isRunning => _isRunning;
  double get progress => _remainingTime / _totalTime;

  void initialize() {
    _totalTime = SharedPrefsService.getQuestionTime();
    _remainingTime = _totalTime;
  }

  void startTimer({VoidCallback? onTimeUp, void Function(int)? onTick}) {
    _onTimeUp = onTimeUp;
    _timer?.cancel(); // Cancel any existing timer before starting a new one
    _remainingTime = _totalTime;
    _isRunning = true;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        _remainingTime--;
        onTick?.call(_remainingTime); // Call onTick callback
        notifyListeners();
      } else {
        _timer?.cancel();
        _isRunning = false; // Ensure _isRunning is set to false when timer stops
        _onTimeUp?.call();
        notifyListeners(); // Notify listeners after timer stops
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void resumeTimer() {
    if (!_isRunning && _remainingTime > 0) {
      _isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingTime > 0) {
          _remainingTime--;
          notifyListeners();
        } else {
          stopTimer();
          _onTimeUp?.call();
        }
      });
    }
  }

  void resetTimer() {
    _timer?.cancel();
    _remainingTime = _totalTime;
    _isRunning = false;
    notifyListeners();
  }

  void setTotalTime(int seconds) {
    _totalTime = seconds;
    _remainingTime = seconds;
    notifyListeners();
  }

  bool get isFastAnswer =>
      _remainingTime >= (_totalTime - AppConstants.fastAnswerThreshold);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
