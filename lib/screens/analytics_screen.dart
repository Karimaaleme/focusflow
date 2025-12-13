// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../models/task.dart';
import 'analytics_plus_screen.dart';


class AnalyticsScreen extends StatefulWidget {
  final String token;

  const AnalyticsScreen({super.key, required this.token});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool loading = true;
  String? error;

  List<Task> tasks = [];

  // fake focus sessions fallback (until backend exists)
  final Map<int, int> focusByHour = {}; // hour -> minutes

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      tasks = await ApiService.getTasks(widget.token);

      _simulateFocusFromTasks(tasks);

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  // --------------------------------------------------
  // SMART FALLBACK: infer focus hours from tasks
  // --------------------------------------------------
  void _simulateFocusFromTasks(List<Task> tasks) {
    focusByHour.clear();

    for (final t in tasks.where((t) => t.isCompleted)) {
      final created = t.createdAt;
      final hour = created.hour;
      focusByHour[hour] = (focusByHour[hour] ?? 0) + t.estimatedMinutes;
    }
  }

  // --------------------------------------------------
  // METRICS
  // --------------------------------------------------
  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  int get remainingTasks => totalTasks - completedTasks;

  int get totalEstimatedMinutes =>
      tasks.fold(0, (sum, t) => sum + t.estimatedMinutes);

  int get completedMinutes => tasks
      .where((t) => t.isCompleted)
      .fold(0, (sum, t) => sum + t.estimatedMinutes);

  int get focusSessions => completedTasks;

  List<MapEntry<int, int>> get peakHours {
    final list = focusByHour.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list.take(3).toList();
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Analytics")),
        body: Center(child: Text(error!)),
        
      );
    }
    

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      appBar: AppBar(
        title: const Text("Your Analytics"),
        centerTitle: true,
      ),
      
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: "Overview",
            child: Row(
              children: [
                Expanded(
                  child: _StatBox(
                    title: "Tasks",
                    value: "$completedTasks / $totalTasks",
                    subtitle: "Completed",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    title: "Focus",
                    value: "$completedMinutes min",
                    subtitle: "Total focus",
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _Section(
            title: "Productivity",
            child: Row(
              children: [
                Expanded(
                  child: _StatBox(
                    title: "Sessions",
                    value: "$focusSessions",
                    subtitle: "Focus sessions",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    title: "Remaining",
                    value: "$remainingTasks",
                    subtitle: "Tasks left",
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
  icon: const Icon(Icons.auto_graph),
  label: const Text("Advanced Analytics"),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalyticsPlusScreen(token: widget.token),


      ),
    );
  },
),


          _Section(
            title: "Peak Focus Hours",
            child: peakHours.isEmpty
                ? const Text(
                    "Not enough data yet.\nComplete tasks to detect peak hours.",
                    style: TextStyle(color: Colors.black54),
                  )
                : Column(
                    children: peakHours.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PeakHourRow(
                          hour: e.key,
                          minutes: e.value,
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),

          _Section(
            title: "Insight",
            child: Text(
              _insightText(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _insightText() {
    if (completedTasks == 0) {
      return "Start completing tasks to unlock productivity insights.";
    }

    if (peakHours.isNotEmpty) {
      final h = peakHours.first.key;
      return "You are most productive around ${_formatHour(h)}. Try scheduling deep work at that time.";
    }

    return "Keep working consistently to discover your productivity patterns.";
  }

  String _formatHour(int h) {
    final dt = DateTime(2025, 1, 1, h);
    return DateFormat('HH:mm').format(dt);
  }
}

// --------------------------------------------------
// UI COMPONENTS
// --------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _StatBox({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _PeakHourRow extends StatelessWidget {
  final int hour;
  final int minutes;

  const _PeakHourRow({
    required this.hour,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "${_fmt(hour)} — $minutes min focus",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int h) {
    final dt = DateTime(2025, 1, 1, h);
    return DateFormat('HH:mm').format(dt);
  }
}
