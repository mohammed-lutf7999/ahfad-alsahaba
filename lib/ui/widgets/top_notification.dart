import 'package:flutter/material.dart';

/// A beautiful top notification that slides down like a curtain
/// Use instead of SnackBar for more elegant notifications
class TopNotification {
  static OverlayEntry? _currentNotification;

  /// Show a notification from the top of the screen
  /// [context] - BuildContext
  /// [message] - The message to display
  /// [icon] - Icon to show (default: check icon)
  /// [backgroundColor] - Background color (default: green for success)
  /// [duration] - How long to show (default: 3 seconds)
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color backgroundColor = Colors.green,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Remove any existing notification
    _currentNotification?.remove();
    _currentNotification = null;

    final overlay = Overlay.of(context);
    
    _currentNotification = OverlayEntry(
      builder: (context) => _TopNotificationWidget(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        onDismiss: () {
          _currentNotification?.remove();
          _currentNotification = null;
        },
        duration: duration,
      ),
    );

    overlay.insert(_currentNotification!);
  }

  /// Show a success notification (green)
  static void showSuccess(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF2E7D32),
    );
  }

  /// Show an info notification (blue)
  static void showInfo(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.info_rounded,
      backgroundColor: const Color(0xFF1976D2),
    );
  }

  /// Show a warning notification (orange)
  static void showWarning(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.warning_rounded,
      backgroundColor: const Color(0xFFE65100),
    );
  }

  /// Show an error notification (red)
  static void showError(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: const Color(0xFFC62828),
    );
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onDismiss;
  final Duration duration;

  const _TopNotificationWidget({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                  _dismiss();
                }
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: statusBarHeight + 12,
                  bottom: 16,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.backgroundColor,
                      widget.backgroundColor.withValues(alpha: 0.95),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.backgroundColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _dismiss,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}