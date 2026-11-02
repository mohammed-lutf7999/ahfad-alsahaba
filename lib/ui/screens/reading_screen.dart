import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/models/library_model.dart';

class ReadingScreen extends StatelessWidget {
  final LibraryItem item;
  final String sectionTitle;

  const ReadingScreen({super.key, required this.item, required this.sectionTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
               Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            sectionTitle,
                            style: const TextStyle(color: AppTheme.accentColor, fontSize: 14),
                          ),
                          Text(
                            item.title,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFBF0), // Creamy paper color
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const Icon(Icons.format_quote_rounded, size: 40, color: AppTheme.accentColor),
                        const SizedBox(height: 20),
                        Text(
                          item.content,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF2D1B4E),
                            fontSize: 18,
                            height: 1.8,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Cairo', // Assuming Arabic font availability, else uses default
                          ),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          width: 50, height: 4,
                          decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
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
