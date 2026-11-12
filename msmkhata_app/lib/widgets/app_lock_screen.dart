import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../services/theme_service.dart';

/// Full-Screen Frosted Dark MPIN Lock Screen for MsmKhata
class AppLockScreen extends StatefulWidget {
  final Widget child;

  const AppLockScreen({super.key, required this.child});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;

  void _onNumberTap(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyEnteredPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verifyEnteredPin() {
    final isValid = SecurityService.verifyPin(_enteredPin);
    if (!isValid) {
      setState(() {
        _errorMessage = 'Galat PIN! Kripya sahi 4-digit PIN darj karein.';
        _enteredPin = '';
      });
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

        return ValueListenableBuilder<AppAccentTheme>(
          valueListenable: ThemeService.accentNotifier,
          builder: (context, accent, _) {
            return Scaffold(
              backgroundColor: const Color(0xFF0A0E1A),
              body: Container(
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
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.primary.withValues(alpha: 0.15),
                          border: Border.all(color: accent.light, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: accent.glow.withValues(alpha: 0.35),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(Icons.lock_rounded, color: accent.light, size: 36),
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
                      const Text(
                        'Enter 4-digit MPIN to unlock your ledger',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),

                      const SizedBox(height: 32),

                      // PIN Dot Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isFilled = index < _enteredPin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled ? accent.light : Colors.transparent,
                              border: Border.all(
                                color: isFilled ? accent.light : const Color(0xFF475569),
                                width: 2,
                              ),
                              boxShadow: [
                                if (isFilled)
                                  BoxShadow(
                                    color: accent.glow.withValues(alpha: 0.6),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

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
                                // Biometric button or empty
                                SizedBox(
                                  width: 68,
                                  height: 68,
                                  child: SecurityService.isBiometricEnabled
                                      ? IconButton(
                                          icon: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981), size: 36),
                                          onPressed: () {
                                            // Mock/biometric unlock trigger
                                            SecurityService.unlockApp();
                                          },
                                        )
                                      : null,
                                ),
                                _buildKeypadButton('0', accent),
                                SizedBox(
                                  width: 68,
                                  height: 68,
                                  child: IconButton(
                                    icon: const Icon(Icons.backspace_outlined, color: Color(0xFF94A3B8), size: 26),
                                    onPressed: _onBackspace,
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
      onTap: () => _onNumberTap(digit),
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
