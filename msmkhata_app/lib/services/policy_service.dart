import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Global System Governance & Policy Enforcement Service for MsmKhata.
///
/// Controls enterprise policy toggles:
/// 1. Entry Update / Edit (allow_entry_update)
/// 2. Entry Deletion (allow_entry_delete)
/// 3. Date Modification (allow_date_edit)
class PolicyService {
  static const String _kAllowEntryUpdate = 'policy_allow_entry_update';
  static const String _kAllowEntryDelete = 'policy_allow_entry_delete';
  static const String _kAllowDateEdit = 'policy_allow_date_edit';

  // In-memory reactive state
  static final ValueNotifier<bool> allowEntryUpdateNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> allowEntryDeleteNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> allowDateEditNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<int> policyVersion = ValueNotifier<int>(0);

  static bool get canEditEntry => allowEntryUpdateNotifier.value;
  static bool get canDeleteEntry => allowEntryDeleteNotifier.value;
  static bool get canEditDate => allowDateEditNotifier.value;

  static bool _initialized = false;

  /// Initialize and restore policy cache from storage & cloud
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      allowEntryUpdateNotifier.value = prefs.getBool(_kAllowEntryUpdate) ?? true;
      allowEntryDeleteNotifier.value = prefs.getBool(_kAllowEntryDelete) ?? true;
      allowDateEditNotifier.value = prefs.getBool(_kAllowDateEdit) ?? true;

      // Fetch fresh policies from cloud
      await fetchPolicies();

      // Subscribe to Realtime policy updates from Supabase
      _setupRealtimeSubscription();
    } catch (e) {
      debugPrint('PolicyService initialize notice: $e');
    }
  }

  /// Fetch policies from Supabase / Backend
  static Future<void> fetchPolicies() async {
    try {
      // 1. Direct fetch via Supabase Client
      final client = Supabase.instance.client;
      final res = await client.from('system_settings').select('key, value');
      if (res.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        for (final row in res) {
          final key = row['key'] as String?;
          final val = row['value'];
          final bool boolVal = val == true || val == 'true';

          if (key == 'allow_entry_update') {
            allowEntryUpdateNotifier.value = boolVal;
            await prefs.setBool(_kAllowEntryUpdate, boolVal);
          } else if (key == 'allow_entry_delete') {
            allowEntryDeleteNotifier.value = boolVal;
            await prefs.setBool(_kAllowEntryDelete, boolVal);
          } else if (key == 'allow_date_edit') {
            allowDateEditNotifier.value = boolVal;
            await prefs.setBool(_kAllowDateEdit, boolVal);
          }
        }
        policyVersion.value++;
        return;
      }
    } catch (e) {
      debugPrint('PolicyService cloud fetch notice: $e');
    }

    // Fallback: Try backend API
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/admin/settings');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();

        if (map.containsKey('allow_entry_update')) {
          final v = map['allow_entry_update'] == true;
          allowEntryUpdateNotifier.value = v;
          await prefs.setBool(_kAllowEntryUpdate, v);
        }
        if (map.containsKey('allow_entry_delete')) {
          final v = map['allow_entry_delete'] == true;
          allowEntryDeleteNotifier.value = v;
          await prefs.setBool(_kAllowEntryDelete, v);
        }
        if (map.containsKey('allow_date_edit')) {
          final v = map['allow_date_edit'] == true;
          allowDateEditNotifier.value = v;
          await prefs.setBool(_kAllowDateEdit, v);
        }
        policyVersion.value++;
      }
    } catch (_) {}
  }

  /// Listen to Supabase Realtime table changes on system_settings
  static void _setupRealtimeSubscription() {
    try {
      final client = Supabase.instance.client;
      client
          .channel('public:system_settings')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'system_settings',
            callback: (payload) {
              final newRow = payload.newRecord;
              if (newRow.isNotEmpty) {
                final key = newRow['key'] as String?;
                final val = newRow['value'];
                final bool boolVal = val == true || val == 'true';

                if (key == 'allow_entry_update') {
                  allowEntryUpdateNotifier.value = boolVal;
                } else if (key == 'allow_entry_delete') {
                  allowEntryDeleteNotifier.value = boolVal;
                } else if (key == 'allow_date_edit') {
                  allowDateEditNotifier.value = boolVal;
                }
                policyVersion.value++;
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime policy subscription notice: $e');
    }
  }

  /// Update policy toggle (Admin only)
  static Future<bool> updatePolicy(String key, bool value) async {
    try {
      final client = Supabase.instance.client;
      await client.from('system_settings').upsert({
        'key': key,
        'value': value,
      });

      // Update in-memory and storage immediately
      final prefs = await SharedPreferences.getInstance();
      if (key == 'allow_entry_update') {
        allowEntryUpdateNotifier.value = value;
        await prefs.setBool(_kAllowEntryUpdate, value);
      } else if (key == 'allow_entry_delete') {
        allowEntryDeleteNotifier.value = value;
        await prefs.setBool(_kAllowEntryDelete, value);
      } else if (key == 'allow_date_edit') {
        allowDateEditNotifier.value = value;
        await prefs.setBool(_kAllowDateEdit, value);
      }
      policyVersion.value++;
      return true;
    } catch (e) {
      debugPrint('Failed to update policy: $e');
      return false;
    }
  }

  /// Display a standard British English restriction popup when user taps a locked action
  static Future<void> showRestrictedDialog(
    BuildContext context, {
    String title = 'Action Restricted',
    required String message,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEAB308), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAB308).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_person_rounded, color: Color(0xFFEAB308), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155), width: 0.8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You may still create new ledger entries without restriction.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

