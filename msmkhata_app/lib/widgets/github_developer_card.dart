import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'msm_shimmer_text.dart';

/// A rich, modern GitHub Developer Profile Card showcasing the creator's
/// real profile, username, avatar, repositories, and featured projects.
class GithubDeveloperCard extends StatelessWidget {
  final VoidCallback? onProfileTap;

  static const String githubUsername = 'AttitudeTopHacker';
  static const String githubProfileUrl = 'https://github.com/AttitudeTopHacker';
  static const String githubAvatarUrl = 'https://avatars.githubusercontent.com/u/97902566?v=4';

  const GithubDeveloperCard({super.key, this.onProfileTap});

  Future<void> _openGitHubUrl(BuildContext context, [String url = githubProfileUrl]) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _showProfileInfo(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showProfileInfo(context);
      }
    }
  }

  void _showProfileInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF30363D), width: 1),
        ),
        title: Row(
          children: const [
            Icon(Icons.terminal_rounded, color: Color(0xFF58A6FF), size: 24),
            SizedBox(width: 10),
            Text(
              'Developer Profile',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Mohd Salman (@AttitudeTopHacker)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Lead Software Architect • Creator of MsmKhata Ledger.\nActive on GitHub since 2022 (ORG : msm.movin 2022).',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openGitHubUrl(context, githubProfileUrl);
            },
            child: const Text('Open on GitHub', style: TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF8B949E))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 820),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117), // GitHub primary dark canvas
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF30363D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF58A6FF).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Card Top Bar with GitHub Badge & Live Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.code_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'GITHUB DEVELOPER PROFILE',
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF238636).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2EA043), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3FB950),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Active Contributor',
                        style: TextStyle(color: Color(0xFF3FB950), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Profile Main Details Header
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Avatar with Gradient Ring
                    InkWell(
                      onTap: () => _openGitHubUrl(context, githubProfileUrl),
                      borderRadius: BorderRadius.circular(35),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF58A6FF), Color(0xFF818CF8), Color(0xFF2EA043)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF58A6FF).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: ClipOval(
                          child: Image.network(
                            githubAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF161B22),
                              alignment: Alignment.center,
                              child: const Text(
                                'MS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Name, Handle, Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _openGitHubUrl(context, githubProfileUrl),
                            child: Row(
                              children: const [
                                Flexible(
                                  child: Text(
                                    'Mohd Salman',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.verified_rounded, color: Color(0xFF58A6FF), size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: const [
                              Text(
                                '@AttitudeTopHacker',
                                style: TextStyle(
                                  color: Color(0xFF58A6FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('•', style: TextStyle(color: Color(0xFF484F58))),
                              SizedBox(width: 8),
                              MsmShimmerText(
                                text: 'ORG : msm.movin 2022',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Lead Engineer & Software Architect • Creator of MsmKhata Ledger & Financial Analytics',
                            style: TextStyle(
                              color: Color(0xFF8B949E),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 3. Stats Matrix Grid (Repositories, Contributions)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    final cardWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildStatBox(
                          label: 'Repositories',
                          value: '48+',
                          icon: Icons.source_rounded,
                          color: const Color(0xFF58A6FF),
                          sublabel: '9 Public • 39 Private Verified',
                          width: cardWidth,
                        ),
                        _buildStatBox(
                          label: 'Contributions',
                          value: '1,280+',
                          icon: Icons.insights_rounded,
                          color: const Color(0xFF3FB950),
                          sublabel: 'Active since Jan 2022',
                          width: cardWidth,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 22),

                // 4. Featured Repositories Section
                Row(
                  children: const [
                    Icon(Icons.bookmark_outline_rounded, color: Color(0xFF8B949E), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Featured Public Repositories',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildRepoCard(
                      context: context,
                      name: 'msm-khata',
                      desc: 'Multi-tenant personal & agricultural ledger with isolated cloud storage and interactive financial charts.',
                      language: 'Dart / Flutter',
                      langColor: const Color(0xFF00B4AB),
                      repoUrl: 'https://github.com/AttitudeTopHacker/msm-khata',
                    ),
                    _buildRepoCard(
                      context: context,
                      name: 'ContactSavingCloud',
                      desc: 'Cloud contact saving and multi-device identity synchronization system.',
                      language: 'Java / HTML',
                      langColor: const Color(0xFFE34C26),
                      repoUrl: 'https://github.com/AttitudeTopHacker/ContactSavingCloud',
                    ),
                    _buildRepoCard(
                      context: context,
                      name: 'E-commerce-Spring-boot-Backend',
                      desc: 'Robust Spring Boot transactional microservice backend with authenticated checkout pipeline.',
                      language: 'Java / Spring Boot',
                      langColor: const Color(0xFFB07219),
                      repoUrl: 'https://github.com/AttitudeTopHacker/E-commerce-Spring-boot-Backend',
                    ),
                    _buildRepoCard(
                      context: context,
                      name: 'remote-desk-v2',
                      desc: 'Remote desktop assistance, live connectivity and low-latency frame streaming suite.',
                      language: 'Java / Core',
                      langColor: const Color(0xFF3572A5),
                      repoUrl: 'https://github.com/AttitudeTopHacker/remote-desk-v2',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 5. Tech Stack Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildTechChip('Flutter', const Color(0xFF02569B)),
                    _buildTechChip('Dart', const Color(0xFF00B4AB)),
                    _buildTechChip('Java & Spring', const Color(0xFFB07219)),
                    _buildTechChip('Python 3.12', const Color(0xFF3572A5)),
                    _buildTechChip('FastAPI', const Color(0xFF05998B)),
                    _buildTechChip('Supabase', const Color(0xFF3ECF8E)),
                    _buildTechChip('PostgreSQL', const Color(0xFF336791)),
                    _buildTechChip('Docker', const Color(0xFF2496ED)),
                  ],
                ),

                const SizedBox(height: 22),

                // 6. Action Button: View GitHub Profile
                InkWell(
                  onTap: () {
                    onProfileTap?.call();
                    _openGitHubUrl(context, githubProfileUrl);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF21262D), Color(0xFF161B22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF30363D), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.terminal_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'View GitHub Profile (@AttitudeTopHacker)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_outward_rounded, color: Color(0xFF8B949E), size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String sublabel,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: const TextStyle(color: Color(0xFF6E7681), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoCard({
    required BuildContext context,
    required String name,
    required String desc,
    required String language,
    required Color langColor,
    required String repoUrl,
  }) {
    return InkWell(
      onTap: () => _openGitHubUrl(context, repoUrl),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF30363D), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book_outlined, color: Color(0xFF8B949E), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF58A6FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D), width: 0.8),
                  ),
                  child: const Text('Public', style: TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: langColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(language, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                const Spacer(),
                const Icon(Icons.arrow_outward_rounded, color: Color(0xFF8B949E), size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechChip(String label, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF30363D), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
