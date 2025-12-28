import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../models/task.dart';
import 'analytics_plus_screen.dart';

class AnalyticsScreen extends StatefulWidget {

  const AnalyticsScreen({super.key});

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

  // -------- FOCUS INFERENCE FROM TASKS & SESSIONS --------
  Future<void> _load() async {
    try {
      loading = true;
      error = null;
      setState(() {});

      tasks = await ApiService.getTasks();
      
      // Try to fetch real sessions, fallback to simulated
      List<Map<String, dynamic>> sessions = [];
      try {
        sessions = await ApiService.getFocusSessions();
      } catch (_) {
        sessions = [];
      }

      if (sessions.isNotEmpty) {
        _calcFocusFromSessions(sessions);
      } else {
         _simulateFocusFromTasks(tasks);
      }

      loading = false;
      setState(() {});
    } catch (e) {
      loading = false;
      error = e.toString();
      setState(() {});
    }
  }

  void _calcFocusFromSessions(List<Map<String, dynamic>> sessions) {
    focusByHour.clear();
    for (final s in sessions) {
      final mins = s['focused_minutes'] as int? ?? 0;
      final start = DateTime.parse(s['started_at']);
      final hour = start.hour;
      focusByHour[hour] = (focusByHour[hour] ?? 0) + mins;
    }
  }

  void _simulateFocusFromTasks(List<Task> tasks) {
    focusByHour.clear();
    for (final t in tasks) {
      // Use actual minutes if available, otherwise estimated for completed items
      final mins = (t.actualMinutes ?? 0);
      if (mins > 0) {
         final hour = t.createdAt.hour; // fallback time
         focusByHour[hour] = (focusByHour[hour] ?? 0) + mins;
      } else if (t.isCompleted) {
        final hour = t.createdAt.hour;
        focusByHour[hour] = (focusByHour[hour] ?? 0) + t.estimatedMinutes;
      }
    }
  }

  // -------- METRICS --------
  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  int get remainingTasks => totalTasks - completedTasks;

  int get completedMinutes {
    // Sum from the hourly map which is the source of truth now (either from sessions or tasks)
    return focusByHour.values.fold(0, (s, m) => s + m);
  }

  List<MapEntry<int, int>> get peakHours {
    final list = focusByHour.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list.take(3).toList();
  }

  // -------- ADVANCED METRICS --------

  // 3.3 Daily Load Analysis
  int get todayLoadMinutes {
    final now = DateTime.now();
    return tasks
        .where((t) =>
            !t.isCompleted &&
            (t.dueDatetime == null ||
                (t.dueDatetime!.year == now.year &&
                    t.dueDatetime!.month == now.month &&
                    t.dueDatetime!.day == now.day)))
        .fold(0, (sum, t) => sum + t.estimatedMinutes);
  }

  String get loadLabel {
    if (todayLoadMinutes < 120) return "Light"; // < 2 hours
    if (todayLoadMinutes < 300) return "Medium"; // < 5 hours
    return "High"; // > 5 hours
  }

  Color get loadColor {
    if (todayLoadMinutes < 120) return Colors.green;
    if (todayLoadMinutes < 300) return Colors.orange;
    return Colors.red;
  }

  // 3.8 Life Balance (Category Distribution)
  Map<String, int> get categoryCounts {
    final map = <String, int>{};
    for (final t in tasks) {
      final c = t.category.toLowerCase();
      map[c] = (map[c] ?? 0) + 1;
    }
    return map;
  }

