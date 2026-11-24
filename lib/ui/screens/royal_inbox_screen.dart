import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/app_control_models.dart';
import '../../data/services/app_control_service.dart';
import '../../data/services/royal_inbox_service.dart';
import 'inbox/royal_inbox_message_card.dart';

/// شاشة «صندوق البريد الملكي» لحفظ واستعراض إشعارات الإدارة والهدايا والتعويضات
/// مع دعم الكاش المحلي (0ms) والتصفية وتحديد الكل كمقروء.
class RoyalInboxScreen extends StatefulWidget {
  const RoyalInboxScreen({super.key});

  @override
  State<RoyalInboxScreen> createState() => _RoyalInboxScreenState();
}

class _RoyalInboxScreenState extends State<RoyalInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final RoyalInboxService _inbox = RoyalInboxService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _inbox.addListener(_onInboxChanged);
    AppControlService.instance.featureFlagsNotifier.addListener(_onInboxChanged);
    AppControlService.instance.isAdminNotifier.addListener(_onInboxChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inbox.fetchInbox();
    });
  }

  void _onInboxChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _inbox.removeListener(_onInboxChanged);
    AppControlService.instance.featureFlagsNotifier
        .removeListener(_onInboxChanged);
    AppControlService.instance.isAdminNotifier.removeListener(_onInboxChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final control = AppControlService.instance;
    final isEnabled = control.isAdminNotifier.value ||
        control.featureFlagsNotifier.value.royalInbox;
    final unread = _inbox.unreadCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: customTheme.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, customTheme, unread),
                if (!isEnabled)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'صندوق الرسائل متوقف مؤقتاً للصيانة من الإدارة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: customTheme.surfaceCard.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: customTheme.sovereignAccent.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: customTheme.sovereignAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: AppTheme.primaryDark,
                        unselectedLabelColor: Colors.white70,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(
                            text:
                                'الإعلانات (${_inbox.announcementMessages.length})',
                          ),
                          Tab(
                            text:
                                'الهدايا والتعويضات (${_inbox.rewardMessages.length})',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_inbox.lastError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _inbox.lastError!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.amberAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _inbox.isLoading && _inbox.messages.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(
                              color: customTheme.sovereignAccent,
                            ),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildMessageList(
                                _inbox.announcementMessages,
                                emptyTitle: 'لا توجد إعلانات أو رسائل حالياً',
                                emptySub:
                                    'ستظهر هنا رسائل الإدارة وتنبيهات البطولات والتحديثات.',
                              ),
                              _buildMessageList(
                                _inbox.rewardMessages,
                                emptyTitle: 'لا توجد هدايا أو تعويضات مسجلة',
                                emptySub:
                                    'عند حصولك على مكافأة أو تعويض من الإدارة ستصل بطاقتها هنا.',
                              ),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppCustomTheme customTheme,
    int unread,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              SoundService().playClick();
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صندوق البريد الملكي 📬',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: customTheme.sovereignAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                Text(
                  unread > 0
                      ? 'لديك $unread رسالة غير مقروءة'
                      : 'جميع الرسائل مقروءة ومحدّثة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0)
            TextButton.icon(
              key: const Key('inbox_mark_all_read_btn'),
              onPressed: () {
                SoundService().playClick();
                _inbox.markAllRead();
              },
              icon: Icon(
                Icons.done_all_rounded,
                size: 16,
                color: customTheme.sovereignAccent,
              ),
              label: Text(
                'قراءة الكل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: customTheme.sovereignAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            onPressed: _inbox.isLoading
                ? null
                : () {
                    SoundService().playClick();
                    _inbox.fetchInbox();
                  },
            icon: Icon(
              Icons.refresh_rounded,
              color: customTheme.sovereignAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    List<RoyalInboxMessage> items, {
    required String emptyTitle,
    required String emptySub,
  }) {
    final customTheme = AppCustomTheme.of(context);
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _inbox.fetchInbox(),
        color: customTheme.sovereignAccent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.mark_email_read_outlined,
              size: 56,
              color: customTheme.sovereignAccent.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptySub,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _inbox.fetchInbox(),
      color: customTheme.sovereignAccent,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => RoyalInboxMessageCard(
          item: items[index],
          onMarkRead: _inbox.markMessageRead,
        ),
      ),
    );
  }
}
