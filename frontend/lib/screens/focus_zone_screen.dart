import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/forest_tree.dart';
import '../services/forest_service.dart';
import '../services/user_display_service.dart';
import 'focus_session_forest_screen.dart';
import 'my_forest_screen.dart';
import 'forest_leaderboard_screen.dart';
import 'forest_achievements_screen.dart';
import 'focus_room_screen.dart';

enum _FocusMode { classic, group, deep }

class FocusZoneScreen extends StatefulWidget {
  const FocusZoneScreen({super.key});

  @override
  State<FocusZoneScreen> createState() => _FocusZoneScreenState();
}

class _FocusZoneScreenState extends State<FocusZoneScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _floatController;
  late final Animation<double> _floatAnim;

  ForestProfile? _profile;
  List<ForestTree> _recentTrees = [];
  bool _loading = true;
  String _selectedPlant = 'oak';
  int _selectedMinutes = 25;
  _FocusMode _selectedMode = _FocusMode.classic;

  final _durations = [15, 25, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _load();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await ForestService.getProfile();
      final trees = await ForestService.getTrees();
      setState(() {
        _profile = profile;
        _recentTrees = trees.take(6).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startFocus() async {
    if (_selectedMode == _FocusMode.group) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FocusRoomScreen()),
      );
      _load();
      return;
    }
    final displayName = await UserDisplayService.getMyDisplayName();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusSessionForestScreen(
          plannedMinutes: _selectedMinutes,
          plantType: _selectedPlant,
          forestModeEnabled: true,
          displayName: displayName,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Focus Zone',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated forest background
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              painter: _ForestBgPainter(_bgController.value),
              size: Size.infinite,
            ),
          ),

          // Floating leaves overlay
          const _FloatingLeavesOverlay(),

          // Main content
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsBar(),
          const SizedBox(height: 24),

          _buildSectionLabel('Session Mode'),
          const SizedBox(height: 12),
          _buildModeSelector(),
          const SizedBox(height: 24),

          if (_selectedMode != _FocusMode.group) ...[
            _buildSectionLabel('Choose Your Plant'),
            const SizedBox(height: 12),
            _buildPlantSelector(),
            const SizedBox(height: 24),
            _buildSectionLabel('Focus Duration'),
            const SizedBox(height: 12),
            _buildDurationSelector(),
            const SizedBox(height: 32),
          ] else
            const SizedBox(height: 8),

          _buildStartButton(),
          const SizedBox(height: 32),

          _buildSectionLabel('Explore'),
          const SizedBox(height: 12),
          _buildNavCards(),
          const SizedBox(height: 24),

          if (_recentTrees.isNotEmpty) ...[
            _buildSectionLabel('Recent Forest'),
            const SizedBox(height: 12),
            _buildRecentForest(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final p = _profile ?? ForestProfile.empty();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(icon: '🪙', label: 'Coins', value: '${p.totalCoins}'),
              _VertDivider(),
              _StatChip(icon: '⚡', label: 'XP', value: '${p.totalXP}'),
              _VertDivider(),
              _StatChip(icon: '🔥', label: 'Streak', value: '${p.currentStreak}d'),
              _VertDivider(),
              _StatChip(icon: '🌲', label: 'Trees', value: '${p.completedSessions}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      children: [
        _FocusModeCard(
          selected: _selectedMode == _FocusMode.classic,
          icon: '🌱',
          title: 'Classic Solo Timer',
          subtitle: 'Personal focus · grow your forest',
          color: const Color(0xFF52B788),
          onTap: () => setState(() => _selectedMode = _FocusMode.classic),
        ),
        const SizedBox(height: 10),
        _FocusModeCard(
          selected: _selectedMode == _FocusMode.group,
          icon: '👥',
          title: 'Group Focus Session',
          subtitle: 'Grow together with friends',
          color: const Color(0xFF2575FC),
          onTap: () => setState(() => _selectedMode = _FocusMode.group),
        ),
        const SizedBox(height: 10),
        _FocusModeCard(
          selected: _selectedMode == _FocusMode.deep,
          icon: '🌊',
          title: 'Deep Focus Mode',
          subtitle: 'Uninterrupted long session · 45+ min',
          color: const Color(0xFF9B5DE5),
          onTap: () => setState(() {
            _selectedMode = _FocusMode.deep;
            if (_selectedMinutes < 45) _selectedMinutes = 45;
          }),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildPlantSelector() {
    final plants = [
      {'id': 'oak', 'emoji': '🌳', 'name': 'Oak'},
      {'id': 'pine', 'emoji': '🌲', 'name': 'Pine'},
      {'id': 'bonsai', 'emoji': '🪴', 'name': 'Bonsai'},
      {'id': 'flower', 'emoji': '🌺', 'name': 'Flower'},
      {'id': 'cherry', 'emoji': '🌸', 'name': 'Cherry'},
      {'id': 'cactus', 'emoji': '🌵', 'name': 'Cactus'},
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: plants.length,
        itemBuilder: (_, i) {
          final p = plants[i];
          final selected = _selectedPlant == p['id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedPlant = p['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2D6A4F).withOpacity(0.5)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF52B788)
                      : Colors.white.withOpacity(0.1),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p['emoji']!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    p['name']!,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._durations.map((m) {
          final selected = _selectedMinutes == m;
          return GestureDetector(
            onTap: () => setState(() => _selectedMinutes = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF52B788)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF52B788)
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Text(
                '${m}m',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: _showCustomDurationPicker,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: !_durations.contains(_selectedMinutes)
                  ? const Color(0xFF52B788)
                  : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: !_durations.contains(_selectedMinutes)
                    ? const Color(0xFF52B788)
                    : Colors.white.withOpacity(0.12),
              ),
            ),
            child: Text(
              !_durations.contains(_selectedMinutes)
                  ? '${_selectedMinutes}m ✎'
                  : 'Custom',
              style: TextStyle(
                color: !_durations.contains(_selectedMinutes)
                    ? Colors.white
                    : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomDurationPicker() async {
    int temp = !_durations.contains(_selectedMinutes) ? _selectedMinutes : 45;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Custom Duration',
          style: TextStyle(color: Colors.white),
        ),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$temp minutes',
                style: const TextStyle(
                  color: Color(0xFF52B788),
                  fontSize: 32,
                  fontWeight: FontWeight.w200,
                ),
              ),
              Slider(
                value: temp.toDouble(),
                min: 5,
                max: 180,
                divisions: 35,
                activeColor: const Color(0xFF52B788),
                inactiveColor: Colors.white12,
                onChanged: (v) => setS(() => temp = v.round()),
              ),
              Text(
                'Drag to set duration (5–180 min)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _selectedMinutes = temp);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF52B788)),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    final String label;
    final String icon;
    final List<Color> colors;

    switch (_selectedMode) {
      case _FocusMode.group:
        label = 'Enter Focus Room';
        icon = '👥';
        colors = [const Color(0xFF2575FC), const Color(0xFF0D47A1)];
        break;
      case _FocusMode.deep:
        label = 'Deep Focus  ·  $_selectedMinutes min';
        icon = '🌊';
        colors = [const Color(0xFF9B5DE5), const Color(0xFF5E0DB3)];
        break;
      case _FocusMode.classic:
        label = 'Plant & Focus  ·  $_selectedMinutes min';
        icon = '🌱';
        colors = [const Color(0xFF52B788), const Color(0xFF2D6A4F)];
    }

    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _floatAnim.value * 0.3),
        child: child,
      ),
      child: GestureDetector(
        onTap: _startFocus,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors[0].withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _NavCard(
          emoji: '🌳',
          title: 'My Forest',
          subtitle: '${_profile?.completedSessions ?? 0} trees',
          color: const Color(0xFF2D6A4F),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyForestScreen()),
          ).then((_) => _load()),
        ),
        _NavCard(
          emoji: '🏆',
          title: 'Leaderboard',
          subtitle: 'Global rankings',
          color: const Color(0xFF7B4F00),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ForestLeaderboardScreen()),
          ),
        ),
        _NavCard(
          emoji: '🎖️',
          title: 'Achievements',
          subtitle: 'Unlock rewards',
          color: const Color(0xFF4A1D96),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ForestAchievementsScreen()),
          ),
        ),
        _NavCard(
          emoji: '👥',
          title: 'Focus Room',
          subtitle: 'Grow together',
          color: const Color(0xFF0E4D8B),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FocusRoomScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentForest() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _recentTrees.length,
        itemBuilder: (_, i) {
          final t = _recentTrees[i];
          return Container(
            width: 76,
            decoration: BoxDecoration(
              color: t.isSuccess
                  ? const Color(0xFF2D6A4F).withOpacity(0.3)
                  : Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: t.isSuccess
                    ? const Color(0xFF52B788).withOpacity(0.4)
                    : Colors.redAccent.withOpacity(0.3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(
                  '${t.focusedMinutes}m',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SettingsSheet(),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
                letterSpacing: 0.5)),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.55), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _soundEnabled = true;
  bool _strictMode = false;
  bool _reminders = true;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628).withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Focus Zone Settings',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
              const SizedBox(height: 20),
              _SettingRow(
                icon: '🔊',
                title: 'Focus Sounds',
                subtitle: 'Ambient nature sounds',
                value: _soundEnabled,
                onChanged: (v) => setState(() => _soundEnabled = v),
              ),
              _SettingRow(
                icon: '🔒',
                title: 'Strict Mode',
                subtitle: 'Prevent early exit',
                value: _strictMode,
                onChanged: (v) => setState(() => _strictMode = v),
              ),
              _SettingRow(
                icon: '🔔',
                title: 'Focus Reminders',
                subtitle: 'Daily session reminders',
                value: _reminders,
                onChanged: (v) => setState(() => _reminders = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF52B788),
            activeTrackColor: const Color(0xFF2D6A4F),
          ),
        ],
      ),
    );
  }
}

