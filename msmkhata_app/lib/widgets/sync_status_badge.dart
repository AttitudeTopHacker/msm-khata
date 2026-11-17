import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

class SyncStatusBadge extends StatelessWidget {
  final bool? isSyncing;
  final VoidCallback? onSync;

  const SyncStatusBadge({
    super.key,
    this.isSyncing,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final connectivity = ConnectivityService();

    return ValueListenableBuilder<bool>(
      valueListenable: connectivity.isOnline,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SyncService.isSyncing,
          builder: (context, globalSyncing, _) {
            return ValueListenableBuilder<int>(
              valueListenable: SyncService.pendingCountNotifier,
              builder: (context, pendingCount, _) {
                final syncing = (isSyncing ?? false) || globalSyncing;

                Color borderColor;
                Color shadowColor;
                Color textColor;
                String label;
                Widget indicator;

                if (syncing) {
                  borderColor = const Color(0xFF818CF8).withValues(alpha: 0.6);
                  shadowColor = const Color(0xFF818CF8).withValues(alpha: 0.15);
                  textColor = const Color(0xFF818CF8);
                  label = 'Syncing...';
                  indicator = const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.4,
                      color: Color(0xFF818CF8),
                    ),
                  );
                } else if (pendingCount > 0) {
                  // Offline or pending entries waiting to be uploaded
                  borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.7);
                  shadowColor = const Color(0xFFF59E0B).withValues(alpha: 0.2);
                  textColor = const Color(0xFFFBBF24);
                  label = '$pendingCount Pending';
                  indicator = Container(
                    width: 6.5,
                    height: 6.5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF59E0B),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFF59E0B),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  );
                } else if (!isOnline) {
                  // Completely offline, 0 pending
                  borderColor = const Color(0xFFEF4444).withValues(alpha: 0.5);
                  shadowColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
                  textColor = const Color(0xFFF87171);
                  label = 'Offline';
                  indicator = Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFEF4444),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  );
                } else {
                  // Online and clean
                  borderColor = const Color(0xFF10B981).withValues(alpha: 0.35);
                  shadowColor = const Color(0xFF10B981).withValues(alpha: 0.08);
                  textColor = const Color(0xFF94A3B8);
                  label = 'Synced';
                  indicator = Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF10B981),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  );
                }

                return InkWell(
                  onTap: syncing ? null : (onSync ?? () => SyncService.syncAll()),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: 0.85,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        indicator,
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
