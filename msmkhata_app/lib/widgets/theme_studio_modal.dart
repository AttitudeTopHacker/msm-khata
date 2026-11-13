import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Ultra-Modern Frosted Glass "Theme Studio" Bottom Sheet with Live Card Preview
class ThemeStudioModal extends StatelessWidget {
  const ThemeStudioModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ThemeStudioModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppAccentTheme>(
      valueListenable: ThemeService.accentNotifier,
      builder: (context, accent, _) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: accent.light.withValues(alpha: 0.4), width: 1.5),
                  left: BorderSide(color: accent.light.withValues(alpha: 0.2), width: 1),
                  right: BorderSide(color: accent.light.withValues(alpha: 0.2), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                  BoxShadow(
                    color: accent.glow.withValues(alpha: 0.12),
                    blurRadius: 35,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Drag Handle
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

                      // 2. Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: accent.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accent.light.withValues(alpha: 0.5), width: 1.2),
                                ),
                                child: Icon(Icons.palette_rounded, color: accent.light, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Theme Studio',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Live card preview ke sath border accent chuniye',
                                    style: TextStyle(color: accent.light, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // 3. LIVE CARD PREVIEW SECTION
                      _buildLivePreviewSection(accent),

                      const SizedBox(height: 20),

                      // 4. Section Label
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CHOOSE ACCENT PALETTE (6 PRESETS)',
                            style: TextStyle(
                              color: accent.light,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accent.light.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: Text(
                              'ACTIVE: ${accent.name.toUpperCase()}',
                              style: TextStyle(color: accent.light, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 5. Grid of 6 Theme Cards
                      _buildThemesGrid(accent),

                      const SizedBox(height: 22),

                      // 6. Done / Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Done • Apply Theme',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Live Mini Mockup Card showing how the theme impacts the dashboard
  Widget _buildLivePreviewSection(AppAccentTheme accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.remove_red_eye_rounded, size: 13, color: accent.light),
              const SizedBox(width: 6),
              Text(
                'LIVE PASSBOOK CARD PREVIEW',
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.cardBg.withValues(alpha: 0.95),
                const Color(0xFF1E293B).withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.light.withValues(alpha: 0.8), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: accent.glow.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar of Mini Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accent.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.light.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Icon(Icons.account_balance_rounded, color: accent.light, size: 14),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Main Account (Book 1)',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Primary',
                      style: TextStyle(color: accent.light, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Available Balance
              const Text(
                'Available Account Passbook Balance',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    '₹32,510',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                    ),
                    child: const Text(
                      'Liquid Funds',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: accent.light.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 10),

              // Money In & Money Out
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 13),
                      SizedBox(width: 4),
                      Text('Money In: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                      Text('+₹1,63,022', style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded, color: Color(0xFFF43F5E), size: 13),
                      SizedBox(width: 4),
                      Text('Money Out: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                      Text('-₹1,30,512', style: TextStyle(color: Color(0xFFFB7185), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Grid of 6 Theme Preset Cards
  Widget _buildThemesGrid(AppAccentTheme currentAccent) {
    return Column(
      children: ThemeService.availableAccents.map((item) {
        final isSelected = item.id == currentAccent.id;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ThemeService.setAccent(item.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? item.primary.withValues(alpha: 0.15) : const Color(0xFF1E293B).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? item.light : const Color(0xFF334155),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: item.glow.withValues(alpha: 0.25),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    // Color Preview Circle with Glow
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: item.glow.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 14),

                    // Theme Name & Color Chips
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: item.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildMiniColorChip(item.primary),
                              const SizedBox(width: 4),
                              _buildMiniColorChip(item.light),
                              const SizedBox(width: 4),
                              _buildMiniColorChip(item.glow),
                              const SizedBox(width: 8),
                              Text(
                                _getThemeSubtitle(item.id),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Radio indicator
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? item.light : const Color(0xFF64748B),
                          width: 2,
                        ),
                        color: isSelected ? item.primary : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.circle, color: Colors.white, size: 10)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static Widget _buildMiniColorChip(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
      ),
    );
  }

  static String _getThemeSubtitle(String id) {
    switch (id) {
      case 'indigo':
        return 'Classic Deep Neon Blue';
      case 'emerald':
        return 'Vibrant Fresh Green';
      case 'purple':
        return 'Cyberpunk Neon Violet';
      case 'amber':
        return 'Warm Sunset Golden';
      case 'rose':
        return 'Electric Passion Rose';
      case 'cyan':
        return 'Futuristic Ocean Sky';
      default:
        return 'Standard Accent';
    }
  }
}
