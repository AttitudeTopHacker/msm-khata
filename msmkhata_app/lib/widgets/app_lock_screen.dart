import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import 'msm_shimmer_text.dart';

/// Adaptive Full-Screen Frosted MPIN & Biometric Lock Screen for MsmKhata.
///
/// Features:
/// 1. Dual Device Adaptation:
///    - Mobile: Glowing Icon, 4 Circular Bubble Dots, Tactile Keypad with Biometric Sensor,
///      and Footer with Profile + Shimmer 'msm.movin 2022'.
///    - Desktop: Clean Centered Card, 4 Large Square Box Inputs (No Numpad, physical keyboard first),
///      Filled full-width Unlock button, Subtle Esc indicator, and 'Forgot MPIN' (Coming Soon).
/// 2. Unified 2-Step Setup Screen (Exact same screen for setting up / confirming PIN).
/// 3. Instant 0ms Unlock on Correct PIN.
/// 4. 0.45-Second Shake & Red React Animation on Incorrect PIN.
class AppLockScreen extends StatefulWidget {
  final Widget child;

  const AppLockScreen({super.key, required this.child});

  /// Opens the exact same unified screen in 2-step Setup Mode
  static Future<bool?> showSetup(BuildContext context) async {
    SecurityService.isPinSetupInProgress = true;
    try {
      return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close Setup',
        barrierColor: Colors.black.withValues(alpha: 0.8),
        pageBuilder: (ctx, anim1, anim2) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: AppLockScreenContent(isSetupMode: true),
          );
        },
      );
    } finally {
      SecurityService.isPinSetupInProgress = false;
    }
  }

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with WidgetsBindingObserver {
  DateTime? _inactiveStartTime;
  Timer? _inactiveLockTimer;
  Timer? _desktopSleepHeartbeatTimer;
  DateTime? _lastDesktopHeartbeat;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Desktop Sleep / Screen Lock Heartbeat Monitor
    if (!_isMobile) {
      _lastDesktopHeartbeat = DateTime.now();
      _desktopSleepHeartbeatTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
        if (!SecurityService.isPinEnabled && !SecurityService.hasPin) return;
        if (SecurityService.isAppLocked) return;
        if (SecurityService.isExternalAuthInProgress || SecurityService.isPinSetupInProgress) return;

        final now = DateTime.now();

        // 1. Detect System Sleep / Suspend / Laptop Lid Close
        // When system goes to sleep, timers pause. Upon waking up, the elapsed time jump >= 5s.
        if (_lastDesktopHeartbeat != null) {
          final diff = now.difference(_lastDesktopHeartbeat!).inSeconds;
          if (diff >= 5) {
            SecurityService.lockApp();
            _lastDesktopHeartbeat = now;
            return;
          }
        }
        _lastDesktopHeartbeat = now;

        // 2. Detect Linux Screen Lock / Screensaver (e.g. Super + L or Display Screen Saver)
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
          try {
            final res = await Process.run('cinnamon-screensaver-command', ['-q']);
            if (res.exitCode == 0 && res.stdout.toString().toLowerCase().contains('is active')) {
              SecurityService.lockApp();
              return;
            }
          } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactiveLockTimer?.cancel();
    _desktopSleepHeartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!SecurityService.isPinEnabled && !SecurityService.hasPin) {
      return;
    }

    if (SecurityService.isExternalAuthInProgress ||
        SecurityService.isAuthenticatingBiometric ||
        SecurityService.isPinSetupInProgress) {
      return;
    }

    if (_isMobile) {
      // =======================================================================
      // MOBILE LIFECYCLE (Power Button / Screen Timeout / Home / App Switcher)
      // =======================================================================
      if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
        _inactiveLockTimer?.cancel();
        _inactiveStartTime = null;
        SecurityService.lockApp();
      } else if (state == AppLifecycleState.inactive) {
        _inactiveStartTime = DateTime.now();
        _inactiveLockTimer?.cancel();
        _inactiveLockTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted) {
            SecurityService.lockApp();
          }
        });
      } else if (state == AppLifecycleState.resumed) {
        _inactiveLockTimer?.cancel();
        if (_inactiveStartTime != null) {
          final elapsed = DateTime.now().difference(_inactiveStartTime!);
          _inactiveStartTime = null;
          if (elapsed >= const Duration(milliseconds: 250)) {
            SecurityService.lockApp();
          }
        }
      }
    } else {
      // =======================================================================
      // DESKTOP LIFECYCLE (Smooth Multitasking: No locking on simple window blur)
      // Lock ONLY on:
      // - App Startup (initial login)
      // - System Sleep / Suspend (detected by heartbeat)
      // - Screen Off / Lock Screen (detected by screensaver command)
      // - Long Inactivity (5+ minutes away from desktop window)
      // =======================================================================
      if (state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
        _inactiveStartTime ??= DateTime.now();
      } else if (state == AppLifecycleState.resumed) {
        if (_inactiveStartTime != null) {
          final elapsed = DateTime.now().difference(_inactiveStartTime!);
          _inactiveStartTime = null;
          // Only auto-lock if user was away from desktop app for more than 5 minutes
          if (elapsed >= const Duration(minutes: 5)) {
            SecurityService.lockApp();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SecurityService.isAppLockedNotifier,
      builder: (context, isLocked, _) {
        if (!isLocked) {
          return widget.child;
        }

        return const Scaffold(
          backgroundColor: Color(0xFF060A14),
          body: AppLockScreenContent(isSetupMode: false),
        );
      },
    );
  }
}

/// The reusable UI content used for both Unlock and 2-Step Setup
class AppLockScreenContent extends StatefulWidget {
  final bool isSetupMode;

  const AppLockScreenContent({super.key, this.isSetupMode = false});

  @override
  State<AppLockScreenContent> createState() => _AppLockScreenContentState();
}

class _AppLockScreenContentState extends State<AppLockScreenContent>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FocusNode _keyboardFocusNode = FocusNode();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String _enteredPin = '';
  String? _errorMessage;
  bool _isChecking = false;
  bool _isError = false;
  bool _autoBioAttempted = false;

  // Setup mode specific state
  int _setupStep = 1; // 1: Enter new PIN, 2: Confirm new PIN
  String _firstPassPin = '';

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMobile) {
        _keyboardFocusNode.requestFocus();
      } else if (!widget.isSetupMode) {
        _checkAutoBiometric();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When screen turns back on and user returns to app:
    if (state == AppLifecycleState.resumed) {
      if (!_isMobile) {
        _keyboardFocusNode.requestFocus();
      } else if (!widget.isSetupMode) {
        _autoBioAttempted = false;
        _checkAutoBiometric();
      }
    }
  }

  void _checkAutoBiometric() {
    if (_isMobile &&
        SecurityService.isBiometricEnabled &&
        SecurityService.isAppLocked &&
        !_autoBioAttempted &&
        !SecurityService.isAuthenticatingBiometric) {
      _autoBioAttempted = true;
      _triggerBiometricAuth();
    }
  }

  Future<void> _triggerBiometricAuth() async {
    final success = await SecurityService.authenticateWithBiometric();
    if (success && mounted) {
      setState(() {
        _enteredPin = '';
        _errorMessage = null;
        _isError = false;
      });
    }
  }

  void _onNumberTap(String digit) {
    if (_isChecking || _enteredPin.length >= 4) return;

    setState(() {
      _errorMessage = null;
      _isError = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      if (widget.isSetupMode) {
        _processSetupStep();
      } else {
        _verifyEnteredPin();
      }
    }
  }

  void _onBackspace() {
    if (_isChecking) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _isError = false;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyEnteredPin() async {
    setState(() {
      _isChecking = true;
    });

    final isValid = SecurityService.verifyPin(_enteredPin);

    if (isValid) {
      _enteredPin = '';
      _isChecking = false;
      _isError = false;
      _errorMessage = null;
      SecurityService.unlockApp();
    } else {
      _shakeController.forward(from: 0.0);
      setState(() {
        _isError = true;
        _errorMessage = 'Incorrect MPIN. Please enter your 4-digit PIN.';
      });

      await Future.delayed(const Duration(milliseconds: 1800));

      if (mounted) {
        setState(() {
          _enteredPin = '';
          _isError = false;
          _errorMessage = null;
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _processSetupStep() async {
    setState(() {
      _isChecking = true;
    });

    if (_setupStep == 1) {
      _firstPassPin = _enteredPin;
      _enteredPin = '';
      _setupStep = 2;
      _isChecking = false;
      _errorMessage = null;
      _isError = false;
      setState(() {});
    } else {
      if (_enteredPin == _firstPassPin) {
        await SecurityService.setPin(_enteredPin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('New 4-digit MPIN configured successfully!'),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        _shakeController.forward(from: 0.0);
        setState(() {
          _isError = true;
          _errorMessage = 'PINs do not match. Please try again.';
        });

        await Future.delayed(const Duration(milliseconds: 1900));

        if (mounted) {
          setState(() {
            _enteredPin = '';
            _firstPassPin = '';
            _setupStep = 1;
            _isError = false;
            _errorMessage = 'Re-enter your new 4-digit PIN:';
            _isChecking = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppAccentTheme>(
      valueListenable: ThemeService.accentNotifier,
      builder: (context, accent, _) {
        final profileName = AuthService.displayName.isNotEmpty &&
                AuthService.displayName != 'User'
            ? AuthService.displayName
            : 'Salman (Admin)';
        final avatarLetter =
            profileName.isNotEmpty ? profileName[0].toUpperCase() : 'S';

        String titleText;
        String subtitleText;

        if (widget.isSetupMode) {
          if (_setupStep == 1) {
            titleText = _isMobile ? 'Setup 4-Digit MPIN' : 'Setup Desktop MPIN';
            subtitleText = 'Enter a new 4-digit MPIN';
          } else {
            titleText = _isMobile ? 'Confirm 4-Digit MPIN' : 'Confirm Desktop MPIN';
            subtitleText = 'Re-enter your PIN to confirm';
          }
        } else {
          titleText = _isMobile ? 'MsmKhata is Locked' : 'MsmKhata Desktop is Locked';
          subtitleText = _isMobile
              ? (SecurityService.isBiometricEnabled
                  ? 'Enter 4-digit MPIN or scan fingerprint'
                  : 'Enter 4-digit MPIN to unlock your ledger')
              : 'Type your 4-digit PIN using your physical keyboard';
        }

        return Focus(
          autofocus: true,
          focusNode: _keyboardFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (_isChecking) return KeyEventResult.handled;

              final key = event.logicalKey;
              String? digit;

              if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
                digit = '0';
              } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
                digit = '1';
              } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
                digit = '2';
              } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
                digit = '3';
              } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
                digit = '4';
              } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
                digit = '5';
              } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
                digit = '6';
              } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
                digit = '7';
              } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
                digit = '8';
              } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
                digit = '9';
              } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
                _onBackspace();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
                if (widget.isSetupMode) {
                  _processSetupStep();
                } else if (_enteredPin.length == 4) {
                  _verifyEnteredPin();
                }
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.escape) {
                if (widget.isSetupMode) {
                  Navigator.of(context).pop(false);
                } else if (!_isChecking) {
                  setState(() {
                    _enteredPin = '';
                    _errorMessage = null;
                    _isError = false;
                  });
                }
                return KeyEventResult.handled;
              }

              if (digit != null) {
                _onNumberTap(digit);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 1.25,
                colors: [
                  accent.cardBg.withValues(alpha: 0.8),
                  const Color(0xFF0C1324),
                  const Color(0xFF060A14),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Setup Close / Remove Lock Top Bar
                  if (widget.isSetupMode)
                    Positioned(
                      top: 10,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 24),
                            onPressed: () => Navigator.of(context).pop(false),
                            tooltip: 'Cancel Setup',
                          ),
                          if (SecurityService.hasPin)
                            TextButton.icon(
                              onPressed: () async {
                                await SecurityService.removePin();
                                if (context.mounted) {
                                  Navigator.of(context).pop(true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('App MPIN lock disabled successfully.'),
                                      backgroundColor: Color(0xFF64748B),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.lock_open_rounded, color: Color(0xFFEF4444), size: 16),
                              label: const Text(
                                'Remove Lock',
                                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Content Body: Mobile vs Desktop
                  _isMobile
                      ? _buildMobileLayout(accent, profileName, avatarLetter, titleText, subtitleText)
                      : _buildDesktopLayout(accent, profileName, avatarLetter, titleText, subtitleText),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT (4 SQUARE BOXES, NO NUMPAD, FILLED BUTTON, FORGOT PIN)
  // ===========================================================================
  Widget _buildDesktopLayout(
    AppAccentTheme accent,
    String profileName,
    String avatarLetter,
    String titleText,
    String subtitleText,
  ) {
    return Center(
      child: SingleChildScrollView(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _keyboardFocusNode.requestFocus(),
          child: Container(
            width: 390,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1424).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.light.withValues(alpha: 0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: accent.glow.withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Glowing MsmKhata App Icon with Attached Lock Badge
              _buildMsmKhataLockBadge(accent),

              const SizedBox(height: 14),

              Text(
                titleText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),

              const SizedBox(height: 18),

              // 4 Large Glowing Square Box Inputs (No Numpad)
              _buildDesktopSquareBoxes(accent),

              const SizedBox(height: 6),

              // Error Banner (Shake on wrong PIN)
              _buildErrorBanner(),

              const SizedBox(height: 12),

              // Full-Width Filled Action Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: accent.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isChecking
                      ? null
                      : () {
                          if (widget.isSetupMode) {
                            _processSetupStep();
                          } else if (_enteredPin.length == 4) {
                            _verifyEnteredPin();
                          }
                        },
                  child: Text(
                    widget.isSetupMode
                        ? (_setupStep == 1 ? 'Next: Confirm PIN →' : 'Save & Enable Lock')
                        : 'Unlock Desktop →',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Action Link: 'Forgot MPIN?' (or 'Cancel' in setup mode)
              Center(
                child: widget.isSetupMode
                    ? TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Cancel Setup',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      )
                    : TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Forgot MPIN feature is Coming Soon!'),
                              backgroundColor: Color(0xFF1E293B),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot MPIN?',
                          style: TextStyle(
                            color: accent.light,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 18),
              const Divider(color: Color(0xFF1E293B), height: 1),
              const SizedBox(height: 14),

              // Bottom Footer: User Profile + Shimmer Text
              _buildUserProfileChip(profileName, avatarLetter, accent),
              const SizedBox(height: 6),
              const MsmShimmerText(
                text: 'ORG : msm.movin 2022',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  /// 4 Large Square Box Inputs for Desktop
  Widget _buildDesktopSquareBoxes(AppAccentTheme accent) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final double shakeOffset = _isError ? sin(_shakeAnimation.value * pi * 4) * 10 : 0.0;
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < _enteredPin.length;
          final isCurrentFocus = index == _enteredPin.length;

          Color borderColor;
          Color bgColor;
          List<BoxShadow> shadows = [];

          if (_isError) {
            borderColor = const Color(0xFFEF4444);
            bgColor = const Color(0xFF7F1D1D).withValues(alpha: 0.3);
            shadows = [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                blurRadius: 14,
              ),
            ];
          } else if (isFilled) {
            borderColor = accent.primary;
            bgColor = accent.primary.withValues(alpha: 0.2);
            shadows = [
              BoxShadow(
                color: accent.glow.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ];
          } else if (isCurrentFocus) {
            borderColor = accent.light;
            bgColor = const Color(0xFF0F172A);
            shadows = [
              BoxShadow(
                color: accent.light.withValues(alpha: 0.25),
                blurRadius: 8,
              ),
            ];
          } else {
            borderColor = const Color(0xFF334155);
            bgColor = const Color(0xFF0F172A).withValues(alpha: 0.8);
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: shadows,
            ),
            child: Center(
              child: isFilled
                  ? Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isError ? const Color(0xFFEF4444) : accent.light,
                      ),
                    )
                  : (isCurrentFocus
                      ? Container(
                          width: 14,
                          height: 2,
                          color: accent.light.withValues(alpha: 0.8),
                        )
                      : null),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT (BUBBLE DOTS, TACTILE KEYPAD, BIOMETRIC, FOOTER PROFILE)
  // ===========================================================================
  Widget _buildMobileLayout(
    AppAccentTheme accent,
    String profileName,
    String avatarLetter,
    String titleText,
    String subtitleText,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Balanced Top Breathing Room (Pushes content comfortably down away from top bar/notch)
          Spacer(flex: widget.isSetupMode ? 3 : 5),

          // Top Section: Icon + Profile Chip + Title + Subtitle + Bubble Dots
          _buildMsmKhataLockBadge(accent),
          const SizedBox(height: 12),
          _buildUserProfileChip(profileName, avatarLetter, accent),
          const SizedBox(height: 14),
          Text(
            titleText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitleText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildBubbleDots(accent),
          const SizedBox(height: 6),
          _buildErrorBanner(),

          // Balanced Space between Header & Keypad
          const Spacer(flex: 2),

          // Middle Section: Tactile Circular Numeric Keypad (Cohesive Grid with 20px row gap)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildKeypadRow(['1', '2', '3'], accent),
              const SizedBox(height: 20),
              _buildKeypadRow(['4', '5', '6'], accent),
              const SizedBox(height: 20),
              _buildKeypadRow(['7', '8', '9'], accent),
              const SizedBox(height: 20),
              _buildBottomKeypadRow(accent),
            ],
          ),

          // Balanced Space between Keypad & Footer
          const Spacer(flex: 3),

          // Bottom Section (Below Keypad): Shimmer Text
          const MsmShimmerText(
            text: 'ORG : msm.movin 2022',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Glowing MsmKhata App Icon with Attached Lock Badge
  Widget _buildMsmKhataLockBadge(AppAccentTheme accent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _isError ? const Color(0xFFEF4444) : accent.primary,
            _isError ? const Color(0xFF991B1B) : const Color(0xFF38BDF8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _isError
                ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                : accent.glow.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF0D1424),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Official App Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/icon.png',
                width: 67,
                height: 67,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    'MK',
                    style: TextStyle(
                      color: _isError ? const Color(0xFFEF4444) : accent.light,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),

            // Attached Glowing Lock Badge at Bottom-Right
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isError ? const Color(0xFFEF4444) : accent.primary,
                  border: Border.all(color: const Color(0xFF0D1424), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  _isError ? Icons.lock_clock_rounded : Icons.lock_rounded,
                  color: Colors.white,
                  size: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 4 Glowing Circular Bubble Dots (for Mobile)
  Widget _buildBubbleDots(AppAccentTheme accent) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final double shakeOffset = _isError ? sin(_shakeAnimation.value * pi * 4) * 10 : 0.0;
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < _enteredPin.length;
          final dotColor = _isError
              ? const Color(0xFFEF4444)
              : (isFilled ? accent.light : Colors.transparent);
          final borderColor = _isError
              ? const Color(0xFFEF4444)
              : (isFilled ? accent.light : const Color(0xFF475569));

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: Border.all(
                color: borderColor,
                width: 2,
              ),
              boxShadow: [
                if (isFilled || _isError)
                  BoxShadow(
                    color: _isError
                        ? const Color(0xFFEF4444).withValues(alpha: 0.8)
                        : accent.glow.withValues(alpha: 0.7),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// 2-Second Red Error Banner
  Widget _buildErrorBanner() {
    return SizedBox(
      height: 32,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: (_isError && _errorMessage != null)
            ? Container(
                key: const ValueKey('error_bubble'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFEE2E2),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// Keypad Row (3 buttons centered with 25px gap)
  Widget _buildKeypadRow(List<String> digits, AppAccentTheme accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildKeypadButton(digits[0], accent),
        const SizedBox(width: 25),
        _buildKeypadButton(digits[1], accent),
        const SizedBox(width: 25),
        _buildKeypadButton(digits[2], accent),
      ],
    );
  }

  /// Bottom Row: [Biometric/Reset] | [0] | [Backspace] (Balanced 70x70 with 25px gap)
  Widget _buildBottomKeypadRow(AppAccentTheme accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: widget.isSetupMode
              ? InkWell(
                  onTap: _isChecking
                      ? null
                      : () {
                          setState(() {
                            _enteredPin = '';
                            _firstPassPin = '';
                            _setupStep = 1;
                            _errorMessage = null;
                            _isError = false;
                          });
                        },
                  borderRadius: BorderRadius.circular(35),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                      border: Border.all(color: const Color(0xFF334155), width: 1),
                    ),
                    child: const Center(
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : ((_isMobile && SecurityService.isBiometricEnabled)
                  ? InkWell(
                      onTap: _isChecking ? null : _triggerBiometricAuth,
                      borderRadius: BorderRadius.circular(35),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.fingerprint_rounded,
                            color: Color(0xFF10B981),
                            size: 32,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
        ),

        const SizedBox(width: 25),

        _buildKeypadButton('0', accent),

        const SizedBox(width: 25),

        SizedBox(
          width: 70,
          height: 70,
          child: InkWell(
            onTap: _isChecking ? null : _onBackspace,
            borderRadius: BorderRadius.circular(35),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                border: Border.all(color: const Color(0xFF334155), width: 1),
              ),
              child: const Center(
                child: Icon(
                  Icons.backspace_outlined,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Single Numeric Keypad Button (Standard 70x70 Proportions)
  Widget _buildKeypadButton(String digit, AppAccentTheme accent) {
    return InkWell(
      onTap: _isChecking ? null : () => _onNumberTap(digit),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E293B).withValues(alpha: 0.65),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// User Profile Chip with actual User Picture support
  Widget _buildUserProfileChip(String profileName, String avatarLetter, AppAccentTheme accent) {
    final avatarUrl = AuthService.avatarUrl;
    final bool hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.primary.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: hasAvatar
                  ? Image.network(
                      avatarUrl,
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFallbackAvatar(avatarLetter, accent);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildFallbackAvatar(avatarLetter, accent);
                      },
                    )
                  : _buildFallbackAvatar(avatarLetter, accent),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            profileName,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(String avatarLetter, AppAccentTheme accent) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accent.primary, const Color(0xFF38BDF8)],
        ),
      ),
      child: Center(
        child: Text(
          avatarLetter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