class _FocusModeCard extends StatelessWidget {
  final bool selected;
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FocusModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.18)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color.withOpacity(0.7)
                : Colors.white.withOpacity(0.1),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painters & Animations ────────────────────────────────────────────────────

class _ForestBgPainter extends CustomPainter {
  final double t;
  _ForestBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1628), Color(0xFF0D2B1F)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final angle = t * 2 * math.pi;

    // Green orb
    final c1 = Offset(
      size.width * 0.5 + size.width * 0.25 * math.cos(angle),
      size.height * 0.35 + size.height * 0.1 * math.sin(angle),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF2D6A4F).withOpacity(0.35),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromCircle(center: c1, radius: size.width * 0.7)),
    );

    // Blue orb
    final c2 = Offset(
      size.width * 0.4 + size.width * 0.2 * math.sin(angle + 1),
      size.height * 0.65 + size.height * 0.12 * math.cos(angle + 1),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF1A3A5C).withOpacity(0.3),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromCircle(center: c2, radius: size.width * 0.8)),
    );

    // Silhouette trees at bottom
    _drawTreeSilhouettes(canvas, size);
  }

  void _drawTreeSilhouettes(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D2B1F).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final positions = [0.05, 0.15, 0.25, 0.40, 0.55, 0.68, 0.80, 0.92];
    final heights = [0.22, 0.30, 0.18, 0.28, 0.20, 0.32, 0.22, 0.26];

    for (int i = 0; i < positions.length; i++) {
      final x = size.width * positions[i];
      final h = size.height * heights[i];
      final baseY = size.height;

      final path = Path();
      path.moveTo(x, baseY);
      path.lineTo(x - 18, baseY - h * 0.4);
      path.lineTo(x - 12, baseY - h * 0.4);
      path.lineTo(x - 20, baseY - h * 0.7);
      path.lineTo(x - 10, baseY - h * 0.7);
      path.lineTo(x, baseY - h);
      path.lineTo(x + 10, baseY - h * 0.7);
      path.lineTo(x + 20, baseY - h * 0.7);
      path.lineTo(x + 12, baseY - h * 0.4);
      path.lineTo(x + 18, baseY - h * 0.4);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForestBgPainter old) => old.t != t;
}

