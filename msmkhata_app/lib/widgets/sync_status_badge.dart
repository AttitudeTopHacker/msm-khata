import 'package:flutter/material.dart';

class SyncStatusBadge extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback? onSync;

  const SyncStatusBadge({
    super.key,
    required this.isSyncing,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSyncing ? null : onSync,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSyncing
                ? const Color(0xFF818CF8).withValues(alpha: 0.6)
                : const Color(0xFF10B981).withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isSyncing
                  ? const Color(0xFF818CF8).withValues(alpha: 0.12)
                  : const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.4,
                  color: Color(0xFF818CF8),
                ),
              )
            else
              Container(
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
              ),
            const SizedBox(width: 5),
            Text(
              isSyncing ? 'Syncing...' : 'Synced',
              style: TextStyle(
                color: isSyncing ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
