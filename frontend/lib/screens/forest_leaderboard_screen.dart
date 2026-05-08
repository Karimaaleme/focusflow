import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/forest_service.dart';

class ForestLeaderboardScreen extends StatefulWidget {
  const ForestLeaderboardScreen({super.key});

  @override
  State<ForestLeaderboardScreen> createState() =>
      _ForestLeaderboardScreenState();
}

class _ForestLeaderboardScreenState extends State<ForestLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  List<LeaderboardEntry> _allTimeEntries = [];
  List<LeaderboardEntry> _weeklyEntries = [];
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final allTime = await ForestService.getLeaderboard(weekly: false);
      final weekly = await ForestService.getLeaderboard(weekly: true);
      setState(() {
        _allTimeEntries = allTime;
        _weeklyEntries = weekly;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFFFFD700),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'All Time'),
            Tab(text: 'This Week'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLeaderboardList(_allTimeEntries, weekly: false),
                    _buildLeaderboardList(_weeklyEntries, weekly: true),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            child: const Text('Retry', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardEntry> entries, {required bool weekly}) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'No data yet.\nBe the first to focus!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // My position
    final myIdx = entries.indexWhere((e) => e.uid == _myUid);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: entries.length + (myIdx > 5 ? 2 : 1),
      itemBuilder: (_, i) {
        // Top 3 podium card at index 0
        if (i == 0 && entries.length >= 3) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _Podium(
              first: entries[0],
              second: entries.length > 1 ? entries[1] : null,
              third: entries.length > 2 ? entries[2] : null,
              myUid: _myUid,
              weekly: weekly,
            ),
          );
        }

        final entryIdx = i - 1;
        if (entryIdx < 0 || entryIdx >= entries.length) return const SizedBox();

        // My floating rank at bottom if not in top visible
        if (myIdx > 5 && i == entries.length + 1) {
          return _MyRankBanner(entry: entries[myIdx], weekly: weekly);
        }

        final e = entries[entryIdx];
        final isMe = e.uid == _myUid;
        return _LeaderboardRow(
          entry: e,
          isMe: isMe,
          weekly: weekly,
        );
      },
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final LeaderboardEntry first;
  final LeaderboardEntry? second;
  final LeaderboardEntry? third;
  final String? myUid;
  final bool weekly;

  const _Podium({
    required this.first,
    this.second,
    this.third,
    this.myUid,
    required this.weekly,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (second != null)
                _PodiumSlot(
                  entry: second!,
                  rank: 2,
                  height: 80,
                  color: const Color(0xFFC0C0C0),
                  isMe: second!.uid == myUid,
                  weekly: weekly,
                ),
              const SizedBox(width: 12),
              _PodiumSlot(
                entry: first,
                rank: 1,
                height: 110,
                color: const Color(0xFFFFD700),
                isMe: first.uid == myUid,
                weekly: weekly,
              ),
              const SizedBox(width: 12),
              if (third != null)
                _PodiumSlot(
                  entry: third!,
                  rank: 3,
                  height: 60,
                  color: const Color(0xFFCD7F32),
                  isMe: third!.uid == myUid,
                  weekly: weekly,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double height;
  final Color color;
  final bool isMe;
  final bool weekly;

  const _PodiumSlot({
    required this.entry,
    required this.rank,
    required this.height,
    required this.color,
    required this.isMe,
    required this.weekly,
  });

  @override
  Widget build(BuildContext context) {
    final medalEmojis = ['🥇', '🥈', '🥉'];
    final value = weekly
        ? '${entry.weeklyMinutes}m'
        : '${entry.totalFocusMinutes}m';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMe)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('You',
                style: TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        Text(medalEmojis[rank - 1], style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          entry.displayName.length > 8
              ? '${entry.displayName.substring(0, 7)}…'
              : entry.displayName,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(top: BorderSide(color: color.withOpacity(0.5), width: 2)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Leaderboard row ───────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final bool weekly;

  const _LeaderboardRow(
      {required this.entry, required this.isMe, required this.weekly});

  @override
  Widget build(BuildContext context) {
    final rankColors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final rankColor = rankColors[entry.rank] ?? Colors.white38;
    final value = weekly
        ? '${entry.weeklyMinutes}m'
        : '${entry.totalFocusMinutes}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF2D6A4F).withOpacity(0.25)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? const Color(0xFF52B788).withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          // Avatar placeholder
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.displayName.isNotEmpty
                    ? entry.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + sessions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.displayName,
                      style: TextStyle(
                        color: isMe ? const Color(0xFF52B788) : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF52B788).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: Color(0xFF52B788),
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${entry.completedSessions} sessions · ${entry.currentStreak}🔥',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 11),
                ),
              ],
            ),
          ),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                'focus time',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyRankBanner extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool weekly;

  const _MyRankBanner({required this.entry, required this.weekly});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F).withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF52B788).withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('📍', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            'Your rank: #${entry.rank}',
            style: const TextStyle(
                color: Color(0xFF52B788),
                fontWeight: FontWeight.w800,
                fontSize: 15),
          ),
          const Spacer(),
          Text(
            weekly ? '${entry.weeklyMinutes}m' : '${entry.totalFocusMinutes}m',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