class _FloatingLeavesOverlay extends StatefulWidget {
  const _FloatingLeavesOverlay();
  @override
  State<_FloatingLeavesOverlay> createState() => _FloatingLeavesOverlayState();
}

class _FloatingLeavesOverlayState extends State<_FloatingLeavesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rnd = math.Random();
  late final List<_Leaf> _leaves;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _leaves = List.generate(12, (_) => _Leaf(_rnd));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _LeafPainter(_leaves, _ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _Leaf {
  late double x, y, speed, size, opacity, sway;
  _Leaf(math.Random rnd) {
    x = rnd.nextDouble();
    y = rnd.nextDouble();
    speed = 0.02 + rnd.nextDouble() * 0.03;
    size = 4 + rnd.nextDouble() * 5;
    opacity = 0.1 + rnd.nextDouble() * 0.25;
    sway = rnd.nextDouble() * 0.02 - 0.01;
  }
}

class _LeafPainter extends CustomPainter {
  final List<_Leaf> leaves;
  final double t;
  _LeafPainter(this.leaves, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in leaves) {
      l.y -= l.speed * 0.003;
      l.x += l.sway * 0.5;
      if (l.y < -0.05) {
        l.y = 1.05;
        l.x = math.Random().nextDouble();
      }
      final paint = Paint()
        ..color = const Color(0xFF52B788).withOpacity(l.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(l.x * size.width, l.y * size.height),
          width: l.size * 1.8,
          height: l.size,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LeafPainter old) => true;
}
