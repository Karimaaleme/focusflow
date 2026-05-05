// lib/screens/analytics_plus_screen.dart
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';

class AnalyticsPlusScreen extends StatefulWidget {

  const AnalyticsPlusScreen({super.key});

  @override
  State<AnalyticsPlusScreen> createState() => _AnalyticsPlusScreenState();
}

class _AnalyticsPlusScreenState extends State<AnalyticsPlusScreen> {
  bool loading = true;
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    tasks = await ApiService.getTasks();
    if (mounted) setState(() => loading = false);
  }

  // ---------- HELPERS ----------
  int _hourLoad(int hour) {
    return tasks.where((t) {
      if (t.dueDatetime == null) return false;
      return t.dueDatetime!.hour == hour;
    }).length;
  }

  int _weekDayDone(int weekday) {
    return tasks.where((t) {
      if (!t.isCompleted || t.dueDatetime == null) return false;
      return t.dueDatetime!.weekday == weekday;
    }).length;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).advancedAnalytics),
        centerTitle: true,
        backgroundColor: const Color(0xFFF6F6F4),
        elevation: 0,
        actions: const [LanguageToggleButton()],
      ),
      body: Builder(builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle(l.dailyHeatmapLabel),
            _DailyHeatmap(hourLoad: _hourLoad),

            const SizedBox(height: 24),

            _sectionTitle(l.weeklyProgressLabel),
            _WeeklyTimeline(weekDayDone: _weekDayDone),

            const SizedBox(height: 24),

            _sectionTitle(l.monthlyReportLabel),
            _MonthlyReport(tasks: tasks),
          ],
        );
      }),
    );
  }
  

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
class WeeklyLoadChart extends StatelessWidget {
  final Map<String, int> loadByDay;

  const WeeklyLoadChart({super.key, required this.loadByDay});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: loadByDay.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text(e.key)),
              Expanded(
                child: LinearProgressIndicator(
                  value: (e.value / 300).clamp(0, 1),
                  minHeight: 10,
                ),
              ),
              const SizedBox(width: 8),
              Text("${e.value}m"),
            ],
          ),
        );
      }).toList(),
    );
  }
}
class MonthlySummaryCard extends StatelessWidget {
  final int completed;
  final int pending;
  final int total;

  const MonthlySummaryCard({
    super.key,
    required this.completed,
    required this.pending,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Completed: $completed"),
        Text("Pending: $pending"),
        Text("Total: $total"),
      ],
    );
  }
}


// =======================================================
// 4.1 DAILY HEATMAP
// =======================================================

class _DailyHeatmap extends StatelessWidget {
  final int Function(int hour) hourLoad;

  const _DailyHeatmap({required this.hourLoad});

  Color _colorFor(int count) {
    if (count == 0) return Colors.grey[200]!;
    if (count == 1) return Colors.green[200]!;
    if (count == 2) return Colors.orange[300]!;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(24, (h) {
        final count = hourLoad(h);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _colorFor(count),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "$h",
              style: const TextStyle(fontSize: 10),
            ),
          ],
        );
      }),
    );
  }
}

// =======================================================
// 4.2 WEEKLY TIMELINE
// =======================================================

class _WeeklyTimeline extends StatelessWidget {
  final int Function(int weekday) weekDayDone;

  const _WeeklyTimeline({required this.weekDayDone});

  static const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(7, (i) {
        final done = weekDayDone(i + 1);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text(days[i])),
              Expanded(
                child: LinearProgressIndicator(
                  value: (done / 5).clamp(0.0, 1.0),
                  minHeight: 10,
                ),
              ),
              const SizedBox(width: 8),
              Text("$done"),
            ],
          ),
        );
      }),
    );
  }
}

// =======================================================
// 4.3 MONTHLY REPORT
// =======================================================
class DailyHeatmap extends StatelessWidget {
  final Map<int, int> focusByHour; // hour -> minutes

  const DailyHeatmap({super.key, required this.focusByHour});

  Color _colorFor(int minutes) {
    if (minutes == 0) return Colors.grey[200]!;
    if (minutes < 30) return Colors.green[200]!;
    if (minutes < 60) return Colors.orange[300]!;
    return Colors.red[300]!;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 24,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (_, hour) {
        final minutes = focusByHour[hour] ?? 0;
        return Container(
          decoration: BoxDecoration(
            color: _colorFor(minutes),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            "$hour",
            style: const TextStyle(fontSize: 11),
          ),
        );
      },
    );
  }
}

class _MonthlyReport extends StatelessWidget {
  final List<Task> tasks;

  const _MonthlyReport({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((t) => t.isCompleted).length;
    final pending = tasks.where((t) => !t.isCompleted).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Builder(builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.completedCount(completed),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(l.pendingCount(pending)),
          const SizedBox(height: 12),
          Text(
            completed > pending ? l.greatMonthMessage : l.challengingMonthMessage,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
        );
      }),
    );
  }
}
