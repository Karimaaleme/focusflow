import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/task.dart';
import 'add_task_screen.dart';
import 'profile_screen.dart';
import '../models/user_profile.dart';

class TasksScreen extends StatefulWidget {
  final String token;
  final String email;
  final UserProfile? profile;

  const TasksScreen({
    super.key,
    required this.token,
    required this.email,
    this.profile,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late Future<List<Task>> tasksFuture;

  @override
  void initState() {
    super.initState();
    tasksFuture = ApiService.getTasks(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      tasksFuture = ApiService.getTasks(widget.token);
    });
  }

  Future<void> _goToAddTask() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(token: widget.token),
      ),
    );

    if (created == true) {
      await _reload();
    }
  }

  Future<void> _editTask(Task task) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTaskScreen(token: widget.token, existingTask: task),
      ),
    );

    if (updated == true) {
      await _reload();
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.deleteTask(token: widget.token, id: task.id);
      await _reload();
    }
  }

  String formatSmartDate(DateTime? date) {
    if (date == null) return "No due date";

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(date.year, date.month, date.day);

    final difference = taskDay.difference(today).inDays;
    final timeFormat = DateFormat('HH:mm');

    if (date.isBefore(now)) {
      return "Overdue! (${DateFormat('dd MMM').format(date)} at ${timeFormat.format(date)})";
    }

    if (difference == 0) {
      return "Today at ${timeFormat.format(date)}";
    }

    if (difference == 1) {
      return "Tomorrow at ${timeFormat.format(date)}";
    }

    if (difference > 1 && difference <= 7) {
      return "In $difference days at ${timeFormat.format(date)}";
    }

    return "${DateFormat('dd MMM yyyy').format(date)} at ${timeFormat.format(date)}";
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Your Tasks"),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      profile: widget.profile,
                      fallbackEmail: widget.email,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueGrey[200],
                child: Text(
                  widget.email.isNotEmpty ? widget.email[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      body: FutureBuilder<List<Task>>(
        future: tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                "No tasks yet.\nTap the + button to add one.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isOverdue =
                    task.dueDatetime != null &&
                    task.dueDatetime!.isBefore(DateTime.now());

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // status icon
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, right: 8),
                          child: Icon(
                            task.isCompleted
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: task.isCompleted
                                ? Colors.green
                                : Colors.grey[500],
                          ),
                        ),
                        // main content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🔹 title + edit/delete row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _editTask(task),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => _deleteTask(task),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // description
                              if (task.description.isNotEmpty)
                                Text(
                                  task.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              // chips row
                              Row(
                                children: [
                                  // category chip
                                  if (task.category.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        task.category,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  // priority dot
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _priorityColor(
                                        task.priority,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: _priorityColor(task.priority),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          task.priority,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _priorityColor(
                                              task.priority,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // due date line
                              Text(
                                'Due: ${formatSmartDate(task.dueDatetime)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOverdue
                                      ? Colors.red
                                      : Colors.grey[800],
                                  fontWeight: isOverdue
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}
