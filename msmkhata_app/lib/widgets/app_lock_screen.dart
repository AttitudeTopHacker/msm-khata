import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';
import '../services/theme_service.dart';

/// Full-Screen Frosted Dark MPIN & Biometric Lock Screen for MsmKhata.
///
/// Features:
/// 1. Dual Device Adaptation:
///    - Mobile (Android / iOS): Full MPIN Keypad + Automatic Native Fingerprint Scanner.
///    - Desktop (Linux / Windows / macOS): Clean MPIN Keypad + Direct Physical Keyboard typing (0-9, Numpad, Backspace, Escape).
/// 2. Instant 0ms Unlock on Correct PIN.
/// 3. Exactly 2-Second Red Wrong Bubble with Horizontal Shake on Incorrect PIN.
class AppLockScreen extends StatefulWidget {
  final Widget child;

  const AppLockScreen({super.key, required this.child});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  final FocusNode _keyboardFocusNode = FocusNode();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String _enteredPin = '';
  String? _errorMessage;
  bool _isChecking = false;
  bool _isError = false;
  bool _autoBioAttempted = false;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    // Auto-prompt fingerprint on mobile devices
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoBiometric();
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _checkAutoBiometric() {
    if (_isMobile &&
        SecurityService.isBiometricEnabled &&
        SecurityService.isAppLocked &&
        !_autoBioAttempted) {
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
      _verifyEnteredPin();
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
      // RULE: Sahi password par immediately unlock ho, 2 second ka kuch nahi!
      _enteredPin = '';
      _isChecking = false;
      _isError = false;
      _errorMessage = null;
      SecurityService.unlockApp();
    } else {
      // RULE: 4 digit dalne ke baad agar wrong ho, 2 second ka wrong bubble dikhao
      _shakeController.forward(from: 0.0);
      setState(() {
        _isError = true;
        _errorMessage = 'Galat PIN! Kripya sahi 4-digit PIN darj karein.';
      });

      // Exactly 2-second wrong bubble presentation
      await Future.delayed(const Duration(seconds: 2));

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SecurityService.isAppLockedNotifier,
      builder: (context, isLocked, _) {
        if (!isLocked) {
          _autoBioAttempted = false;
          return widget.child;
        }

        if (!_autoBioAttempted && _isMobile && SecurityService.isBiometricEnabled) {
          _checkAutoBiometric();
        }

        return ValueListenableBuilder<AppAccentTheme>(
          valueListenable: ThemeService.accentNotifier,
          builder: (context, accent, _) {
            return Scaffold(
              backgroundColor: const Color(0xFF0A0E1A),
              body: Focus(
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
                    } else if (key == LogicalKeyboardKey.escape) {
                      if (!_isChecking) {
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
                      center: const Alignment(0, -0.3),
                      radius: 1.2,
                      colors: [
                        accent.cardBg,
                        const Color(0xFF0F172A),
                        const Color(0xFF0A0E1A),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const Spacer(flex: 2),

                        // Lock Icon & Aura
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isError
                                ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                : accent.primary.withValues(alpha: 0.15),
                            border: Border.all(
                              color: _isError ? const Color(0xFFEF4444) : accent.light,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isError
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                    : accent.glow.withValues(alpha: 0.35),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isError ? Icons.lock_clock_rounded : Icons.lock_rounded,
                            color: _isError ? const Color(0xFFEF4444) : accent.light,
                            size: 36,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'MsmKhata is Locked',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isMobile
                              ? (SecurityService.isBiometricEnabled
                                  ? 'Enter 4-digit MPIN or scan fingerprint'
                                  : 'Enter 4-digit MPIN to unlock your ledger')
                              : 'Keyboard se 4-digit PIN type karein ya keypad use karein',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),

                        const SizedBox(height: 32),

                        // PIN Dot Indicators with Shake Animation on Wrong PIN
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            final double shakeOffset = _isError
                                ? sin(_shakeAnimation.value * pi * 4) * 10
                                : 0.0;
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
                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                width: 18,
                                height: 18,
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
                                            ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                                            : accent.glow.withValues(alpha: 0.6),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 2-Second Wrong PIN Bubble
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: (_isError && _errorMessage != null)
                              ? Container(
                                  key: const ValueKey('wrong_pin_bubble'),
                                  margin: const EdgeInsets.symmetric(horizontal: 24),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7F1D1D).withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFEF4444),
                                        ),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: Color(0xFFFEE2E2),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(height: 42),
                        ),

                        const Spacer(flex: 3),

                        // Numeric Keypad
                        Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              _buildKeypadRow(['1', '2', '3'], accent),
                              const SizedBox(height: 14),
                              _buildKeypadRow(['4', '5', '6'], accent),
                              const SizedBox(height: 14),
                              _buildKeypadRow(['7', '8', '9'], accent),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Biometric Button (Only on Mobile devices when enabled)
                                  SizedBox(
                                    width: 68,
                                    height: 68,
                                    child: (_isMobile && SecurityService.isBiometricEnabled)
                                        ? InkWell(
                                            onTap: _isChecking ? null : _triggerBiometricAuth,
                                            borderRadius: BorderRadius.circular(34),
                                            child: Container(
                                              width: 68,
                                              height: 68,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                border: Border.all(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.fingerprint_rounded,
                                                  color: Color(0xFF10B981),
                                                  size: 36,
                                                ),
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  _buildKeypadButton('0', accent),
                                  SizedBox(
                                    width: 68,
                                    height: 68,
                                    child: IconButton(
                                      icon: const Icon(Icons.backspace_outlined, color: Color(0xFF94A3B8), size: 26),
                                      onPressed: _isChecking ? null : _onBackspace,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKeypadRow(List<String> digits, AppAccentTheme accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildKeypadButton(d, accent)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit, AppAccentTheme accent) {
    return InkWell(
      onTap: _isChecking ? null : () => _onNumberTap(digit),
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
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
}
