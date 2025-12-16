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
  final Map<int, int> focusByHour = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      loading = true;
      error = null;
      setState(() {});

      tasks = await ApiService.getTasks(widget.token);
      _simulateFocusFromTasks(tasks);

      loading = false;
      setState(() {});
    } catch (e) {
      loading = false;
      error = e.toString();
      setState(() {});
    }
  }

  // -------- FOCUS INFERENCE FROM TASKS --------
  void _simulateFocusFromTasks(List<Task> tasks) {
    focusByHour.clear();
    for (final t in tasks.where((t) => t.isCompleted)) {
      final hour = t.createdAt.hour;
      focusByHour[hour] = (focusByHour[hour] ?? 0) + t.estimatedMinutes;
    }
  }

  // -------- METRICS --------
  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  int get remainingTasks => totalTasks - completedTasks;

  int get completedMinutes =>
      tasks.where((t) => t.isCompleted).fold(0, (s, t) => s + t.estimatedMinutes);

  List<MapEntry<int, int>> get peakHours {
    final list = focusByHour.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list.take(3).toList();
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          _section("Overview", Row(
            children: [
              _stat("Tasks", "$completedTasks / $totalTasks", "Completed"),
              const SizedBox(width: 12),
              _stat("Focus", "$completedMinutes min", "Estimated focus"),
            ],
          )),

          const SizedBox(height: 16),

          _section("Productivity", Row(
            children: [
              _stat("Sessions", "$completedTasks", "Completed tasks"),
              const SizedBox(width: 12),
              _stat("Remaining", "$remainingTasks", "Tasks left"),
            ],
          )),

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

          const SizedBox(height: 16),

          _section(
            "Peak Focus Hours",
            peakHours.isEmpty
                ? const Text("Not enough data yet.")
                : Column(
                    children: peakHours.map((e) {
                      return _peakRow(e.key, e.value);
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),

          _section(
            "Insight",
            Text(
              completedTasks == 0
                  ? "Start completing tasks to unlock insights."
                  : "You focus best around ${_fmt(peakHours.first.key)}.",
            ),
          ),
        ],
      ),
    );
  }

  // -------- SMALL UI HELPERS --------
  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _stat(String title, String value, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _peakRow(int hour, int minutes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 18),
          const SizedBox(width: 8),
          Text("${_fmt(hour)} — $minutes min"),
        ],
      ),
    );
  }

  String _fmt(int h) =>
      DateFormat('HH:mm').format(DateTime(2025, 1, 1, h));
}
