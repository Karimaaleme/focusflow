// lib/screens/ai_planner_screen.dart
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/ai_plan_response.dart';
import '../models/ai_plan_item.dart';
import '../models/task.dart';
import 'focus_session_screen.dart';

class AIPlannerScreen extends StatefulWidget {
  final String token;

  const AIPlannerScreen({super.key, required this.token});

  @override
  State<AIPlannerScreen> createState() => _AIPlannerScreenState();
}

class _AIPlannerScreenState extends State<AIPlannerScreen> {
  late Future<AIPlanResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getAIPlan(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      _future = ApiService.getAIPlan(widget.token);
    });
  }

  Future<void> _markDone(AIPlanItem item) async {
    if (item.taskId == null) return;
    try {
      await ApiService.updateTaskStatus(
        token: widget.token,
        id: item.taskId!,
        status: 'done',
      );
      await ApiService.toggleTaskComplete(
        token: widget.token,
        id: item.taskId!,
      );
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark done: $e")),
      );
    }
  }

  Future<void> _skipToTomorrow(AIPlanItem item) async {
    if (item.taskId == null) return;
    try {
      final tomorrow =
          DateTime.now().add(const Duration(days: 1)); // simple strategy
      await ApiService.updateTaskDueDate(
        token: widget.token,
        id: item.taskId!,
        dueDatetime: tomorrow,
      );
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to move task: $e")),
      );
    }
  }

  Future<void> _openFocusSession(AIPlanItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusSessionScreen(block: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Daily Planner"),
        centerTitle: true,
      ),
      body: FutureBuilder<AIPlanResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Failed to load tasks: ${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          final plan = snapshot.data!;
          final items = plan.items;

          if (items.isEmpty) {
            return const Center(
              child: Text(
                "No tasks to plan for today.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  color: plan.overloaded
                      ? Colors.red[50]
                      : Colors.blueGrey[50],
                  child: Column(
                    children: [
                      Text(
                        plan.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: plan.overloaded
                              ? Colors.red[800]
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Planned time: ${plan.totalMinutes} min",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildPlanCard(item);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(AIPlanItem item) {
    return GestureDetector(
      onTap: () => _openFocusSession(item),
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // title + actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (item.taskId != null) ...[
                    IconButton(
                      tooltip: "Mark done",
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                      ),
                      onPressed: () => _markDone(item),
                    ),
                    IconButton(
                      tooltip: "Skip to tomorrow",
                      icon: const Icon(
                        Icons.skip_next,
                        size: 20,
                      ),
                      onPressed: () => _skipToTomorrow(item),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.timeRangeLabel,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.reason,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "${item.estimatedMinutes} minutes",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
