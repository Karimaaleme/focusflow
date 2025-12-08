// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/task.dart';

class AnalyticsScreen extends StatelessWidget {
  final String token;

  const AnalyticsScreen({super.key, required this.token});

  int _minutesForTasks(List<Task> tasks) {
    int total = 0;
    for (final t in tasks) {
      final est = t.estimatedMinutes ?? 30;
      total += est;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today’s Analytics"),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Task>>(
        future: ApiService.getTasks(token),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Failed to load stats: ${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(
              child: Text("No tasks yet to analyze."),
            );
          }

          final completed = tasks.where((t) => t.isCompleted).toList();
          final todo = tasks.where((t) => !t.isCompleted).toList();

          final todoMinutes = _minutesForTasks(todo);
          final doneMinutes = _minutesForTasks(completed);
          final totalMinutes = todoMinutes + doneMinutes;

          int countByPriority(String p) => tasks
              .where((t) => t.priority.toLowerCase() == p.toLowerCase())
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text(
                    "Tasks overview",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Total: ${tasks.length}\n"
                    "Completed: ${completed.length}\n"
                    "Remaining: ${todo.length}",
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text(
                    "Time (estimated)",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Total: $totalMinutes min\n"
                    "Completed: $doneMinutes min\n"
                    "Remaining: $todoMinutes min",
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text(
                    "By priority",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "High: ${countByPriority('high')}\n"
                    "Medium: ${countByPriority('medium')}\n"
                    "Low: ${countByPriority('low')}",
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
