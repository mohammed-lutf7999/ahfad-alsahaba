import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/models/quote_model.dart';

/// بطاقة مقولة بتصميم إسلامي مزخرف
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
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.quotes.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: _QuoteCardItem(quote: widget.quotes[index]),
              );
            },
          ),
        ),
        // Page indicators
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.quotes.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppTheme.accentColor
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _currentPage == index
                      ? [
                          BoxShadow(
                            color: AppTheme.accentColor.withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuoteCardItem extends StatelessWidget {
  final Quote quote;

  const _QuoteCardItem({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppTheme.primaryLight.withOpacity(0.9),
            AppTheme.primaryColor,
            AppTheme.primaryDark.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Islamic pattern overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: _IslamicPatternPainter(),
                ),
              ),
            ),
          ),
          
          // Corner decorations
          Positioned(
            top: 8,
            right: 12,
            child: Text(
              '❁',
              style: TextStyle(
                fontSize: 20,
                color: AppTheme.accentColor.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 12,
            child: Text(
              '❁',
              style: TextStyle(
                fontSize: 20,
                color: AppTheme.accentColor.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 12,
            child: Text(
              '❁',
              style: TextStyle(
                fontSize: 20,
                color: AppTheme.accentColor.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 12,
            child: Text(
              '❁',
              style: TextStyle(
                fontSize: 20,
                color: AppTheme.accentColor.withOpacity(0.5),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title with decorative line
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppTheme.accentColor,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '﴿ ${quote.title} ﴾',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentColor,
                        fontFamily: 'Cairo',
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 30,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentColor,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Quote text with internal scrolling
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        '« ${quote.text} »',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.95),
                          fontFamily: 'Cairo',
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Divider
                Container(
                  width: 60,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppTheme.accentColor,
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Author
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 16,
                      color: AppTheme.accentLight.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      quote.author,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.accentLight,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Reference
                Text(
                  quote.reference,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// رسام النمط الإسلامي
class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 30.0;
    
    // Draw geometric pattern
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Draw 8-point star pattern
        _drawStar(canvas, Offset(x, y), 12, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 - 90) * 3.14159 / 180;
      final outerPoint = Offset(
        center.dx + size * 0.5 * (i.isEven ? 1 : 0.5) * (angle.isNaN ? 0 : (i % 2 == 0 ? 1 : 1)) + size * 0.5 * _cos(angle),
        center.dy + size * 0.5 * _sin(angle),
      );
      if (i == 0) {
        path.moveTo(outerPoint.dx, outerPoint.dy);
      } else {
        path.lineTo(outerPoint.dx, outerPoint.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double _cos(double angle) => math.cos(angle * math.pi / 180);
  double _sin(double angle) => math.sin(angle * math.pi / 180);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
