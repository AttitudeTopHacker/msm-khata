import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

class OfflineNoticeBar extends StatelessWidget {
  const OfflineNoticeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = ConnectivityService();

    return ValueListenableBuilder<bool>(
      valueListenable: connectivity.isOnline,
      builder: (context, isOnline, _) {
        if (isOnline) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFF991B1B)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x66DC2626),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '⚠️ Internet Connection Off Hai!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kripya apna internet connection ON karein taaki ledger sync rahe.',
                          style: TextStyle(
                            color: Color(0xFFFEE2E2),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: connectivity.isChecking,
                    builder: (context, isChecking, _) {
                      return TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF991B1B),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isChecking
                            ? null
                            : () async {
                                final isNowOnline = await connectivity.checkActualInternet();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 3),
                                      backgroundColor: isNowOnline
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                      content: Row(
                                        children: [
                                          Icon(
                                            isNowOnline
                                                ? Icons.wifi_rounded
                                                : Icons.wifi_off_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              isNowOnline
                                                  ? 'Internet connect ho gaya! MsmKhata online hai.'
                                                  : 'Abhi bhi internet off hai. Kripya Wi-Fi ya Mobile Data check karein.',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: isChecking
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF991B1B),
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 14),
                        label: Text(
                          isChecking ? 'Checking...' : 'Retry',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
