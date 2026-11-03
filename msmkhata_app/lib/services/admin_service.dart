import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class AdminUserItem {
  final String id;
  final String email;
  final String displayName;
  final String avatarUrl;
  final String role;
  final bool isSuspended;
  final DateTime? suspendedAt;
  final DateTime? createdAt;
  final int transactionsCount;

  AdminUserItem({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.role,
    required this.isSuspended,
    this.suspendedAt,
    this.createdAt,
    this.transactionsCount = 0,
  });

  bool get isPrimaryAdmin => email.trim().toLowerCase() == AuthService.primaryAdminEmail;

  factory AdminUserItem.fromMap(Map<String, dynamic> map, {int txCount = 0}) {
    return AdminUserItem(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? (map['email']?.toString().split('@').first ?? 'User'),
      avatarUrl: map['avatar_url']?.toString() ?? '',
      role: map['role']?.toString() ?? 'user',
      isSuspended: map['is_suspended'] == true,
      suspendedAt: map['suspended_at'] != null ? DateTime.tryParse(map['suspended_at'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      transactionsCount: txCount,
    );
  }
}

class AdminDashboardStats {
  final int totalUsers;
  final int activeUsers;
  final int suspendedUsers;
  final int totalTransactions;

  AdminDashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.totalTransactions,
  });
}

class AdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Fetch overview metrics for the Admin Dashboard
  static Future<AdminDashboardStats> fetchDashboardStats() async {
    try {
      final profiles = await _client.from('profiles').select('id, is_suspended');
      final total = profiles.length;
      final suspended = profiles.where((p) => p['is_suspended'] == true).length;
      final active = total - suspended;

      final txCountRes = await _client.from('transactions').select('id');
      final totalTx = txCountRes.length;

      return AdminDashboardStats(
        totalUsers: total,
        activeUsers: active,
        suspendedUsers: suspended,
        totalTransactions: totalTx,
      );
    } catch (e) {
      debugPrint('Error fetching admin dashboard stats: $e');
      return AdminDashboardStats(totalUsers: 0, activeUsers: 0, suspendedUsers: 0, totalTransactions: 0);
    }
  }

  /// Fetch list of registered users with transaction counts
  static Future<List<AdminUserItem>> fetchUsersList() async {
    try {
      final profiles = await _client.from('profiles').select('*').order('created_at', ascending: false);
      final List<AdminUserItem> users = [];

      for (final p in profiles) {
        final uid = p['id']?.toString() ?? '';
        int txCount = 0;
        if (uid.isNotEmpty) {
          try {
            final txRes = await _client.from('transactions').select('id').eq('user_id', uid);
            txCount = txRes.length;
          } catch (_) {}
        }
        users.add(AdminUserItem.fromMap(p, txCount: txCount));
      }
      return users;
    } catch (e) {
      debugPrint('Error fetching users in AdminService: $e');
      rethrow;
    }
  }

  /// Suspend or unsuspend a user account
  static Future<void> toggleUserSuspension({
    required String userId,
    required String userEmail,
    required bool suspend,
  }) async {
    if (userEmail.trim().toLowerCase() == AuthService.primaryAdminEmail) {
      throw Exception('The primary administrator account cannot be suspended.');
    }

    await _client.from('profiles').update({
      'is_suspended': suspend,
      'suspended_at': suspend ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', userId);
  }

  /// Permanently delete a user account and associated personal data
  static Future<void> deleteUserAccount({
    required String userId,
    required String userEmail,
  }) async {
    if (userEmail.trim().toLowerCase() == AuthService.primaryAdminEmail) {
      throw Exception('The primary administrator account cannot be deleted.');
    }

    // Cascade delete user data
    await _client.from('transactions').delete().eq('user_id', userId);
    await _client.from('persons').delete().eq('user_id', userId);
    await _client.from('categories').delete().eq('user_id', userId);
    await _client.from('saved_filters').delete().eq('user_id', userId);
    await _client.from('profiles').delete().eq('id', userId);
  }
}

