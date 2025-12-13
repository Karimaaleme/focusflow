// lib/screens/kanban_screen.dart
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import 'add_task_screen.dart';

class KanbanScreen extends StatefulWidget {
  final String token;

  /// Optional for personalization
  final UserProfile? profile;

  const KanbanScreen({
    super.key,
    required this.token,
    this.profile,
  });

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  bool loading = true;
  String? errorMessage;

  List<Task> todo = [];
  List<Task> inProgress = [];
  List<Task> done = [];

  int? _draggingTaskId;

  // hover highlight per column
  String? _hoverStatus;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
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

  // ---------------- personalization ----------------
  String _boardTitle() {
    final t = (widget.profile?.userType ?? "").toLowerCase();
    if (t.contains("student")) return "Study Board";
    if (t.contains("employee")) return "Work Board";
    if (t.contains("freelancer")) return "Projects Board";
    return "Kanban Board";
  }

  // ---------------- helpers ----------------
  List<Task> _listForStatus(String status) {
    if (status == "todo") return todo;
    if (status == "in_progress") return inProgress;
    return done;
  }

  int _minutesSum(List<Task> tasks) {
    var sum = 0;
    for (final t in tasks) {
      sum += t.estimatedMinutes;
    }
    return sum;
  }

  Color _priorityColor(Task task) {
    switch (task.priority.toLowerCase()) {
      case "high":
        return Colors.redAccent;
      case "low":
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  _ColumnTheme _themeFor(String status) {
    switch (status) {
      case "todo":
        return const _ColumnTheme(
          title: "To-Do",
          accent: Color(0xFF3B82F6), // blue
          tint: Color(0xFFEFF6FF),
          icon: Icons.playlist_add_check,
        );
      case "in_progress":
        return const _ColumnTheme(
          title: "In Progress",
          accent: Color(0xFFF59E0B), // amber
          tint: Color(0xFFFFFBEB),
          icon: Icons.timelapse,
        );
      case "done":
      default:
        return const _ColumnTheme(
          title: "Done",
          accent: Color(0xFF22C55E), // green
          tint: Color(0xFFF0FDF4),
          icon: Icons.verified,
        );
    }
  }

  // ---------------- CRUD ----------------
  Future<void> _editTask(Task task) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          token: widget.token,
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
      await ApiService.deleteTask(token: widget.token, id: task.id);
      _loadTasks();
    }
  }

  Future<void> _createQuickTask(String status) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final minutesCtrl = TextEditingController(text: "30");
    String priority = "medium";

    final ok = await showDialog<bool>(
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
              controller: minutesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Estimated minutes"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: priority,
              items: const [
                DropdownMenuItem(value: "low", child: Text("Low")),
                DropdownMenuItem(value: "medium", child: Text("Medium")),
                DropdownMenuItem(value: "high", child: Text("High")),
              ],
              onChanged: (v) => priority = v ?? "medium",
              decoration: const InputDecoration(labelText: "Priority"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (ok == true) {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;

      final mins = int.tryParse(minutesCtrl.text.trim()) ?? 30;

      await ApiService.createTask(
        token: widget.token,
        title: title,
        description: descCtrl.text.trim(),
        category: "general",
        priority: priority,
        status: status,
        estimatedMinutes: mins,
      );

      _loadTasks();
    }
  }

  // ---------------- Drag between columns ----------------
  Future<void> _moveToStatus(Task task, String newStatus) async {
    if (task.status == newStatus) return;

    await ApiService.updateTaskStatus(
      token: widget.token,
      id: task.id,
      status: newStatus,
    );

    // Nice UX: if moved to done, also mark complete
    if (newStatus == "done" && !task.isCompleted) {
      await ApiService.toggleTaskComplete(token: widget.token, id: task.id);
    }

    await _loadTasks();
  }

  // ---------------- Reorder inside a column ----------------
  Future<void> _reorderWithin(String status, int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final list = _listForStatus(status);
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });

    final merged = [...todo, ...inProgress, ...done];
    final order = merged.map((t) => t.id).toList();

    try {
      await ApiService.saveTaskOrder(token: widget.token, order: order);
    } catch (_) {
      await _loadTasks();
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
          centerTitle: true,
          title: Text(_boardTitle()),
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
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),

      // OPTIONAL global add (creates todo task)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createQuickTask("todo"),
        child: const Icon(Icons.add),
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          // if small width -> horizontal scroll like pro kanban
          final isNarrow = constraints.maxWidth < 900;

