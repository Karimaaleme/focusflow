// lib/screens/kanban_screen.dart
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import 'add_task_screen.dart';

class KanbanScreen extends StatefulWidget {
  final String token;

  const KanbanScreen({super.key, required this.token});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  List<Task> todo = [];
  List<Task> inProgress = [];
  List<Task> done = [];

  bool loading = true;
  String? errorMessage;
  int? _hoveredTask;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final tasks = await ApiService.getTasks(widget.token);

      setState(() {
        todo = tasks.where((t) => t.status == "todo").toList();
        inProgress = tasks.where((t) => t.status == "in_progress").toList();
        done = tasks.where((t) => t.status == "done").toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Unable to load tasks";
        loading = false;
      });
    }
  }

  Future<void> changeStatus(Task task, String newStatus) async {
    await ApiService.updateTaskStatus(
      token: widget.token,
      id: task.id,
      status: newStatus,
    );
    await loadTasks();
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

    if (updated == true) loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Task"),
        content: Text("Are you sure you want to delete \"${task.title}\"?"),
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
      await ApiService.deleteTask(token: widget.token, id: task.id);
      loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F7F3),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F7F3),
        body: Center(child: Text(errorMessage!)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F3),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Kanban Board",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Row(
        children: [
          buildColumn("To-Do", todo, "todo"),
          buildColumn("In Progress", inProgress, "in_progress"),
          buildColumn("Done", done, "done"),
        ],
      ),
    );
  }

  // ---------- COLUMN ----------
  Widget buildColumn(String title, List<Task> tasks, String status) {
    return Expanded(
      child: DragTarget<Task>(
        onAcceptWithDetails: (details) async {
          await changeStatus(details.data, status);
        },
        builder: (context, candidateData, rejectedData) {
          final hovering = candidateData.isNotEmpty;

          return Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: hovering
                  ? Border.all(color: Colors.greenAccent, width: 1.4)
                  : null,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black,
                      child: Text(
                        "${tasks.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showAddTaskDialog(status),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: tasks.isEmpty
                      ? const Center(
                          child: Text(
                            "No tasks",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.black45,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return Draggable<Task>(
                              data: task,
                              feedback: SizedBox(
                                width: 260,
                                child: Opacity(
                                  opacity: 0.9,
                                  child: taskCard(task, dragging: true),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.25,
                                child: taskCard(task),
                              ),
                              child: taskCard(task),
                            );
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

  // ---------- TASK CARD ----------
  Widget taskCard(Task task, {bool dragging = false}) {
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

    final pColor = priorityColor();

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTask = task.id),
      onExit: (_) => setState(() => _hoveredTask = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: dragging || _hoveredTask == task.id
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
          border: Border.all(color: pColor.withValues(alpha: 0.6), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + actions
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: pColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editTask(task),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => _deleteTask(task),
                ),
              ],
            ),

            if (task.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  task.description,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ),

            const SizedBox(height: 6),

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (task.category.isNotEmpty)
                  Chip(
                    label: Text(task.category),
                    backgroundColor: Colors.blue[50],
                    labelStyle: const TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  ),
                Chip(
                  label: Text(
                    task.priority,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: pColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: pColor,
                    fontSize: 11,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                ),
                Chip(
                  label: Text("${task.estimatedMinutes} min"),
                  backgroundColor: Colors.grey[100],
                  labelStyle: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- ADD TASK POPUP ----------
  void _showAddTaskDialog(String status) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final estimatedCtrl = TextEditingController(text: "30");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Task"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            TextField(
              controller: estimatedCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Estimated minutes"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              final minutes = int.tryParse(estimatedCtrl.text.trim()) ?? 30;

              await ApiService.createTask(
                token: widget.token,
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                category: "general",
                priority: "medium",
                status: status,
                estimatedMinutes: minutes,
              );
              if (!mounted) return;
              Navigator.pop(context);
              loadTasks();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}
