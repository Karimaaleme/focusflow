import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forest_tree.dart';
import '../services/forest_service.dart';
import 'focus_session_forest_screen.dart' show TreeGrowthPainter;

class MyForestScreen extends StatefulWidget {
  const MyForestScreen({super.key});

  @override
  State<MyForestScreen> createState() => _MyForestScreenState();
}

class _MyForestScreenState extends State<MyForestScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  bool _loading = true;
  String? _error;
  List<ForestTree> _trees = [];
  ForestProfile _profile = ForestProfile.empty();
  _ViewMode _viewMode = _ViewMode.grid;
  _FilterMode _filter = _FilterMode.all;
  _TimeRange _timeRange = _TimeRange.allTime;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trees = await ForestService.getTrees();
      final profile = await ForestService.getProfile();
      setState(() {
        _trees = trees;
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

  List<ForestTree> get _filteredTrees {
    var list = _trees;

    // Filter by success state
    switch (_filter) {
      case _FilterMode.completed:
        list = list.where((t) => t.isSuccess).toList();
        break;
      case _FilterMode.failed:
        list = list.where((t) => !t.isSuccess).toList();
        break;
      default:
        break;
    }

    // Filter by time range
    final now = DateTime.now();
    switch (_timeRange) {
      case _TimeRange.thisWeek:
        final weekAgo = now.subtract(const Duration(days: 7));
        list = list.where((t) => t.completedAt.isAfter(weekAgo)).toList();
        break;
      case _TimeRange.thisMonth:
        final monthAgo = now.subtract(const Duration(days: 30));
        list = list.where((t) => t.completedAt.isAfter(monthAgo)).toList();
        break;
      default:
        break;
    }

    return list;
  }

  int get _totalMinutes => _trees
      .where((t) => t.isSuccess)
      .fold(0, (sum, t) => sum + t.focusedMinutes);

  int get _weeklyMinutes {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _trees
        .where((t) => t.isSuccess && t.completedAt.isAfter(weekAgo))
        .fold(0, (sum, t) => sum + t.focusedMinutes);
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
          'My Forest',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              painter: _ForestScenePainter(_bgController.value),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF52B788)))
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌧️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF52B788)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Stats header
        _buildStatsHeader(),
        // Filters
        _buildFilters(),
        // Tree grid / list
        Expanded(
          child: _filteredTrees.isEmpty
              ? _buildEmpty()
              : _viewMode == _ViewMode.grid
                  ? _buildGrid()
                  : _buildList(),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    final completedCount = _trees.where((t) => t.isSuccess).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _HeaderStat(
                      icon: '🌳',
                      value: '$completedCount',
                      label: 'Trees Grown',
                    ),
                    _HeaderStat(
                      icon: '⏱️',
                      value: '${_totalMinutes}m',
                      label: 'Total Focus',
                    ),
                    _HeaderStat(
                      icon: '📅',
                      value: '${_weeklyMinutes}m',
                      label: 'This Week',
                    ),
                    _HeaderStat(
                      icon: '🔥',
                      value: '${_profile.currentStreak}d',
                      label: 'Streak',
                    ),
                  ],
                ),
                if (_profile.currentStreak > 0) ...[
                  const SizedBox(height: 12),
                  _buildStreakBar(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBar() {
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      final dayStart = DateTime(d.year, d.month, d.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final hasFocus = _trees.any(
        (t) => t.isSuccess &&
            t.completedAt.isAfter(dayStart) &&
            t.completedAt.isBefore(dayEnd),
      );
      return hasFocus;
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        final dayLabel = DateFormat('E')
            .format(DateTime.now().subtract(Duration(days: 6 - i)));
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: days[i]
                        ? const Color(0xFF52B788)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: days[i]
                          ? const Color(0xFF52B788).withOpacity(0.6)
                          : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Center(
                    child: days[i]
                        ? const Text('🌿', style: TextStyle(fontSize: 12))
                        : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dayLabel[0],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // View toggle
          _IconToggle(
            icon: Icons.grid_view_rounded,
            active: _viewMode == _ViewMode.grid,
            onTap: () => setState(() => _viewMode = _ViewMode.grid),
          ),
          const SizedBox(width: 6),
          _IconToggle(
            icon: Icons.list_rounded,
            active: _viewMode == _ViewMode.list,
            onTap: () => setState(() => _viewMode = _ViewMode.list),
          ),
          const SizedBox(width: 12),
          // Filter chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                      label: 'All',
                      active: _filter == _FilterMode.all,
                      onTap: () => setState(() => _filter = _FilterMode.all)),
                  const SizedBox(width: 6),
                  _FilterChip(
                      label: '🌳 Grown',
                      active: _filter == _FilterMode.completed,
                      onTap: () =>
                          setState(() => _filter = _FilterMode.completed)),
                  const SizedBox(width: 6),
                  _FilterChip(
                      label: '🥀 Failed',
                      active: _filter == _FilterMode.failed,
                      onTap: () =>
                          setState(() => _filter = _FilterMode.failed)),
                  const SizedBox(width: 12),
                  _FilterChip(
                      label: 'This Week',
                      active: _timeRange == _TimeRange.thisWeek,
                      onTap: () => setState(
                          () => _timeRange = _timeRange == _TimeRange.thisWeek
                              ? _TimeRange.allTime
                              : _TimeRange.thisWeek)),
                  const SizedBox(width: 6),
                  _FilterChip(
                      label: 'This Month',
                      active: _timeRange == _TimeRange.thisMonth,
                      onTap: () => setState(
                          () => _timeRange = _timeRange == _TimeRange.thisMonth
                              ? _TimeRange.allTime
                              : _TimeRange.thisMonth)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: _filteredTrees.length,
      itemBuilder: (_, i) => _TreeGridItem(
        tree: _filteredTrees[i],
        onTap: () => _showTreeDetail(_filteredTrees[i]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _filteredTrees.length,
      itemBuilder: (_, i) => _TreeListItem(
        tree: _filteredTrees[i],
        onTap: () => _showTreeDetail(_filteredTrees[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Your forest is empty',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete focus sessions to grow trees here',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showTreeDetail(ForestTree tree) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TreeDetailSheet(tree: tree),
    );
  }
}

// ── Tree Grid Item ────────────────────────────────────────────────────────────

class _TreeGridItem extends StatelessWidget {
  final ForestTree tree;
  final VoidCallback onTap;

  const _TreeGridItem({required this.tree, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tree.isSuccess
              ? const Color(0xFF2D6A4F).withOpacity(0.2)
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tree.isSuccess
                ? const Color(0xFF52B788).withOpacity(0.35)
                : Colors.redAccent.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: CustomPaint(
                  painter: TreeGrowthPainter(
                    progress: tree.isSuccess ? 1.0 : 0.3,
                    plantType: tree.plantType,
                    isDead: !tree.isSuccess,
                    isCompleted: tree.isSuccess,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${tree.focusedMinutes}m',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d').format(tree.completedAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 10,
                      ),
                    ),
                    if (tree.isSuccess)
                      Text(
                        '+${tree.coinsEarned}🪙',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tree List Item ────────────────────────────────────────────────────────────

class _TreeListItem extends StatelessWidget {
  final ForestTree tree;
  final VoidCallback onTap;

  const _TreeListItem({required this.tree, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tree.isSuccess
              ? const Color(0xFF2D6A4F).withOpacity(0.15)
              : Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tree.isSuccess
                ? const Color(0xFF52B788).withOpacity(0.25)
                : Colors.redAccent.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Tree mini preview
            SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: TreeGrowthPainter(
                  progress: tree.isSuccess ? 1.0 : 0.3,
                  plantType: tree.plantType,
                  isDead: !tree.isSuccess,
                  isCompleted: tree.isSuccess,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tree.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tree.isSuccess
                              ? const Color(0xFF52B788).withOpacity(0.2)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tree.isSuccess ? 'Grown' : 'Withered',
                          style: TextStyle(
                            color: tree.isSuccess
                                ? const Color(0xFF52B788)
                                : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (tree.taskTitle != null)
                    Text(
                      tree.taskTitle!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    DateFormat('EEEE, MMM d · h:mm a')
                        .format(tree.completedAt),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tree.focusedMinutes}m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (tree.isSuccess) ...[
                  Text(
                    '+${tree.coinsEarned}🪙',
                    style: const TextStyle(
                        color: Color(0xFFFFD700), fontSize: 12),
                  ),
                  Text(
                    '+${tree.xpEarned}⚡',
                    style: const TextStyle(
                        color: Color(0xFF52B788), fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tree Detail Sheet ─────────────────────────────────────────────────────────

class _TreeDetailSheet extends StatelessWidget {
  final ForestTree tree;

  const _TreeDetailSheet({required this.tree});

  @override
  Widget build(BuildContext context) {
    final eff = tree.plannedMinutes > 0
        ? (tree.focusedMinutes / tree.plannedMinutes * 100).round()
        : 100;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628).withOpacity(0.94),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Tree preview large
              SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: TreeGrowthPainter(
                    progress: tree.isSuccess ? 1.0 : 0.3,
                    plantType: tree.plantType,
                    isDead: !tree.isSuccess,
                    isCompleted: tree.isSuccess,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${tree.label} ${tree.isSuccess ? '🌳' : '🥀'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                DateFormat('EEEE, MMMM d, yyyy · h:mm a')
                    .format(tree.completedAt),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              const SizedBox(height: 24),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DetailStat('Focused', '${tree.focusedMinutes}m', Colors.white),
                  _DetailStat('Planned', '${tree.plannedMinutes}m', Colors.white54),
                  _DetailStat('Efficiency', '$eff%',
                      eff >= 80 ? const Color(0xFF52B788) : Colors.orangeAccent),
                ],
              ),
              if (tree.isSuccess) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RewardBadge('+${tree.coinsEarned}', '🪙 Coins',
                        const Color(0xFFFFD700)),
                    const SizedBox(width: 12),
                    _RewardBadge(
                        '+${tree.xpEarned}', '⚡ XP', const Color(0xFF52B788)),
                  ],
                ),
              ],
              if (tree.taskTitle != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('📋 ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          tree.taskTitle!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Close',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label.toUpperCase(),
            style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                letterSpacing: 1)),
      ],
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _RewardBadge(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Filter Widgets ────────────────────────────────────────────────────────────

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _IconToggle(
      {required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF52B788).withOpacity(0.3)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF52B788).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Icon(icon,
            color: active ? const Color(0xFF52B788) : Colors.white54,
            size: 18),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF52B788).withOpacity(0.25)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF52B788).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF52B788) : Colors.white60,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _HeaderStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.45), fontSize: 9)),
      ],
    );
  }
}

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _ViewMode { grid, list }

enum _FilterMode { all, completed, failed }

enum _TimeRange { allTime, thisWeek, thisMonth }

// ── Background Painter ────────────────────────────────────────────────────────

class _ForestScenePainter extends CustomPainter {
  final double t;
  _ForestScenePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Sky gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF0A1628), Color(0xFF0D2B1F)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Stars
    final starPaint = Paint()..color = Colors.white.withOpacity(0.3);
    final starPositions = [
      Offset(size.width * 0.1, size.height * 0.05),
      Offset(size.width * 0.35, size.height * 0.08),
      Offset(size.width * 0.6, size.height * 0.04),
      Offset(size.width * 0.85, size.height * 0.07),
      Offset(size.width * 0.2, size.height * 0.12),
      Offset(size.width * 0.75, size.height * 0.13),
    ];
    for (final p in starPositions) {
      canvas.drawCircle(p, 1.5, starPaint);
    }

    // Moon
    final moonPaint = Paint()
      ..color = Colors.white.withOpacity(0.12 + t * 0.06);
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.1), 22, moonPaint);
    canvas.drawCircle(
        Offset(size.width * 0.87, size.height * 0.1),
        18,
        Paint()..color = const Color(0xFF0A1628));

    // Forest floor silhouette
    final groundPaint = Paint()..color = const Color(0xFF0D2B1F);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22),
      groundPaint,
    );

    // Tree silhouettes
    final silPaint = Paint()..color = const Color(0xFF0B2016);
    final treePositions = [0.05, 0.18, 0.32, 0.52, 0.70, 0.83, 0.94];
    final treeHeights = [0.30, 0.25, 0.35, 0.28, 0.32, 0.22, 0.30];

    for (int i = 0; i < treePositions.length; i++) {
      final x = size.width * treePositions[i];
      final h = size.height * treeHeights[i];
      final baseY = size.height * 0.78;

      final path = Path();
      path.moveTo(x - 4, baseY);
      path.lineTo(x + 4, baseY);
      path.lineTo(x + 4, baseY - h * 0.3);
      path.lineTo(x + 22, baseY - h * 0.3);
      path.lineTo(x, baseY - h);
      path.lineTo(x - 22, baseY - h * 0.3);
      path.lineTo(x - 4, baseY - h * 0.3);
      path.close();
      canvas.drawPath(path, silPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForestScenePainter old) => old.t != t;
}
