// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/task.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../widgets/kanban_widgets.dart';
import '../widgets/category_management_sheet.dart';
import 'add_task_screen.dart';
import 'profile_screen.dart';
import '../models/user_profile.dart';
import 'ai_planner_screen.dart';
import 'analytics_screen.dart';

class TasksScreen extends StatefulWidget {
  final String email;
  final UserProfile? profile;

  const TasksScreen({
    super.key,
    required this.email,
    this.profile,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late Future<List<Task>> tasksFuture;
  UserProfile? loadedProfile;
  List<Task>? _currentTasks;

  // --- Category Logic ---
  List<Category> _categories = [];
  String? _selectedCategory; // Null = All

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadCategories();
    if (widget.profile != null) {
      loadedProfile = widget.profile;
    } else {
      _loadProfile();
    }
  }

  void _loadTasks() {
    setState(() {
      tasksFuture = ApiService.getTasks().then((tasks) {
        _currentTasks = tasks;
        return tasks;
      });
    });
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ApiService.loadProfile(widget.email);
      if (mounted) setState(() => loadedProfile = p);
    } catch (_) {}
  }

  Future<void> _updateTaskStatus(Task task, String newStatus) async {
    try {
      await ApiService.updateTaskStatus(id: task.id, status: newStatus);
      _loadTasks();
    } catch (e) {
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedMoveTask(e.toString()))),
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await ApiService.deleteTask(id: task.id);
      _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedDeleteTask(e.toString()))),
        );
      }
    }
  }

  Future<void> _goToAddTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(),
      ),
    );
    if (result == true) _loadTasks();
  }

  Future<void> _editTask(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          existingTask: task,
        ),
      ),
    );
    if (result == true) _loadTasks();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.getCategories();
    if (mounted) setState(() => _categories = cats);
  }

  void _openCategoryManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CategoryManagementSheet(),
    ).then((_) => _loadCategories());
  }

  List<Task> _filterTasks(List<Task> tasks) {
    if (_selectedCategory == null) return tasks;
    return tasks.where((t) => t.category == _selectedCategory).toList();
  }

  Widget _buildCategoryFilterList() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _buildFilterChip(
            label: AppLocalizations.of(context).filterAll,
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: cat.name,
                  isSelected: _selectedCategory == cat.name,
                  color: cat.color,
                  icon: cat.icon,
                  onTap: () => setState(() => _selectedCategory = cat.name),
                ),
              )),
          Container(
            width: 1,
            height: 20,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          GestureDetector(
            onTap: _openCategoryManager,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).manageLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
    IconData? icon,
  }) {
    final themeColor = color ?? Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: themeColor.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : themeColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddTask,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildAppBar(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildCategoryFilterList(),
          ),
          Expanded(
            child: FutureBuilder<List<Task>>(
              future: tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _currentTasks == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data ?? _currentTasks ?? [];
                final filtered = _filterTasks(tasks);

                final todoTasks = filtered.where((t) => t.status == 'todo').toList();
                final inProgressTasks = filtered.where((t) => t.status == 'in_progress').toList();
                final doneTasks = filtered.where((t) => t.status == 'done').toList();

                return RefreshIndicator(
                  onRefresh: () async => _loadTasks(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KanbanColumn(
                          title: AppLocalizations.of(context).toDo,
                          status: "todo",
                          count: todoTasks.length,
                          tasks: todoTasks,
                          onEdit: _editTask,
                          onDelete: _deleteTask,
                          onStatusChanged: _updateTaskStatus,
                        ),
                        KanbanColumn(
                          title: AppLocalizations.of(context).inProgress,
                          status: "in_progress",
                          count: inProgressTasks.length,
                          tasks: inProgressTasks,
                          onEdit: _editTask,
                          onDelete: _deleteTask,
                          onStatusChanged: _updateTaskStatus,
                        ),
                        KanbanColumn(
                          title: AppLocalizations.of(context).done,
                          status: "done",
                          count: doneTasks.length,
                          tasks: doneTasks,
                          onEdit: _editTask,
                          onDelete: _deleteTask,
                          onStatusChanged: _updateTaskStatus,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      color: Colors.white,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).myBoard,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).workspaceOf(loadedProfile?.userType ?? 'User'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          const LanguageToggleButton(),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: AppLocalizations.of(context).aiPlannerLabel,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AIPlannerScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: AppLocalizations.of(context).analytics,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AnalyticsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final updated = await Navigator.push<UserProfile?>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    profile: loadedProfile,
                    fallbackEmail: widget.email,
                  ),
                ),
              );
              if (updated != null && mounted) {
                setState(() => loadedProfile = updated);
              }
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
              backgroundImage: loadedProfile?.profileImageBytes != null
                  ? MemoryImage(loadedProfile!.profileImageBytes!)
                  : null,
              child: loadedProfile?.profileImageBytes == null
                  ? Text(widget.email.isNotEmpty ? widget.email[0].toUpperCase() : "?")
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
