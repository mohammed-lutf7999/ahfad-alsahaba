import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/challenge_game_service.dart';
import '../../../data/services/nearby_service.dart' as nearby;
import 'waiting_room_screen.dart';

/// شاشة البحث والانضمام لتحدي
class JoinChallengeScreen extends StatefulWidget {
  const JoinChallengeScreen({super.key});

  @override
  State<JoinChallengeScreen> createState() => _JoinChallengeScreenState();
}

class _JoinChallengeScreenState extends State<JoinChallengeScreen>
    with TickerProviderStateMixin {
  late AnimationController _searchController;
  bool _isSearching = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    
    _searchController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    nearby.NearbyService.instance.addListener(_onNearbyStateChanged);
    _startSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    nearby.NearbyService.instance.removeListener(_onNearbyStateChanged);
    super.dispose();
  }

  void _onNearbyStateChanged() {
    if (mounted) {
      setState(() {});
      
      // التحقق من الاتصال الناجح
      final connectionState = nearby.NearbyService.instance.connectionState;
      debugPrint('🔄 Nearby state changed: $connectionState');
      
      if (connectionState == nearby.ConnectionState.connected && !_isConnecting) {
        debugPrint('✅ Connected! Navigating to waiting room...');
        _navigateToWaitingRoom();
      }
    }
  }

  Future<void> _startSearch() async {
    setState(() => _isSearching = true);
    await ChallengeGameService.instance.initAsClient();
    setState(() => _isSearching = false);
  }

  void _navigateToWaitingRoom() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoveredChallenges = nearby.NearbyService.instance.discoveredChallenges;
    
    return WillPopScope(
      onWillPop: () async {
        await nearby.NearbyService.instance.stopAll();
        return true;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                
                // Search Animation
                _buildSearchIndicator(),
                
                const SizedBox(height: 20),
                
                // Discovered Challenges List
                Expanded(
                  child: discoveredChallenges.isEmpty
                      ? _buildEmptyState()
                      : _buildChallengesList(discoveredChallenges),
                ),
                
                // Refresh Button
                _buildRefreshButton(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title and Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 10)],
                ),
                child: const Icon(Icons.search_rounded, color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accentLight, AppTheme.accentColor],
                ).createShader(bounds),
                child: const Text(
                  'البحث عن تحدي',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // Back button
          GestureDetector(
            onTap: () async {
              SoundService().playClick();
              await nearby.NearbyService.instance.stopAll();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.accentColor, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _searchController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing circles
                  ...List.generate(3, (index) {
                    final delay = index * 0.3;
                    final progress = (_searchController.value + delay) % 1.0;
                    return Container(
                      width: 100 + (progress * 50),
                      height: 100 + (progress * 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentColor.withOpacity(1 - progress),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                  // Center icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentColor.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.accentColor,
                      size: 40,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'جاري البحث...' : 'ابحث عن تحديات قريبة',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_tethering_off_rounded,
            size: 60,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد تحديات قريبة',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تأكد من تفعيل البلوتوث والموقع',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesList(List discoveredChallenges) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: discoveredChallenges.length,
      itemBuilder: (context, index) {
        final challenge = discoveredChallenges[index];
        return _buildChallengeCard(challenge);
      },
    );
  }

  Widget _buildChallengeCard(nearby.DiscoveredChallenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _isConnecting ? null : () => _joinChallenge(challenge),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentColor.withOpacity(0.15),
                AppTheme.accentColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              // Host Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentColor.withOpacity(0.2),
                ),
                child: const Center(
                  child: Text('👤', style: TextStyle(fontSize: 24)),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Challenge Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.hostName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.wifi_rounded,
                          size: 14,
                          color: Colors.green.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'متاح للانضمام',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Join Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentLight, AppTheme.accentColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryDark,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'انضم',
                        style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _isSearching ? null : _startSearch,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.refresh_rounded,
                color: Colors.white.withOpacity(_isSearching ? 0.3 : 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'إعادة البحث',
                style: TextStyle(
                  color: Colors.white.withOpacity(_isSearching ? 0.3 : 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinChallenge(nearby.DiscoveredChallenge challenge) async {
    setState(() => _isConnecting = true);
    
    SoundService().playClick();
    debugPrint('🔗 Attempting to join challenge: ${challenge.hostName}');
    
    final success = await nearby.NearbyService.instance.requestConnection(
      endpointId: challenge.endpointId,
      playerName: ChallengeGameService.instance.localPlayer?.name ?? 'Player',
    );
    
    debugPrint('🔗 Connection request result: $success');
    
    if (success && mounted) {
      // انتظار لحظة للتأكد من إتمام الاتصال
      await Future.delayed(const Duration(milliseconds: 500));
      
      // التحقق من حالة الاتصال
      if (nearby.NearbyService.instance.connectionState == nearby.ConnectionState.connected) {
        debugPrint('✅ Connected successfully! Navigating to waiting room...');
        _navigateToWaitingRoom();
      } else {
        debugPrint('⏳ Waiting for connection to complete...');
        // الانتقال سيتم عبر _onNearbyStateChanged
      }
    } else if (!success && mounted) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل الاتصال، حاول مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
