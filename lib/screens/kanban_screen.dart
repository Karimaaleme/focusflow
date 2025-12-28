import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import 'add_task_screen.dart';
import '../widgets/kanban_widgets.dart'; // Import reusable widgets

class KanbanScreen extends StatefulWidget {
  final UserProfile? profile;

  const KanbanScreen({
    super.key,
    this.profile,
  });

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  bool loading = true;
  String? errorMessage;

  List<Task> allTasks = [];
  List<Task> todo = [];
  List<Task> inProgress = [];
  List<Task> done = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      if (!mounted) return;
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final tasks = await ApiService.getTasks();

      if (!mounted) return;
      setState(() {
        allTasks = tasks;
        todo = tasks.where((t) => t.status == "todo").toList();
        inProgress = tasks.where((t) => t.status == "in_progress").toList();
        done = tasks.where((t) => t.status == "done").toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Unable to load tasks";
        loading = false;
      });
    }
  }

  // ---------------- personalization ----------------
  String _boardTitle() {
    final t = (widget.profile?.userType ?? "").toLowerCase();
    if (t.contains("student")) return "Study Board";
    if (t.contains("employee")) return "Work Board";
    if (t.contains("freelancer")) return "Projects Board";
    return "Kanban Board";
  }

  // ---------------- actions ----------------
  Future<void> _updateTaskStatus(Task task, String newStatus) async {
    // 1. Optimistic UI Update
    final oldStatus = task.status;
    if (oldStatus == newStatus) return;

    final updatedTask = task.copyWith(status: newStatus);

    setState(() {
      // Remove from old list
      if (oldStatus == 'todo') todo.removeWhere((t) => t.id == task.id);
      else if (oldStatus == 'in_progress') inProgress.removeWhere((t) => t.id == task.id);
      else if (oldStatus == 'done') done.removeWhere((t) => t.id == task.id);

      // Add to new list
      if (newStatus == 'todo') todo.add(updatedTask);
      else if (newStatus == 'in_progress') inProgress.add(updatedTask);
      else if (newStatus == 'done') done.add(updatedTask);
    });

    try {
      // 2. Call API
      await ApiService.updateTask(
        id: updatedTask.id,
        title: updatedTask.title,
        description: updatedTask.description,
        priority: updatedTask.priority,
        status: updatedTask.status,
        category: updatedTask.category, // ADDED
        estimatedMinutes: updatedTask.estimatedMinutes,
        actualMinutes: updatedTask.actualMinutes,
        dueDatetime: updatedTask.dueDatetime,
        subtasks: updatedTask.subtasks,
      );

      // 3. Verified Reload (ensure backend has processed)
      // await Future.delayed(const Duration(milliseconds: 200)); 
      if (mounted) await _loadTasks();
      
    } catch (e) {
      debugPrint("Update failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Failed to save status")),
        );
        // Revert on error
        _loadTasks();
      }
    }
  }

  Future<void> _editTask(Task task) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          existingTask: task,
        ),
      ),
    );
    if (updated == true) _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Task"),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context, false),
             child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.deleteTask(id: task.id);
      await _loadTasks();
    }
  }

  Future<void> _createQuickTask(String status) async {
    // Reusing the AddTaskScreen logic might be better, or a simple dialog
    final result = await showDialog<bool>(
        context: context, 
        builder: (_) => _QuickAddDialog(initialStatus: status)
    );
    
    if (result == true) {
      // Actually creating inside dialog returns values ideally, 
      // but let's assume dialog handled API or returns data to call API.
      // Simpler: Just open AddTaskScreen with pre-filled status? 
      // But AddTaskScreen might not support passing status in constructor (checked earlier, it accepts existingTask).
      // Let's implement the simple dialog logic here properly or just call API.
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F6F4),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F6F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F6F4), 
          elevation: 0,
          leading: const BackButton(color: Colors.black),
        ),
        body: Center(child: Text(errorMessage!)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F4),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _boardTitle(),
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddTaskScreen()),
            );
            if (result == true) _loadTasks();
        }, // Global add
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KanbanColumn(
              title: "To Do",
              status: "todo",
              tasks: todo,
              count: todo.length,
              onEdit: _editTask,
              onDelete: _deleteTask,
              onStatusChanged: _updateTaskStatus,
            ),
            KanbanColumn(
              title: "In Progress",
              status: "in_progress",
              tasks: inProgress,
              count: inProgress.length,
              onEdit: _editTask,
              onDelete: _deleteTask,
              onStatusChanged: _updateTaskStatus,
            ),
            KanbanColumn(
              title: "Done",
              status: "done",
              tasks: done,
              count: done.length,
              onEdit: _editTask,
              onDelete: _deleteTask,
              onStatusChanged: _updateTaskStatus,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddDialog extends StatefulWidget {
  final String initialStatus;
  const _QuickAddDialog({required this.initialStatus});

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
    // ... ignoring implementation for now to prefer generic AddTaskScreen 
    // to ensure all fields are handled. Will remove usage above.
    @override
    Widget build(BuildContext context) {
        return const SizedBox(); 
    }
}
