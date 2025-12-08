// lib/screens/weekly_planner_screen.dart
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_service.dart';

class WeeklyPlannerScreen extends StatefulWidget {
  final String token;

  const WeeklyPlannerScreen({super.key, required this.token});

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  DateTime _weekStart = _mondayOfWeek(DateTime.now());
  bool _loading = true;
  String? _error;

  List<Task> _allTasks = [];
  Map<DateTime, List<Task>> _tasksByDay = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  static DateTime _mondayOfWeek(DateTime d) {
    final diff = d.weekday - DateTime.monday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _allTasks = await ApiService.getTasks(widget.token);
      _groupTasksByDay();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load tasks: $e";
        _loading = false;
      });
    }
  }

  void _groupTasksByDay() {
    _tasksByDay = {};
    final weekEnd = _weekStart.add(const Duration(days: 6));

    for (final task in _allTasks) {
      if (task.dueDatetime == null) {
        continue;
      }

      final day = _normalize(task.dueDatetime!);

      if (day.isBefore(_normalize(_weekStart)) ||
          day.isAfter(_normalize(weekEnd))) {
        continue;
      }

      _tasksByDay.putIfAbsent(day, () => []);
      _tasksByDay[day]!.add(task);
    }
  }

  List<Task> _tasksForDay(DateTime day) {
    final list = _tasksByDay[_normalize(day)] ?? [];
    list.sort((a, b) {
      final at = a.dueDatetime ?? day;
      final bt = b.dueDatetime ?? day;
      return at.compareTo(bt);
    });
    return list;
  }

  Future<void> _moveTaskToDay(Task task, DateTime targetDay) async {
    final oldDue = task.dueDatetime ?? DateTime.now();

    final newDue = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      oldDue.hour,
      oldDue.minute,
    );

    try {
      await ApiService.updateTaskDueDate(
        token: widget.token,
        id: task.id,
        dueDatetime: newDue,
      );

      final index = _allTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _allTasks[index] = Task(
          id: task.id,
          title: task.title,
          description: task.description,
          category: task.category,
          priority: task.priority,
          dueDatetime: newDue,
          isRecurring: task.isRecurring,
          recurrence: task.recurrence,
          isCompleted: task.isCompleted,
          orderIndex: task.orderIndex,
          status: task.status,
          createdAt: task.createdAt,
          estimatedMinutes: task.estimatedMinutes,
        );
      }

      _groupTasksByDay();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to move task: $e")),
      );
    }
  }

  void _changeWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: delta * 7));
    });
    _groupTasksByDay();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Weekly Planner")),
        body: Center(child: Text(_error!)),
      );
    }

    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Weekly Planner"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(1),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF6F5F2),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: days
                .map((day) => _buildDayColumn(day, _tasksForDay(day)))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDayColumn(DateTime day, List<Task> tasks) {
    final bool isToday = _normalize(day) == _normalize(DateTime.now());

    const labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final label = labels[day.weekday - 1];

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isToday ? Colors.white : const Color(0xFFFBFAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday ? Colors.greenAccent : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: DragTarget<Task>(
        onAcceptWithDetails: (details) => _moveTaskToDay(details.data, day),
        builder: (context, candidates, rejects) {
          final hovering = candidates.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$label ${day.day}/${day.month}",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isToday ? Colors.green[800] : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "${tasks.length} tasks",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hovering
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: hovering
                        ? Border.all(color: Colors.greenAccent, width: 1.2)
                        : null,
                  ),
                  child: tasks.isEmpty
                      ? const Center(
                          child: Text(
                            "Drop tasks here",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.black38,
                            ),
                          ),
                        )
                      : ListView(
                          children:
                              tasks.map((t) => _buildTaskBlock(t)).toList(),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskBlock(Task task) {
    final time = task.dueDatetime != null
        ? "${task.dueDatetime!.hour.toString().padLeft(2, '0')}:${task.dueDatetime!.minute.toString().padLeft(2, '0')}"
        : "Any time";

    Color priorityColor() {
      switch (task.priority.toLowerCase()) {
        case "high":
          return Colors.redAccent;
        case "low":
          return Colors.green;
        default:
          return Colors.orange;
      }
    }

    final color = priorityColor();

    return LongPressDraggable<Task>(
      data: task,
      feedback: SizedBox(
        width: 200,
        child: Opacity(
          opacity: 0.9,
          child: _taskBlockContent(task, color, time, dragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _taskBlockContent(task, color, time),
      ),
      child: _taskBlockContent(task, color, time),
    );
  }

  Widget _taskBlockContent(
    Task task,
    Color pColor,
    String time, {
    bool dragging = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
        border: Border.all(color: pColor.withValues(alpha: 0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: pColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (task.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
              Text(
                "${task.estimatedMinutes} min",
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