          final content = Row(
            children: [
              _buildColumn(status: "todo"),
              _buildColumn(status: "in_progress"),
              _buildColumn(status: "done"),
            ],
          );

          if (!isNarrow) return content;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 900),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Widget _buildColumn({required String status}) {
    final theme = _themeFor(status);
    final tasks = _listForStatus(status);

    final count = tasks.length;
    final minutes = _minutesSum(tasks);

    final isHover = _hoverStatus == status;

    return Expanded(
      child: DragTarget<Task>(
        onWillAcceptWithDetails: (_) {
          setState(() => _hoverStatus = status);
          return true;
        },
        onLeave: (_) => setState(() {
          if (_hoverStatus == status) _hoverStatus = null;
        }),
        onAcceptWithDetails: (details) async {
          setState(() => _hoverStatus = null);
          await _moveToStatus(details.data, status);
        },
        builder: (context, candidateData, rejectedData) {
          final hovering = candidateData.isNotEmpty || isHover;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: EdgeInsets.fromLTRB(
              status == "todo" ? 12 : 6,
              12,
              status == "done" ? 12 : 6,
              12,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hovering
                    ? theme.accent.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.06),
                width: hovering ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: hovering ? 0.07 : 0.04),
                  blurRadius: hovering ? 22 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // top colored bar
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 4,
                    width: 46,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Header row
                Row(
                  children: [
                    Icon(theme.icon, size: 18, color: Colors.black87),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        theme.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _Pill(text: "$count", bg: Colors.black.withValues(alpha: 0.06)),
                    const SizedBox(width: 6),
                    _Pill(text: "${minutes}m", bg: Colors.black.withValues(alpha: 0.06)),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: "Add task",
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => _createQuickTask(status),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: tasks.isEmpty
                      ? _EmptyDropHint(accent: theme.accent)
                      : ReorderableListView.builder(
                          key: PageStorageKey<String>("kanban_$status"),
                          buildDefaultDragHandles: false,
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: tasks.length,
                          onReorder: (oldIndex, newIndex) =>
                              _reorderWithin(status, oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            final task = tasks[index];

                            return _NotionTaskCard(
                              key: ValueKey("task_${task.id}_$status"),
                              index: index,
                              task: task,
                              accent: _priorityColor(task),
                              dragging: _draggingTaskId == task.id,
                              onEdit: () => _editTask(task),
                              onDelete: () => _deleteTask(task),
                              onDragStarted: () => setState(() => _draggingTaskId = task.id),
                              onDragEnd: () => setState(() => _draggingTaskId = null),
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
}

// ------------------------
// UI components
// ------------------------

class _ColumnTheme {
  final String title;
  final Color accent;
  final Color tint;
  final IconData icon;

  const _ColumnTheme({
    required this.title,
    required this.accent,
    required this.tint,
    required this.icon,
  });
}

class _EmptyDropHint extends StatelessWidget {
  final Color accent;

  const _EmptyDropHint({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Text(
          "Drop tasks here",
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;

  const _Pill({required this.text, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _NotionTaskCard extends StatelessWidget {
  final int index;
  final Task task;
  final Color accent;
  final bool dragging;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  const _NotionTaskCard({
    super.key,
    required this.index,
    required this.task,
    required this.accent,
    required this.dragging,
    required this.onEdit,
    required this.onDelete,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    // WOW: scale + shadow lift while dragging
    return LongPressDraggable<Task>(
      data: task,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: AnimatedScale(
            scale: 1.03,
            duration: const Duration(milliseconds: 120),
            child: Opacity(
              opacity: 0.95,
              child: _card(context, elevated: true),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: _card(context)),
      child: AnimatedScale(
        scale: dragging ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: _card(context),
      ),
    );
  }

  Widget _card(BuildContext context, {bool elevated = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.14 : 0.06),
            blurRadius: elevated ? 26 : 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + actions + reorder handle
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 14.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onEdit,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete, size: 18),
                onPressed: onDelete,
              ),
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),

          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.25,
                color: Colors.black.withValues(alpha: 0.62),
              ),
            ),
          ],

          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (task.category.isNotEmpty)
                _Tag(
                  text: task.category,
                  bg: Colors.blue.withValues(alpha: 0.08),
                  fg: Colors.blue,
                ),
              _Tag(
                text: task.priority.toUpperCase(),
                bg: accent.withValues(alpha: 0.14),
                fg: accent,
              ),
              _Tag(
                text: "${task.estimatedMinutes}m",
                bg: Colors.black.withValues(alpha: 0.05),
                fg: Colors.black87,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Tag({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
