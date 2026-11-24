import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../data/services/nearby_service.dart' as nearby;

class NearbySearchIndicator extends StatelessWidget {
  final AnimationController searchController;
  final bool isSearching;

  const NearbySearchIndicator({
    super.key,
    required this.searchController,
    required this.isSearching,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: searchController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (index) {
                    final delay = index * 0.3;
                    final progress = (searchController.value + delay) % 1.0;
                    return Container(
                      width: 100 + (progress * 50),
                      height: 100 + (progress * 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentColor
                              .withValues(alpha: 1 - progress),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentColor.withValues(alpha: 0.2),
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
            isSearching ? 'جاري البحث...' : 'ابحث عن تحديات قريبة',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class NearbyChallengeCard extends StatelessWidget {
  final nearby.DiscoveredChallenge challenge;
  final bool isConnecting;
  final VoidCallback onJoin;

  const NearbyChallengeCard({
    super.key,
    required this.challenge,
    required this.isConnecting,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isConnecting ? null : onJoin,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentColor.withValues(alpha: 0.15),
                AppTheme.accentColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.accentColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                ),
                child: const Center(
                  child: Text('👤', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
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
                          color: Colors.green.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'متاح للانضمام',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentLight, AppTheme.accentColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isConnecting
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
}
