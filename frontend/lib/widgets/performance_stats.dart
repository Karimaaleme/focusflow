import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class PerformanceStats extends StatefulWidget {
  const PerformanceStats({super.key});

  @override
  State<PerformanceStats> createState() => _PerformanceStatsState();
}

class _PerformanceStatsState extends State<PerformanceStats> {
  bool _loading = true;
  int _completionRate = 0;
  int _tasksDone = 0;
  int _focusMinutes = 0;
  List<int> _weeklyData = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await ApiService.getTasks();
      final total = tasks.length;
      final done = tasks.where((t) => t.isCompleted).length;

      List<Map<String, dynamic>> sessions = [];
      try {
        sessions = await ApiService.getFocusSessions();
      } catch (_) {}

      final weeklyData = List.filled(7, 0);
      int totalFocusMinutes = 0;
      final now = DateTime.now();

      if (sessions.isNotEmpty) {
        for (final s in sessions) {
          final mins = s['focused_minutes'] as int? ?? 0;
          totalFocusMinutes += mins;
          final start = DateTime.tryParse(s['started_at'] ?? '');
          if (start == null) continue;
          final diff = now.difference(start).inDays;
          if (diff >= 0 && diff < 7) {
            // diff=0 → today (index 6), diff=6 → 6 days ago (index 0)
            weeklyData[6 - diff] += mins ~/ 60; // store as task-count-style units (hours rounded)
          }
        }
      } else {
        // Fallback: use completed tasks as proxy
        for (final t in tasks) {
          if (!t.isCompleted) continue;
          final time = t.dueDatetime ?? t.createdAt;
          final diff = now.difference(time).inDays;
          if (diff >= 0 && diff < 7) {
            weeklyData[6 - diff] += 1;
          }
          totalFocusMinutes += t.actualMinutes > 0 ? t.actualMinutes : t.estimatedMinutes;
        }
      }

      if (!mounted) return;
      setState(() {
        _completionRate = total == 0 ? 0 : (done / total * 100).round();
        _tasksDone = done;
        _focusMinutes = totalFocusMinutes;
        _weeklyData = weeklyData;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: l.completionLabel,
                value: "$_completionRate%",
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                label: l.tasksDoneLabel,
                value: "$_tasksDone",
                icon: Icons.task_alt,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                label: l.focusTimeLabel,
                value: "${(_focusMinutes / 60).toStringAsFixed(1)}h",
                icon: Icons.timer_outlined,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.weeklyActivityTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(l.last7DaysLabel, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _WeeklyBarChart(data: _weeklyData, dayLabels: l.weekDayAbbrs),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<int> data;
  final List<String> dayLabels;
  const _WeeklyBarChart({required this.data, required this.dayLabels});

  @override
  Widget build(BuildContext context) {
    final max = data.isEmpty ? 1 : data.reduce(math.max);
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(data.length, (index) {
        final v = data[index];
        final h = (v / (max == 0 ? 1 : max));
        final isToday = index == 6; // last bar is always today

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (v > 0)
              Text(
                v.toString(),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            SizedBox(
              height: 60,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  FractionallySizedBox(
                    heightFactor: h > 0 ? h : 0.05,
                    child: Container(
                      width: 12,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.blue : Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dayLabels[index],
              style: TextStyle(
                fontSize: 12,
                color: isToday ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      }),
    );
  }
}
