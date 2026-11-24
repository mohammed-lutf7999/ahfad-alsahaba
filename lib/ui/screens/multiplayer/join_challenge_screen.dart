import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/challenge_game_service.dart';
import '../../../data/services/nearby_service.dart' as nearby;
import 'waiting_room_screen.dart';
import 'widgets/nearby_challenge_card.dart';

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
    if (!mounted) return;
    setState(() {});
    final connectionState = nearby.NearbyService.instance.connectionState;
    debugPrint('🔄 Nearby state changed: $connectionState');
    if (connectionState == nearby.ConnectionState.connected && !_isConnecting) {
      debugPrint('✅ Connected! Navigating to waiting room...');
      _navigateToWaitingRoom();
    }
  }

  Future<void> _startSearch() async {
    setState(() => _isSearching = true);
    await ChallengeGameService.instance.initAsClient();
    if (mounted) setState(() => _isSearching = false);
  }

  void _navigateToWaitingRoom() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
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
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (nearby.NearbyService.instance.connectionState ==
          nearby.ConnectionState.connected) {
        debugPrint('✅ Connected successfully! Navigating to waiting room...');
        _navigateToWaitingRoom();
      } else {
        debugPrint('⏳ Waiting for connection to complete...');
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

  @override
  Widget build(BuildContext context) {
    final discoveredChallenges =
        nearby.NearbyService.instance.discoveredChallenges;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        nearby.NearbyService.instance.stopAll();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                NearbySearchIndicator(
                  searchController: _searchController,
                  isSearching: _isSearching,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: discoveredChallenges.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: discoveredChallenges.length,
                          itemBuilder: (context, index) {
                            final challenge = discoveredChallenges[index];
                            return NearbyChallengeCard(
                              challenge: challenge,
                              isConnecting: _isConnecting,
                              onJoin: () => _joinChallenge(challenge),
                            );
                          },
                        ),
                ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withAlpha(80),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accentLight, AppTheme.accentColor],
                ).createShader(bounds),
                child: const Text(
                  'البحث عن تحدي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () async {
              SoundService().playClick();
              await nearby.NearbyService.instance.stopAll();
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.accentColor,
                size: 20,
              ),
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
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد تحديات قريبة',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تأكد من تفعيل البلوتوث والموقع',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
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
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.refresh_rounded,
                color:
                    Colors.white.withValues(alpha: _isSearching ? 0.3 : 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'إعادة البحث',
                style: TextStyle(
                  color:
                      Colors.white.withValues(alpha: _isSearching ? 0.3 : 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
