import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/grocery_item.dart';
import '../models/stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/account_service.dart';
import '../services/grocery_service.dart';
import '../services/routine_service.dart';
import '../services/grocery_pdf_service.dart';
import '../services/routine_pdf_service.dart';
import '../services/google_drive_service.dart';
import '../services/pdf_export_service.dart';
import '../services/sync_service.dart';
import 'unified_progress_modal.dart';

/// Modal bottom sheet providing Google Drive cloud backup options,
/// automated financial archival settings, and per-account backup toggles.
class ExportBackupModal extends StatefulWidget {
  const ExportBackupModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExportBackupModal(),
    );
  }

  @override
  State<ExportBackupModal> createState() => _ExportBackupModalState();
}

class _ExportBackupModalState extends State<ExportBackupModal> {
  bool _autoDriveBackup = true;
  String _backupFrequency = 'Daily';
  String _lastBackupTime = 'Never';
  bool _isBackingUp = false;
  String? _backupStatusMessage;
  bool _hasGoogleAuth = false;
  Set<String> _selectedAccountKeys = {};

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  Future<void> _loadBackupSettings() async {
    try {
      final token = await AuthService.getGoogleAccessToken();
      final prefs = await SharedPreferences.getInstance();

      final books = AccountService.accountsNotifier.value;
      final stores = GroceryService.cachedStores;

      final savedKeys = prefs.getStringList('gdrive_backup_selected_keys');
      final Set<String> activeKeys;

      if (savedKeys != null) {
        activeKeys = savedKeys.toSet();
      } else {
        // First launch: select all accounts by default
        activeKeys = <String>{};
        for (final b in books) {
          activeKeys.add('account_${b.id}');
        }
        for (final s in stores) {
          activeKeys.add('grocery_${s.id}');
        }
        activeKeys.add('daily_routine');
      }

      bool isTokenValid = false;
      if (token != null && token.isNotEmpty && !token.startsWith('eyJ')) {
        isTokenValid = await GoogleDriveDirectService.validateToken(token);
        if (!isTokenValid) {
          await AuthService.clearGoogleAccessToken();
        }
      }

      if (mounted) {
        setState(() {
          _hasGoogleAuth = isTokenValid;
          _autoDriveBackup = prefs.getBool('gdrive_auto_backup') ?? true;
          _backupFrequency = prefs.getString('gdrive_backup_frequency') ?? 'Daily';
          _lastBackupTime = prefs.getString('gdrive_last_backup_time') ?? 'Never';
          _selectedAccountKeys = activeKeys;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveBackupSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gdrive_auto_backup', _autoDriveBackup);
      await prefs.setString('gdrive_backup_frequency', _backupFrequency);
      await prefs.setString('gdrive_last_backup_time', _lastBackupTime);
      await prefs.setStringList('gdrive_backup_selected_keys', _selectedAccountKeys.toList());
    } catch (_) {}
  }

  Future<void> _connectGoogleDrive() async {
    if (_isBackingUp) return;

    // Show persistent in-flight notification while browser OAuth is active
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Waiting for Google authorization... Browser window me "Continue" per click karein.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF4F46E5),
        duration: Duration(seconds: 90),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final token = await AuthService.authorizeGoogleDrive();
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      await _loadBackupSettings();

      if (mounted && (token != null && token.isNotEmpty || _hasGoogleAuth)) {
        setState(() => _hasGoogleAuth = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Google Drive jud gaya! Ab backup upload ho raha hai...'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _performDriveBackup();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Drive authorization complete nahi hui. Kripya browser me "Continue" allow karein.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Drive connection notice: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showGoogleSignInPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_to_drive_rounded, color: Color(0xFF4285F4), size: 22),
            SizedBox(width: 10),
            Text('Connect Google Drive', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Google Drive backup requires authorization with your Google Account.\n\n'
          'Would you like to connect your Google Account now to enable automatic PDF statement backups into your Drive folder?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Drive connection skipped. You can still export & print statements locally.'),
                  backgroundColor: Color(0xFF64748B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _connectGoogleDrive();
            },
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text('Connect Google Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDrivePermissionRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_person_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 10),
            Text('Google Drive Permission Required', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Google Drive me PDF statement backup upload karne ke liye Drive permissions ki zaroorat hai.\n\n'
          'Kripya "Authorize Google Drive" per tap karein aur permission allow karein.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _connectGoogleDrive();
            },
            icon: const Icon(Icons.security_update_good_rounded, size: 16),
            label: const Text('Authorize Google Drive', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDriveBackup() async {
    final token = await AuthService.getGoogleAccessToken();

    if (token == null || token.isEmpty || token.startsWith('eyJ')) {
      await AuthService.clearGoogleAccessToken();
      if (mounted) setState(() => _hasGoogleAuth = false);
      _showGoogleSignInPrompt();
      return;
    }

    // Validate that the token is active and has Drive scope
    final isTokenActive = await GoogleDriveDirectService.validateToken(token);
    if (!isTokenActive) {
      await AuthService.clearGoogleAccessToken();
      if (mounted) {
        setState(() => _hasGoogleAuth = false);
        _showDrivePermissionRequiredDialog();
      }
      return;
    }

    if (_selectedAccountKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kripya backup ke liye kam se kam 1 account chunein.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isBackingUp = true;
      _backupStatusMessage = 'Preparing backup upload...';
    });

    final uploadedFiles = <Map<String, String>>[];
    final failedItems = <String>[];
    bool authErrorOccurred = false;
    String authErrorMessage = '';

    try {
      await UnifiedProgressModal.show(
        context: context,
        title: 'Google Drive Cloud Backup',
        subtitle: '${_selectedAccountKeys.length} Accounts Selected',
        icon: Icons.cloud_upload_rounded,
        iconColor: const Color(0xFF4285F4),
        task: (progress) async {
          final books = AccountService.accountsNotifier.value;
          final stores = GroceryService.cachedStores;
          final totalToUpload = _selectedAccountKeys.length;
          int currentIdx = 0;

          // 1. Personal Accounts & Books
          for (final book in books) {
            if (authErrorOccurred) break;
            final key = 'account_${book.id}';
            if (_selectedAccountKeys.contains(key)) {
              currentIdx++;
              progress.update(
                status: 'Uploading ($currentIdx/$totalToUpload): ${book.name}...',
                progress: currentIdx / (totalToUpload + 0.5),
              );
              try {
                var stats = SyncService.cachedStats;
                var txs = SyncService.cachedTransactions
                    .where((t) => t.accountId == book.id)
                    .toList();
                try {
                  stats = await ApiService.getDashboardStats(accountId: book.id);
                  final freshTxs = await ApiService.getTransactions(accountId: book.id, limit: 300);
                  if (freshTxs.isNotEmpty) txs = freshTxs;
                } catch (_) {}

                final pdfBytes = await PdfExportService.generateA4PdfBytes(
                  stats: stats ??
                      DashboardStats(
                        netAccountBalance: 0,
                        totalMoneyIn: 0,
                        totalMoneyOut: 0,
                        totalReceivable: 0,
                        totalPayable: 0,
                        netLenDenPosition: 0,
                        totalIncome: 0,
                        totalExpense: 0,
                        netSavings: 0,
                        peopleToReceiveCount: 0,
                        peopleToPayCount: 0,
                        totalTransactionsCount: txs.length,
                        categoryBreakdown: const [],
                        topDebtors: const [],
                        topCreditors: const [],
                        monthlyTrends: const [],
                      ),
                  transactions: txs,
                  isFastMode: false,
                );

                final cleanName = book.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
                final fileName = 'msmkhata_personal_${cleanName}_$dateStr.pdf';

                await GoogleDriveDirectService.uploadPdfBytes(
                  accessToken: token,
                  bytes: pdfBytes,
                  fileName: fileName,
                );

                uploadedFiles.add({
                  'title': book.name,
                  'filename': fileName,
                  'type': 'Personal Book',
                });
              } catch (e) {
                final errStr = e.toString();
                debugPrint('Personal book backup error for ${book.name}: $errStr');
                if (errStr.contains('401') ||
                    errStr.contains('403') ||
                    errStr.contains('ACCESS_TOKEN') ||
                    errStr.contains('Invalid Credentials') ||
                    errStr.contains('PERMISSION_DENIED')) {
                  authErrorOccurred = true;
                  authErrorMessage = errStr;
                  break;
                }
                failedItems.add(book.name);
              }
            }
          }

          // 2. Grocery & Dukaan Khatas
          for (final store in stores) {
            if (authErrorOccurred) break;
            final key = 'grocery_${store.id}';
            if (_selectedAccountKeys.contains(key)) {
              currentIdx++;
              progress.update(
                status: 'Uploading ($currentIdx/$totalToUpload): ${store.storeName}...',
                progress: currentIdx / (totalToUpload + 0.5),
              );
              try {
                final entries = GroceryService.cachedEntriesByStore[store.id] ?? <GroceryEntry>[];
                final pdfBytes = await GroceryPdfService.generateStorePdfBytes(store: store, entries: entries);
                final cleanName = store.storeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
                final fileName = 'msmkhata_dukaan_${cleanName}_$dateStr.pdf';

                await GoogleDriveDirectService.uploadPdfBytes(
                  accessToken: token,
                  bytes: pdfBytes,
                  fileName: fileName,
                );
                uploadedFiles.add({
                  'title': store.storeName,
                  'filename': fileName,
                  'type': 'Dukaan Khata',
                });
              } catch (e) {
                final errStr = e.toString();
                debugPrint('Grocery store backup error for ${store.storeName}: $errStr');
                if (errStr.contains('401') ||
                    errStr.contains('403') ||
                    errStr.contains('ACCESS_TOKEN') ||
                    errStr.contains('Invalid Credentials') ||
                    errStr.contains('PERMISSION_DENIED')) {
                  authErrorOccurred = true;
                  authErrorMessage = errStr;
                  break;
                }
                failedItems.add(store.storeName);
              }
            }
          }

          // 3. Daily Routine & Work Diary
          if (!authErrorOccurred && _selectedAccountKeys.contains('daily_routine')) {
            currentIdx++;
            progress.update(
              status: 'Uploading ($currentIdx/$totalToUpload): Daily Routine Diary...',
              progress: currentIdx / (totalToUpload + 0.5),
            );
            try {
              final entries = RoutineService.cachedEntries;
              final pdfBytes = await RoutinePdfService.generateRoutinePdfBytes(entries: entries);
              final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
              final fileName = 'msmkhata_daily_routine_$dateStr.pdf';

              await GoogleDriveDirectService.uploadPdfBytes(
                accessToken: token,
                bytes: pdfBytes,
                fileName: fileName,
              );
              uploadedFiles.add({
                'title': 'Daily Routine & Work Diary',
                'filename': fileName,
                'type': 'Work Diary',
              });
            } catch (e) {
              final errStr = e.toString();
              debugPrint('Daily routine backup error: $errStr');
              if (errStr.contains('401') ||
                  errStr.contains('403') ||
                  errStr.contains('ACCESS_TOKEN') ||
                  errStr.contains('Invalid Credentials') ||
                  errStr.contains('PERMISSION_DENIED')) {
                authErrorOccurred = true;
                authErrorMessage = errStr;
              } else {
                failedItems.add('Daily Routine Diary');
              }
            }
          }

          if (!authErrorOccurred) {
            progress.update(
              status: 'All backups saved to Google Drive! ☁️',
              progress: 1.0,
            );
          }
        },
      );

      // If authentication expired or permission was revoked mid-upload
      if (authErrorOccurred) {
        await AuthService.clearGoogleAccessToken();
        if (mounted) {
          setState(() => _hasGoogleAuth = false);
          _showDrivePermissionRequiredDialog();
        }
        return;
      }

      final nowStr = DateFormat('Today, hh:mm a').format(DateTime.now());
      if (mounted) {
        setState(() {
          _lastBackupTime = nowStr;
        });
      }
      _saveBackupSettings();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                Icon(
                  failedItems.isEmpty ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: failedItems.isEmpty ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  failedItems.isEmpty ? 'All Backups Uploaded!' : 'Backup Notice',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340, maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${uploadedFiles.length} official statement PDFs safely Google Drive ke "MsmKhata Backups" folder me upload ho gaye:',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    ...uploadedFiles.map((f) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF10B981), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f['title'] ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      f['filename'] ?? '',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (failedItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Failed to upload: ${failedItems.join(", ")}',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.folder_open_rounded, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Destination: Google Drive > MsmKhata Backups',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') ||
          errStr.contains('ACCESS_TOKEN_EXPIRED') ||
          errStr.contains('insufficient authentication scopes') ||
          errStr.contains('PERMISSION_DENIED') ||
          errStr.contains('Invalid Credentials') ||
          errStr.contains('401') ||
          errStr.contains('403')) {
        await AuthService.clearGoogleAccessToken();
        if (mounted) {
          setState(() => _hasGoogleAuth = false);
          _showDrivePermissionRequiredDialog();
        }
        return;
      }
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 24),
                SizedBox(width: 10),
                Text('Backup Failed', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'PDF statement Google Drive me upload nahi ho pa rahi:\n\n$e\n\nKripya apna internet connection check karein ya Google account reconnect karein.',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Dismiss', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4285F4)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showGoogleSignInPrompt();
                },
                child: const Text('Reconnect Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _backupStatusMessage = null;
        });
      }
    }
  }

  Widget _buildToggleSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF818CF8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildAccountToggleTile({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _selectedAccountKeys.contains(key);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF0F172A).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? iconColor.withValues(alpha: 0.45) : const Color(0xFF334155).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isSelected,
              activeColor: iconColor,
              onChanged: _isBackingUp
                  ? null
                  : (val) {
                      setState(() {
                        if (val) {
                          _selectedAccountKeys.add(key);
                        } else {
                          _selectedAccountKeys.remove(key);
                        }
                      });
                      _saveBackupSettings();
                    },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = AccountService.accountsNotifier.value;
    final stores = GroceryService.cachedStores;

    final allAccountKeys = <String>{
      ...books.map((b) => 'account_${b.id}'),
      ...stores.map((s) => 'grocery_${s.id}'),
      'daily_routine',
    };
    final totalAccountsCount = allAccountKeys.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF38BDF8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Google Drive Cloud Backup',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Automated cloud synchronization & archival',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    tooltip: 'Close',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Google Drive Cloud Backup Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_to_drive_rounded, color: Color(0xFF4285F4), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Google Drive Backup',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'PDF Statement Archival in Drive',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _hasGoogleAuth ? null : _showGoogleSignInPrompt,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _hasGoogleAuth
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _hasGoogleAuth ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_hasGoogleAuth) ...[
                                  const Icon(Icons.link_rounded, size: 12, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  _hasGoogleAuth ? 'Connected' : 'Connect Account',
                                  style: TextStyle(
                                    color: _hasGoogleAuth ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Automatic Backup Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Automatic Cloud Backup',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Backup ledger to Google Drive folder automatically',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _autoDriveBackup,
                            activeColor: const Color(0xFF4F46E5),
                            onChanged: (val) {
                              setState(() => _autoDriveBackup = val);
                              _saveBackupSettings();
                            },
                          ),
                        ],
                      ),
                    ),

                    if (_autoDriveBackup) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Frequency:',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                          Wrap(
                            spacing: 6,
                            children: ['Daily', 'Weekly', 'Manual'].map((freq) {
                              final isSel = _backupFrequency == freq;
                              return ChoiceChip(
                                label: Text(freq),
                                selected: isSel,
                                selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                backgroundColor: const Color(0xFF0F172A),
                                labelStyle: TextStyle(
                                  color: isSel ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                                side: BorderSide(color: isSel ? const Color(0xFF4F46E5) : Colors.transparent),
                                onSelected: (_) {
                                  setState(() => _backupFrequency = freq);
                                  _saveBackupSettings();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],

                    // Accounts Selection for Backup (Multi-Account Toggles)
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.checklist_rtl_rounded, color: Color(0xFF818CF8), size: 17),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Accounts to Backup (${_selectedAccountKeys.length}/$totalAccountsCount)',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _isBackingUp
                                    ? null
                                    : () {
                                        setState(() {
                                          if (_selectedAccountKeys.length == totalAccountsCount) {
                                            _selectedAccountKeys.clear();
                                          } else {
                                            _selectedAccountKeys = allAccountKeys.toSet();
                                          }
                                        });
                                        _saveBackupSettings();
                                      },
                                child: Text(
                                  _selectedAccountKeys.length == totalAccountsCount ? 'Deselect All' : 'Select All',
                                  style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Personal Accounts Group
                          _buildToggleSectionHeader('📘 PERSONAL ACCOUNTS & BOOKS'),
                          ...books.map((b) => _buildAccountToggleTile(
                                key: 'account_${b.id}',
                                title: b.name,
                                subtitle: b.isDefault ? 'Default Primary Account' : 'Isolated Khata Book',
                                icon: Icons.book_rounded,
                                iconColor: const Color(0xFF6366F1),
                              )),

                          // Grocery Khatas Group
                          if (stores.isNotEmpty) ...[
                            _buildToggleSectionHeader('🏪 GROCERY & DUKAAN KHATA'),
                            ...stores.map((s) => _buildAccountToggleTile(
                                  key: 'grocery_${s.id}',
                                  title: s.storeName,
                                  subtitle: '${s.category} • Balance: ₹${s.pendingBalance.toStringAsFixed(0)}',
                                  icon: Icons.storefront_rounded,
                                  iconColor: const Color(0xFF10B981),
                                )),
                          ],

                          // Daily Routine Group
                          _buildToggleSectionHeader('📅 DAILY ROUTINE & WORK DIARY'),
                          _buildAccountToggleTile(
                            key: 'daily_routine',
                            title: 'Daily Routine & Work Diary',
                            subtitle: 'Rozana kaam, categories, ghante aur kharche ka log',
                            icon: Icons.event_note_rounded,
                            iconColor: const Color(0xFF38BDF8),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Last backup status & folder info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 5),
                            Text(
                              'Last backup: $_lastBackupTime',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                        const Text(
                          'MsmKhata_Backups/',
                          style: TextStyle(color: Color(0xFF4285F4), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Backup Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _selectedAccountKeys.isEmpty ? const Color(0xFF475569) : const Color(0xFF4285F4),
                              width: 1,
                            ),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isBackingUp
                            ? null
                            : (_hasGoogleAuth
                                ? (_selectedAccountKeys.isEmpty ? null : _performDriveBackup)
                                : _connectGoogleDrive),
                        icon: _isBackingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload_outlined, color: Color(0xFF4285F4), size: 18),
                        label: Text(
                          _isBackingUp
                              ? (_backupStatusMessage ?? 'Uploading to Google Drive...')
                              : (!_hasGoogleAuth
                                  ? 'Connect Google Drive to Backup'
                                  : (_selectedAccountKeys.isEmpty
                                      ? 'Select at least 1 account to backup'
                                      : 'Backup ${_selectedAccountKeys.length} ${_selectedAccountKeys.length == 1 ? 'Account' : 'Accounts'} to Drive')),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedAccountKeys.isEmpty && _hasGoogleAuth && !_isBackingUp
                                ? const Color(0xFF64748B)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
