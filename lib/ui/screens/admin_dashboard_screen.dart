import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/services/admin_service.dart';
import 'admin_email_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await AdminService().getStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header بسيط وأنيق
              _buildHeader(),

              // المحتوى الرئيسي
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : RefreshIndicator(
                        onRefresh: _loadStats,
                        color: AppTheme.accentColor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // بطاقات الإحصائيات
                              _buildStatsSection(),
                              
                              const SizedBox(height: 32),
                              
                              // قسم الإجراءات
                              _buildActionsSection(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // زر الرجوع
          _buildBackButton(),
          const SizedBox(width: 16),
          // العنوان
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'لوحة التحكم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_lastUpdated != null)
                  Text(
                    'آخر تحديث: ${_formatTime(_lastUpdated!)}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(120),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // زر التحديث
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _loadStats,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accentColor.withAlpha(60)),
        ),
        child: Icon(
          Icons.refresh_rounded,
          color: AppTheme.accentColor,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.accentColor),
          const SizedBox(height: 16),
          Text(
            'جاري التحميل...',
            style: TextStyle(color: Colors.white.withAlpha(150)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // عنوان القسم
        const Text(
          'الإحصائيات',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // بطاقات الإحصائيات
        Row(
          children: [
            // بطاقة المتصلين الآن
            Expanded(
              child: _buildStatCard(
                title: 'المتصلين الآن',
                value: '${_stats['onlineUsers'] ?? 0}',
                icon: Icons.wifi_tethering_rounded,
                color: Colors.green,
                isLive: true,
              ),
            ),
            const SizedBox(width: 16),
            // بطاقة إجمالي المستخدمين
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي المستخدمين',
                value: '${_stats['totalUsers'] ?? 0}',
                icon: Icons.people_alt_rounded,
                color: AppTheme.accentColor,
                isLive: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isLive,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Column(
        children: [
          // الأيقونة مع مؤشر الحالة
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              // مؤشر الحالة النشطة
              if (isLive)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryDark, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withAlpha(150),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // الرقم
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          
          // العنوان
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // عنوان القسم
        const Text(
          'الإجراءات',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // بطاقة إرسال البريد
        _buildActionCard(
          title: 'إرسال بريد إلكتروني',
          subtitle: 'مراسلة المستخدمين',
          icon: Icons.email_rounded,
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminEmailScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // الأيقونة
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            
            // النصوص
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // سهم الانتقال
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white.withAlpha(100),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
