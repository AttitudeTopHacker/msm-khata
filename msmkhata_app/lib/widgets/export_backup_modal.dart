import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Modal bottom sheet providing Google Drive cloud backup options
/// and automated financial archival settings.
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
  bool _hasGoogleAuth = false;

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  Future<void> _loadBackupSettings() async {
    try {
      final token = await AuthService.getGoogleAccessToken();
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hasGoogleAuth = token != null && token.isNotEmpty;
          _autoDriveBackup = prefs.getBool('gdrive_auto_backup') ?? true;
          _backupFrequency = prefs.getString('gdrive_backup_frequency') ?? 'Daily';
          _lastBackupTime = prefs.getString('gdrive_last_backup_time') ?? 'Never';
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

    if (token == null || token.isEmpty) {
      _connectGoogleDrive();
      return;
    }

    setState(() => _isBackingUp = true);
    try {
      final res = await ApiService.uploadBackupToGoogleDrive(
        googleAccessToken: token,
        userId: AuthService.currentUserId,
        includeExcel: false,
        includePdf: true,
      );

      final uploaded = res['uploaded_files'] as List<dynamic>? ?? [];
      final fileName = uploaded.isNotEmpty ? uploaded[0]['filename'] ?? 'Statement.pdf' : 'Statement.pdf';

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
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 10),
                Text('Backup Uploaded!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aapka official statement PDF "$fileName" safely Google Drive ke "MsmKhata Backups" folder me upload ho gaya hai.',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: const [
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
          errStr.contains('insufficient authentication scopes') ||
          errStr.contains('PERMISSION_DENIED') ||
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
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

                    // Manual Backup Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF4285F4), width: 1),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isBackingUp ? null : (_hasGoogleAuth ? _performDriveBackup : _connectGoogleDrive),
                        icon: _isBackingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload_outlined, color: Color(0xFF4285F4), size: 18),
                        label: Text(
                          _isBackingUp
                              ? 'Uploading PDF Statement to Drive...'
                              : (_hasGoogleAuth ? 'Backup PDF to Google Drive' : 'Connect Google Drive to Backup'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
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
