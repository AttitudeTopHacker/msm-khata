import 'package:flutter/material.dart';

/// Progress controller passed to tasks to update dialog in real-time
class ProgressController {
  final void Function({String? status, double? progress, String? subtitle}) _callback;
  ProgressController(this._callback);

  void update({String? status, double? progress, String? subtitle}) {
    _callback(status: status, progress: progress, subtitle: subtitle);
  }
}

/// Unified Luxury Processing & Animation Overlay Dialog for MsmKhata.
///
/// Features:
/// 1. Consistent branding & UI for all Accounts (Main Account, Grocery, Routine Diary, Drive Backup).
/// 2. Smooth animated pulsing ring and spinning gradient indicator.
/// 3. Real-time dynamic status & progress bar updates.
/// 4. Graceful success state with animated checkmark before launching print/preview.
/// 5. Resilient error state with user dismissal.
class UnifiedProgressModal extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Future<dynamic> Function(ProgressController progress) task;
  final bool autoDismissOnSuccess;

  const UnifiedProgressModal({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.picture_as_pdf_rounded,
    this.iconColor = const Color(0xFFEF4444),
    required this.task,
    this.autoDismissOnSuccess = true,
  });

  /// Static entry point to display the unified progress modal
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData icon = Icons.picture_as_pdf_rounded,
    Color iconColor = const Color(0xFFEF4444),
    required Future<T> Function(ProgressController progress) task,
    bool autoDismissOnSuccess = true,
  }) async {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => UnifiedProgressModal(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        task: (progress) => task(progress),
        autoDismissOnSuccess: autoDismissOnSuccess,
      ),
    );
  }

  @override
  State<UnifiedProgressModal> createState() => _UnifiedProgressModalState();
}

class _UnifiedProgressModalState extends State<UnifiedProgressModal> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  String _currentStatus = 'Preparing request...';
  String? _currentSubtitle;
  double? _progressValue; // null = indeterminate
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentSubtitle = widget.subtitle;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Execute the background task
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeTask();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _updateProgress({String? status, double? progress, String? subtitle}) {
    if (!mounted) return;
    setState(() {
      if (status != null) _currentStatus = status;
      if (progress != null) _progressValue = progress;
      if (subtitle != null) _currentSubtitle = subtitle;
    });
  }

  Future<void> _executeTask() async {
    final controller = ProgressController(_updateProgress);
    try {
      final result = await widget.task(controller);
      if (!mounted) return;

      setState(() {
        _isSuccess = true;
        _currentStatus = 'Ready! Opening viewer...';
      });

      if (widget.autoDismissOnSuccess) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorMessage != null;

    return PopScope(
      canPop: hasError,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 340,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                    : _isSuccess
                        ? const Color(0xFF10B981).withValues(alpha: 0.6)
                        : widget.iconColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: (hasError
                          ? const Color(0xFFEF4444)
                          : _isSuccess
                              ? const Color(0xFF10B981)
                              : widget.iconColor)
                      .withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Pulsing Icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (hasError
                              ? const Color(0xFFEF4444)
                              : _isSuccess
                                  ? const Color(0xFF10B981)
                                  : widget.iconColor)
                          .withValues(alpha: 0.16),
                      border: Border.all(
                        color: (hasError
                                ? const Color(0xFFEF4444)
                                : _isSuccess
                                    ? const Color(0xFF10B981)
                                    : widget.iconColor)
                            .withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: hasError
                          ? const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36)
                          : _isSuccess
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 38)
                              : Icon(widget.icon, color: widget.iconColor, size: 34),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  hasError ? 'Process Error' : widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.5,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Subtitle Badge
                if (_currentSubtitle != null && _currentSubtitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.iconColor.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _currentSubtitle!,
                      style: TextStyle(
                        color: widget.iconColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Progress Indicator (Bar / Spinner)
                if (!hasError) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 5,
                      width: double.infinity,
                      child: _progressValue != null
                          ? LinearProgressIndicator(
                              value: _progressValue,
                              backgroundColor: const Color(0xFF0F172A),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isSuccess ? const Color(0xFF10B981) : widget.iconColor,
                              ),
                            )
                          : LinearProgressIndicator(
                              backgroundColor: const Color(0xFF0F172A),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isSuccess ? const Color(0xFF10B981) : widget.iconColor,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Dynamic Status Message or Error Message
                Text(
                  hasError ? _errorMessage! : _currentStatus,
                  style: TextStyle(
                    color: hasError ? const Color(0xFFFCA5A5) : const Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: hasError ? FontWeight.w500 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // Error Action Button
                if (hasError) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

