import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/quote_model.dart';

/// كبسولة نور وهداية المدمجة المتجاوبة بالهوية الملكية الأندلسية
/// توفر قراءة رشيقة للأقوال المأثورة بمساحة رأسية محسوبة (~92px)
/// مع إمكانية النقر لقراءة المقولة كاملة ونسخها أو مشاركتها
class IslamicQuoteCard extends StatefulWidget {
  final List<Quote> quotes;

  const IslamicQuoteCard({
    super.key,
    required this.quotes,
  });

  @override
  State<IslamicQuoteCard> createState() => _IslamicQuoteCardState();
}

class _IslamicQuoteCardState extends State<IslamicQuoteCard> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showFullQuoteSheet(BuildContext context, Quote quote) {
    SoundService().playClick();
    final customTheme = AppCustomTheme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: customTheme.sovereignAccent.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: customTheme.sovereignAccent.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Title badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    color: customTheme.sovereignAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'قَبَسٌ مِن نُورِ السَّلَف • ${quote.title}',
                    style: TextStyle(
                      color: customTheme.sovereignAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Full quote text
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: customTheme.sovereignAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '« ${quote.text} »',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    height: 1.65,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Author & reference
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '— ${quote.author}',
                    style: TextStyle(
                      color: customTheme.sovereignAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${quote.reference})',
                    style: TextStyle(
                      color: customTheme.textMuted,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Action buttons (Copy quote)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    SoundService().playClick();
                    Clipboard.setData(
                      ClipboardData(
                        text: '« ${quote.text} »\n— ${quote.author} (${quote.reference})\nعبر تطبيق: معركة أحفاد الصحابة',
                      ),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'تم نسخ الحكمة المباركة بنجاح 📋',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                        backgroundColor: customTheme.surfaceCard,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: customTheme.sovereignAccent,
                    foregroundColor: AppTheme.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'نسخ الحكمة المباركة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quotes.isEmpty) {
      return const SizedBox.shrink();
    }

    final customTheme = AppCustomTheme.of(context);

    return SizedBox(
      height: 92,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.quotes.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final quote = widget.quotes[index];
          return GestureDetector(
            onTap: () => _showFullQuoteSheet(context, quote),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: customTheme.sovereignAccent.withValues(alpha: 0.35),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header Row: Category/Title on Right, Dots on Left
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '✨',
                              style: TextStyle(
                                fontSize: 11,
                                color: customTheme.sovereignAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'قَبَس من نور • ${quote.title}',
                                style: TextStyle(
                                  color: customTheme.sovereignAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sleek Inline Pagination Dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          widget.quotes.length,
                          (dotIndex) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(left: 3),
                            width: _currentPage == dotIndex ? 14 : 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _currentPage == dotIndex
                                  ? customTheme.sovereignAccent
                                  : Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: _currentPage == dotIndex
                                  ? [
                                      BoxShadow(
                                        color: customTheme.sovereignAccent.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Middle Row: Centered Quote Text (Max 2 lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '« ${quote.text} »',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Footer Row: Author & Reference
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          '— ${quote.author}  •  ${quote.reference}',
                          style: TextStyle(
                            color: customTheme.textMuted,
                            fontSize: 10,
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
