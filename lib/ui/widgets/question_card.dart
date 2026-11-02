import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'dart:math' as math;

class QuestionCard extends StatefulWidget {
  final String questionText;
  final int questionNumber;
  final int totalQuestions;

  const QuestionCard({super.key, required this.questionText, required this.questionNumber, required this.totalQuestions});

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(2.5), // Border width
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22), // Matching inner radius + width roughly
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                AppTheme.accentColor,
                Color(0xFFFFD700), // Bright Gold
                AppTheme.accentDark,
                AppTheme.accentColor,
                 Color(0xFFFFD700),
              ],
              stops: [
                0.0,
                0.25 + 0.25 * math.sin(_controller.value * 2 * math.pi),
                0.5,
                0.75 + 0.25 * math.cos(_controller.value * 2 * math.pi),
                1.0,
              ],
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withAlpha(50 + (20 * math.sin(_controller.value * 2 * math.pi)).toInt()),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryLight, AppTheme.primaryColor, AppTheme.primaryDark],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    widget.questionText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentColor.withAlpha(50)),
                    ),
                    child: Text(
                      'الجواب الصحيح هو..؟',
                      style: TextStyle(color: AppTheme.accentColor.withAlpha(230), fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