  // 3.13 Category Performance (Completion Rate)
  Map<String, double> get categoryCompletionRates {
    final total = <String, int>{};
    final done = <String, int>{};
    
    for (final t in tasks) {
      final c = t.category.toLowerCase();
      total[c] = (total[c] ?? 0) + 1;
      if (t.isCompleted) {
        done[c] = (done[c] ?? 0) + 1;
      }
    }

    final rates = <String, double>{};
    total.forEach((k, v) {
      rates[k] = (done[k] ?? 0) / v;
    });
    return rates;
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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Your Analytics"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. OVERVIEW CARDS
          _section(context, "Overview", Row(
            children: [
              _stat(context, "Tasks", "$completedTasks / $totalTasks", "Completed"),
              const SizedBox(width: 12),
              _stat(context, "Focus", "$completedMinutes min", "Total time"),
            ],
          )),
          const SizedBox(height: 16),
          
          // 3.3 DAILY LOAD ANALYSIS
          _section(context, "Today's Load", Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: loadColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.speed, color: loadColor, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loadLabel.toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: loadColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${(todayLoadMinutes / 60).toStringAsFixed(1)}h estimated remaining",
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),

          // 3.8 LIFE BALANCE ANALYZER
          _section(context, "Life Balance", Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                // Visual Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: categoryCounts.entries.map((e) {
                        final color = _getCategoryColor(e.key);
                        final flex = e.value;
                        return Expanded(flex: flex, child: Container(color: color));
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Legend
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: categoryCounts.entries.map((e) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _getCategoryColor(e.key), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${e.key[0].toUpperCase()}${e.key.substring(1)} (${e.value})",
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    );
                  }).toList(),
                )
              ],
            ),
          )),
          const SizedBox(height: 16),

          // 3.5 FOCUS TREND (Simulated for this milestone as standard bar chart)
          _section(context, "Focus Trend (Last 7 Days)", Container(
             height: 180,
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: theme.cardTheme.color ?? theme.cardColor,
               borderRadius: BorderRadius.circular(18),
             ),
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.end,
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: List.generate(7, (index) {
                  // Mock data for visual structure logic.
                  // Real implementation would group sessions by day.
                  final dayParams = [30, 60, 45, 90, 20, 120, completedMinutes > 0 ? completedMinutes : 45]; 
                  final val = dayParams[index % dayParams.length];
                  final max = 150;
                  final h = (val / max) * 120;
                  
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                       Container(
                         width: 12,
                         height: h.toDouble(),
                         decoration: BoxDecoration(
                           color: index == 6 ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.3),
                           borderRadius: BorderRadius.circular(4),
                         ),
                       ),
                       const SizedBox(height: 8),
                       Text(
                         DateFormat('E').format(DateTime.now().subtract(Duration(days: 6 - index))),
                         style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                       ),
                    ],
                  );
               }),
             ),
          )),
          const SizedBox(height: 16),


          // 3.13 CATEGORY PERFORMANCE
          _section(context, "Category Performance", Column(
            children: categoryCompletionRates.entries.map((e) {
               return Container(
                 margin: const EdgeInsets.only(bottom: 8),
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 decoration: BoxDecoration(
                   color: theme.cardTheme.color ?? theme.cardColor,
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Row(
                   children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(e.key).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.category, size: 16, color: _getCategoryColor(e.key)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                               "${e.key[0].toUpperCase()}${e.key.substring(1)}",
                               style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                             ),
                             const SizedBox(height: 4),
                             ClipRRect(
                               borderRadius: BorderRadius.circular(2),
                               child: LinearProgressIndicator(
                                 value: e.value,
                                 backgroundColor: theme.dividerColor,
                                 color: _getCategoryColor(e.key),
                                 minHeight: 4,
                               ),
                             ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "${(e.value * 100).toInt()}%",
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                   ],
                 ),
               );
            }).toList(),
          )),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            icon: const Icon(Icons.auto_graph),
            label: const Text("Advanced Analytics (Coming Soon)"),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AnalyticsPlusScreen(),
                ),
              );
            },
          ),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // -------- HELPERS --------
  Widget _section(BuildContext context, String title, Widget child) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 12, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface.withOpacity(0.6))),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _stat(BuildContext context, String title, String value, String subtitle) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(value,
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String c) {
    switch (c.toLowerCase()) {
      case 'work': return Colors.blue;
      case 'personal': return Colors.green;
      case 'study': return Colors.purple;
      case 'health': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _fmt(int h) =>
      DateFormat('HH:mm').format(DateTime(2025, 1, 1, h));
}
