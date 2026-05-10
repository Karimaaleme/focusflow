import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/forest_achievement.dart';
import '../models/forest_tree.dart';
import '../services/forest_service.dart';

class ForestAchievementsScreen extends StatefulWidget {
  const ForestAchievementsScreen({super.key});

  @override
  State<ForestAchievementsScreen> createState() =>
      _ForestAchievementsScreenState();
}

class _ForestAchievementsScreenState extends State<ForestAchievementsScreen> {
  bool _loading = true;
  String? _error;
  List<ForestAchievement> _achievements = [];
  ForestProfile _profile = ForestProfile.empty();
  bool _showUnlocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final achievements = await ForestService.getAchievements();
      final profile = await ForestService.getProfile();
      setState(() {
        _achievements = achievements;
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _unlockedCount => _achievements.where((a) => a.isUnlocked).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).achievementsTitle,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF52B788)))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎖️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFF52B788)),
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildHeader(),
        _buildFilterToggle(),
        Expanded(child: _buildAchievementList()),
      ],
    );
  }

  Widget _buildHeader() {
    final total = _achievements.length;
    final unlocked = _unlockedCount;
    final progress = total > 0 ? unlocked / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).achievementProgress,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                        Text(
                          '$unlocked / $total unlocked',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12),
                        ),
                      ],
                    ),
                    // Circular progress
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 5,
                            color: const Color(0xFFFFD700),
                            backgroundColor: Colors.white.withOpacity(0.1),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // XP / Coins summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AchievStat(
                        icon: '🪙',
                        label: AppLocalizations.of(context).coins,
                        value: '${_profile.totalCoins}'),
                    _AchievStat(
                        icon: '⚡', label: 'XP', value: '${_profile.totalXP}'),
                    _AchievStat(
                        icon: '📊',
                        label: AppLocalizations.of(context).levelLabel,
                        value: '${_profile.level}'),
                    _AchievStat(
                        icon: '🔥',
                        label: AppLocalizations.of(context).streakLabel,
                        value: '${_profile.currentStreak}d'),
                  ],
                ),
                // Level progress bar
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).levelN(_profile.level),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          AppLocalizations.of(context).xpToNextLevel(_profile.xpToNextLevel),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _profile.levelProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF52B788)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showUnlocked = false),
            child: _TabChip(
              label: '🔒 ${AppLocalizations.of(context).inProgress}',
              active: !_showUnlocked,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _showUnlocked = true),
            child: _TabChip(
              label: '✅ ${AppLocalizations.of(context).unlockedCount(_unlockedCount)}',
              active: _showUnlocked,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementList() {
    final items = _showUnlocked
        ? _achievements.where((a) => a.isUnlocked).toList()
        : _achievements.where((a) => !a.isUnlocked).toList();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showUnlocked ? '🎖️' : '🔓',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              _showUnlocked
                  ? AppLocalizations.of(context).noAchievementsYet
                  : AppLocalizations.of(context).allAchievementsUnlocked,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: items.length,
      itemBuilder: (_, i) => _AchievementCard(achievement: items[i]),
    );
  }
}

// ── Achievement Card ──────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final ForestAchievement achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final unlocked = a.isUnlocked;

    return Container(
      decoration: BoxDecoration(
        color: unlocked
            ? const Color(0xFF4A1D96).withOpacity(0.25)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked
              ? Colors.purple.withOpacity(0.45)
              : Colors.white.withOpacity(0.08),
          width: unlocked ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: unlocked
                    ? Colors.purple.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: unlocked
                      ? Colors.purple.withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Center(
                child: Text(
                  unlocked ? a.icon : '🔒',
                  style: TextStyle(
                      fontSize: unlocked ? 26 : 22,
                      color: unlocked ? null : Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
                          style: TextStyle(
                            color: unlocked ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (unlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFFFD700).withOpacity(0.4)),
                          ),
                          child: Text(
                            '+${a.rewardCoins}🪙',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.description,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            a.requirement,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            unlocked ? 'UNLOCKED ✓' : '${(a.progress * 100).round()}%',
                            style: TextStyle(
                              color: unlocked
                                  ? Colors.purple
                                  : Colors.white.withOpacity(0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: unlocked ? 1.0 : a.progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            unlocked ? Colors.purple : const Color(0xFF52B788),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _AchievStat extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _AchievStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.4), fontSize: 10)),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;

  const _TabChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? Colors.purple.withOpacity(0.25)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? Colors.purple.withOpacity(0.5)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.purple : Colors.white54,
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
