import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/models/library_model.dart';
import 'reading_screen.dart';
import '../../core/sound_service.dart';

class ContentListScreen extends StatelessWidget {
  final LibrarySection section;

  const ContentListScreen({super.key, required this.section});

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
                      child: Text(
                        section.title,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                         SoundService().playClick();
                         Navigator.pop(context);
                      },
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: section.items.length,
                    itemBuilder: (context, index) {
                      final item = section.items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                          ],
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          title: Text(
                            item.title,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          trailing: Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(
                               color: AppTheme.accentColor.withOpacity(0.1),
                               shape: BoxShape.circle,
                             ),
                             child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.accentColor),
                          ),
                          onTap: () {
                             SoundService().playClick(); // Click sound on Content Item
                             Navigator.push(
                               context,
                               MaterialPageRoute(builder: (context) => ReadingScreen(item: item, sectionTitle: section.title)),
                             );
                          },
                        ),
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
