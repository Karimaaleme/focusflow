// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../models/task.dart';
import 'add_task_screen.dart';
import 'profile_screen.dart';
import '../models/user_profile.dart';
import 'kanban_screen.dart';
import 'ai_planner_screen.dart';
import 'analytics_screen.dart';


enum TaskViewMode { all, today, week }

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
  UserProfile? loadedProfile;

  TaskViewMode _viewMode = TaskViewMode.all;

  @override
  void initState() {
    super.initState();

    tasksFuture = ApiService.getTasks(widget.token);

    if (widget.profile != null) {
      loadedProfile = widget.profile;
    } else {
      ApiService.loadProfile(widget.token, widget.email).then((profile) {
        if (!mounted) return;
        setState(() => loadedProfile = profile);
      }).catchError((_) {});
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
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(token: widget.token),
      ),
    );

    if (created == true) _reload();
  }

  Future<void> _editTask(Task task) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          token: widget.token,
          existingTask: task,
        ),
      ),
    );

    if (updated == true) _reload();
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.deleteTask(token: widget.token, id: task.id);
      _reload();
    }
  }

  Future<void> _toggleComplete(Task task) async {
    await ApiService.toggleTaskComplete(
      token: widget.token,
      id: task.id,
    );
    _reload();
  }

  String formatSmartDate(DateTime? date) {
    if (date == null) return 'No due date';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(date.year, date.month, date.day);
    final difference = taskDay.difference(today).inDays;
    final time = DateFormat('HH:mm').format(date);

    if (date.isBefore(now)) {
      return 'Overdue! (${DateFormat('dd MMM').format(date)} at $time)';
    }
    if (difference == 0) return 'Today at $time';
    if (difference == 1) return 'Tomorrow at $time';
    if (difference > 1 && difference <= 7) {
      return 'In $difference days at $time';
    }

    return '${DateFormat('dd MMM yyyy').format(date)} at $time';
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

  List<Task> _filterTasks(List<Task> tasks) {
    if (_viewMode == TaskViewMode.all) return tasks;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_viewMode == TaskViewMode.today) {
      return tasks.where((t) {
        if (t.dueDatetime == null) return false;
        final d = t.dueDatetime!;
        final day = DateTime(d.year, d.month, d.day);
        return day == today;
      }).toList();
    }

    final weekFromNow = today.add(const Duration(days: 7));
    return tasks.where((t) {
      if (t.dueDatetime == null) return false;
      final d = t.dueDatetime!;
      final day = DateTime(d.year, d.month, d.day);
      return day.isAfter(today.subtract(const Duration(days: 1))) &&
          day.isBefore(weekFromNow.add(const Duration(days: 1)));
    }).toList();
  }

  Widget _buildTaskCard(Task task) {
    final overdue =
        task.dueDatetime != null && task.dueDatetime!.isBefore(DateTime.now());

    return Card(
      key: ValueKey(task.id),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: Icon(
                task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
              ),
              color: task.isCompleted ? Colors.green : Colors.grey[500],
              onPressed: () => _toggleComplete(task),
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
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTask(task),
                      ),
                      const Icon(Icons.drag_handle),
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
                          labelStyle: const TextStyle(color: Colors.blue),
                        ),
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(task.priority),
                        backgroundColor:
                         _priorityColor(task.priority).withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: _priorityColor(task.priority),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Due: ${formatSmartDate(task.dueDatetime)}',
                    style: TextStyle(
                      color: overdue ? Colors.red : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeChips() {
    Chip chip(TaskViewMode mode, String label) {
      final selected = _viewMode == mode;
      return Chip(
        label: Text(label),
        backgroundColor: selected ? Colors.green[200] : Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.grey[800],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _viewMode = TaskViewMode.all),
            child: chip(TaskViewMode.all, 'All'),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _viewMode = TaskViewMode.today),
            child: chip(TaskViewMode.today, 'Today'),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _viewMode = TaskViewMode.week),
            child: chip(TaskViewMode.week, 'This Week'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Your Tasks'),
        centerTitle: true,
        elevation: 0,
        actions: [
  IconButton(
    icon: const Icon(Icons.auto_awesome),
    tooltip: "AI Daily Planner",
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AIPlannerScreen(token: widget.token),
        ),
      );
    },
  ),

  IconButton(
    icon: const Icon(Icons.insights),
    tooltip: "Analytics",
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalyticsScreen(token: widget.token),
        ),
      );
    },
  ),

  IconButton(
    icon: const Icon(Icons.view_kanban),
    tooltip: "Open Kanban Board",
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KanbanScreen(token: widget.token),
        ),
      );
    },
  ),

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
          setState(() => loadedProfile = updatedProfile);
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
      body: FutureBuilder<List<Task>>(
        future: tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'No tasks yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final filteredTasks = _filterTasks(tasks);

          return Column(
            children: [
              _buildViewModeChips(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: _viewMode == TaskViewMode.all
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: tasks.length,
                          onReorder: (oldIndex, newIndex) async {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = tasks.removeAt(oldIndex);
                              tasks.insert(newIndex, item);
                            });

                            final order = tasks.map((t) => t.id).toList();

                            await ApiService.saveTaskOrder(
                              token: widget.token,
                              order: order,
                            );
                          },
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return _buildTaskCard(task);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return _buildTaskCard(task);
                          },
                        ),
                ),
              ),
            ],
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
