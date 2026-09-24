import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _preferredPlayer = 'mpv';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 40.0 : 16.0,
          vertical: 16.0,
        ),
        children: [
          // Section: Streaming & Playback
          _buildSectionHeader('PLAYBACK & STREAMING'),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                  title: const Text('Default Video Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _preferredPlayer == 'mpv' ? 'mpv (Recommended for DASH & Subtitles)' : 'VLC Media Player',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.surfaceElevated,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                      builder: (ctx) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Select Default Player', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              ListTile(
                                leading: const Icon(Icons.play_arrow, color: AppColors.primary),
                                title: const Text('mpv Player', style: TextStyle(color: Colors.white)),
                                subtitle: const Text('Full DASH & Subtitle support', style: TextStyle(color: AppColors.textMuted)),
                                trailing: _preferredPlayer == 'mpv' ? const Icon(Icons.check, color: AppColors.primary) : null,
                                onTap: () {
                                  setState(() => _preferredPlayer = 'mpv');
                                  Navigator.pop(ctx);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.traffic, color: Colors.orangeAccent),
                                title: const Text('VLC Media Player', style: TextStyle(color: Colors.white)),
                                subtitle: const Text('Standard Android external player', style: TextStyle(color: AppColors.textMuted)),
                                trailing: _preferredPlayer == 'vlc' ? const Icon(Icons.check, color: AppColors.primary) : null,
                                onTap: () {
                                  setState(() => _preferredPlayer = 'vlc');
                                  Navigator.pop(ctx);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: AppColors.cardBorder, height: 1),
                ListTile(
                  leading: const Icon(Icons.high_quality, color: AppColors.accentBlue),
                  title: const Text('DASH Resolution Parsing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Live MPD manifest quality discovery enabled', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(color: AppColors.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Engine & Architecture
          _buildSectionHeader('SYSTEM & CORE ENGINE'),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.developer_board, color: AppColors.accentPurple),
                  title: Text('MovieMania Core Engine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    kIsWeb ? 'Chrome Dev Bridge Connected' : 'Native Rust FFI + In-process Proxy',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x2622C55E),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text('ONLINE', style: TextStyle(color: AppColors.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Divider(color: AppColors.cardBorder, height: 1),
                ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.white70),
                  title: Text('Version', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('MovieMania 0.1.21 · Premium Streaming Edition', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Branded Footer
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MOVIEMANIA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Official Streaming Application',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
