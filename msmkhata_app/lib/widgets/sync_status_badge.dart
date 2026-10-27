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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSyncing
                ? const Color(0xFF818CF8).withOpacity(0.6)
                : const Color(0xFF10B981).withOpacity(0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSyncing
                  ? const Color(0xFF818CF8).withOpacity(0.12)
                  : const Color(0xFF10B981).withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: Color(0xFF818CF8),
                ),
              )
            else
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981),
                      blurRadius: 5,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 6),
            Text(
              isSyncing ? 'Syncing...' : 'Synced',
              style: TextStyle(
                color: isSyncing ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                fontSize: 11,
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
