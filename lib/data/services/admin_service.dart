import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if the current user is an admin
  bool get isAdmin {
    final user = _supabase.auth.currentUser;
    return user != null && user.email == 'dia666111@gmail.com';
  }

  /// Fetch dashboard statistics via Edge Function
  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _supabase.functions.invoke('admin-stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching admin stats via Edge Function: $e');
      
      // Fallback: Try client-side count
      try {
        final countResponse = await _supabase
            .from('leaderboard')
            .count(CountOption.exact);
            
        return {
          'totalUsers': countResponse,
          'onlineUsers': 0, 
          'isFallback': true
        };
      } catch (fallbackError) {
        debugPrint('Fallback stats failed: $fallbackError');
        return {'totalUsers': 0, 'onlineUsers': 0, 'error': e.toString()};
      }
    }
  }

  /// Get all users from leaderboard (for email list)
  /// Note: This depends on RLS policies allowing read access to leaderboard
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('leaderboard')
          .select('display_name, email, score, created_at')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  /// Send broadcast email via Edge Function
  Future<bool> sendBroadcast({
    required List<String> emails,
    required String subject,
    required String message,
  }) async {
    try {
      await _supabase.functions.invoke(
        'admin-broadcast',
        body: {
          'recipients': emails,
          'subject': subject,
          'message': message,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
      return false;
    }
  }
}
