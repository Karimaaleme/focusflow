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

  /// Local profile we keep updated
  UserProfile? loadedProfile;

  @override
  void initState() {
    super.initState();

    tasksFuture = ApiService.getTasks(widget.token);

    // If profile already exists (from onboarding), use it.
    if (widget.profile != null) {
      loadedProfile = widget.profile;
    } else {
      // Otherwise, load it from backend
      ApiService.loadProfile(widget.token, widget.email)
          .then((profile) {
            setState(() => loadedProfile = profile);
          })
          .catchError((_) {
            // User might not have a profile yet — ignore error
          });
    }
  }

  Future<void> _reload() async {
    setState(() {
      tasksFuture = ApiService.getTasks(widget.token);
    });
  }

  Future<void> _goToAddTask() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTaskScreen(token: widget.token)),
    );

    if (created == true) {
      _reload();
    }
  }

  Future<void> _editTask(Task task) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(token: widget.token, existingTask: task),
      ),
    );

    if (updated == true) {
      _reload();
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
      _reload();
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
    if (difference == 0) return "Today at ${timeFormat.format(date)}";
    if (difference == 1) return "Tomorrow at ${timeFormat.format(date)}";
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
              onTap: () async {
                final updatedProfile = await Navigator.push<UserProfile?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      profile: loadedProfile,
                      fallbackEmail: widget.email,
                      token: widget.token,
                    ),
                  ),
                );

                if (updatedProfile != null) {
                  setState(() {
                    loadedProfile = updatedProfile; // ✔ UPDATE UI
                  });
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueGrey[200],
                backgroundImage: loadedProfile?.profileImageBytes != null
                    ? MemoryImage(loadedProfile!.profileImageBytes!)
                    : null,
                child: loadedProfile?.profileImageBytes == null
                    ? Text(
                        widget.email[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),

      // --- TASK LIST (unchanged) ---
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
                        Icon(
                          task.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: task.isCompleted
                              ? Colors.green
                              : Colors.grey[500],
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editTask(task),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => _deleteTask(task),
                                  ),
                                ],
                              ),

                              if (task.description.isNotEmpty)
                                Text(
                                  task.description,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),

                              const SizedBox(height: 6),

                              Row(
                                children: [
                                  if (task.category.isNotEmpty)
                                    Chip(
                                      label: Text(task.category),
                                      backgroundColor: Colors.blue[50],
                                      labelStyle: const TextStyle(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  Chip(
                                    label: Text(task.priority),
                                    backgroundColor: _priorityColor(
                                      task.priority,
                                    ).withOpacity(0.1),
                                    labelStyle: TextStyle(
                                      color: _priorityColor(task.priority),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              Text(
                                "Due: ${formatSmartDate(task.dueDatetime)}",
                                style: TextStyle(
                                  color: isOverdue
                                      ? Colors.red
                                      : Colors.black87,
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
