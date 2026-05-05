import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../l10n/app_localizations.dart';
import '../l10n/task_l10n.dart';

// ---------------------------------------------------------------------------
// 1. KANBAN COLUMN
// ---------------------------------------------------------------------------
class KanbanColumn extends StatelessWidget {
  final String title;
  final String status;
  final List<Task> tasks;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final Function(Task, String) onStatusChanged;
  final Function(Task)? onLongPress;
  final int count;

  const KanbanColumn({
    super.key,
    required this.title,
    required this.status,
    required this.tasks,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    this.onLongPress,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    Color headerColor;
    IconData headerIcon;

    switch (status) {
      case 'todo':
        headerColor = Colors.blue;
        headerIcon = Icons.circle_outlined;
        break;
      case 'in_progress':
        headerColor = Colors.orange;
        headerIcon = Icons.timelapse;
        break;
      case 'done':
        headerColor = Colors.green;
        headerIcon = Icons.check_circle_outline;
        break;
      default:
        headerColor = Colors.grey;
        headerIcon = Icons.list;
    }

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(headerIcon, size: 18, color: headerColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<Task>(
              onWillAccept: (task) => task != null && task.status != status,
              onAccept: (task) {
                onStatusChanged(task, status);
              },
              builder: (context, candidateData, rejectedData) {
                if (candidateData.isNotEmpty) {
                  return Container(
                    color: headerColor.withOpacity(0.05),
                    child: _buildList(),
                  );
                }
                return _buildList();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return KanbanTaskCard(
          task: task,
          onEdit: () => onEdit(task),
          onDelete: () => onDelete(task),
          onLongPress: onLongPress != null ? () => onLongPress!(task) : null,
          isDraggable: true,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 2. KANBAN TASK CARD (Redesigned)
// ---------------------------------------------------------------------------
class KanbanTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool isDraggable;

  const KanbanTaskCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    this.onLongPress,
    this.isDraggable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDraggable) {
      return _CardContent(task: task, onEdit: onEdit, onDelete: onDelete);
    }
    return Draggable<Task>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 280,
          child: _CardContent(task: task, isDragging: true, onDelete: onDelete),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _CardContent(task: task, onDelete: onDelete),
      ),
      child: _CardContent(task: task, onEdit: onEdit, onDelete: onDelete),
    );
  }
}

class _CardContent extends StatelessWidget {
  final Task task;
  final bool isDragging;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  const _CardContent({
    required this.task,
    this.isDragging = false,
    this.onEdit,
    required this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final hasSubtasks = task.subtasks != null && task.subtasks!.isNotEmpty;

    return GestureDetector(
      onTap: isDragging ? null : onEdit,
      onLongPress: isDragging ? null : onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDragging
              ? [const BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)]
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDragging ? null : onEdit,
              onLongPress: isDragging ? null : onLongPress,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Tags Row
                    Row(
                      children: [
                        if (task.category.isNotEmpty)
                          _CategoryBadge(category: task.category),
                        const Spacer(),
                        _PriorityIndicator(priority: task.priority),
                        if (task.dueDatetime != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _getDeadlineDotColor(task.dueDatetime),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 2. Title
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    // 3. Subtask List
                    if (hasSubtasks) ...[
                      const SizedBox(height: 12),
                      ...task.subtasks!.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              s.isCompleted ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                              size: 14,
                              color: s.isCompleted ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  decoration: s.isCompleted ? TextDecoration.lineThrough : null,
                                  color: s.isCompleted ? Colors.grey : theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                    const SizedBox(height: 12),
                    // 4. Footer Row
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(task.dueDatetime, l),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: _isOverdue(task.dueDatetime) ? FontWeight.bold : FontWeight.w500,
                            color: _getDateColor(task.dueDatetime),
                          ),
                        ),
                        if (task.isRecurring) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.repeat, size: 13, color: Colors.orange),
                        ],
                        if (task.reminderDateTime != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.notifications_active, size: 13, color: Colors.purple),
                        ],
                        const Spacer(),
                        if (task.actualMinutes > 0) ...[
                          Icon(Icons.hourglass_bottom, size: 12, color: theme.colorScheme.primary.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            "${task.actualMinutes}${l.minsAbbr}",
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.primary.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
                            onPressed: onDelete,
                            tooltip: l.deleteTask,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isOverdue(DateTime? dt) {
    if (dt == null) return false;
    return dt.isBefore(DateTime.now()) && dt.day != DateTime.now().day;
  }

  Color _getDateColor(DateTime? dt) {
    if (dt == null) return Colors.grey;
    if (_isOverdue(dt)) return Colors.red;
    final diff = dt.difference(DateTime.now()).inHours;
    if (diff > -24 && diff < 48) return Colors.orange;
    return Colors.grey[600]!;
  }

  Color? _getDeadlineDotColor(DateTime? dt) {
    if (dt == null) return null;
    if (_isOverdue(dt)) return Colors.red;
    final diff = dt.difference(DateTime.now()).inHours;
    if (diff > -24 && diff < 48) return Colors.orange;
    return Colors.green;
  }

  String _formatDate(DateTime? dt, AppLocalizations l) {
    if (dt == null) return l.noDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return l.todayLabel;
    if (diff == 1) return l.tomorrowLabel;
    if (diff == -1) return l.yesterdayLabel;

    final locale = l.isHebrew ? 'he_IL' : 'en_US';
    return DateFormat("MMM d", locale).format(dt);
  }
}

// ---------------------------------------------------------------------------
// 3. KANBAN CONTROL BAR
// ---------------------------------------------------------------------------
class KanbanControlBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onClearFilters;
  final bool hasActiveFilters;
  final int activeFilterCount;
  final String sortBy;
  final ValueChanged<String?> onSortChanged;

  const KanbanControlBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onClearFilters,
    required this.hasActiveFilters,
    required this.activeFilterCount,
    required this.sortBy,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFFF6F6F4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l.searchTasks,
                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: sortBy,
                    icon: const Icon(Icons.sort, size: 18),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    onChanged: onSortChanged,
                    items: [
                      DropdownMenuItem(value: 'priority', child: Text(l.sortPriority)),
                      DropdownMenuItem(value: 'due_date', child: Text(l.sortDueDate)),
                      DropdownMenuItem(value: 'created', child: Text(l.sortCreated)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ActionChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasActiveFilters ? Icons.filter_list_alt : Icons.filter_list,
                      size: 16,
                      color: hasActiveFilters ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasActiveFilters ? l.filterActiveCount(activeFilterCount) : l.filter,
                      style: TextStyle(
                        color: hasActiveFilters ? Colors.white : Colors.black87,
                        fontWeight: hasActiveFilters ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                backgroundColor: hasActiveFilters ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                onPressed: onFilterTap,
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onClearFilters,
                  child: Text(l.clearLabel, style: const TextStyle(color: Colors.red)),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. KANBAN FILTER BOTTOM SHEET
// ---------------------------------------------------------------------------
class KanbanFilterBottomSheet extends StatefulWidget {
  final Set<String> selectedCategories;
  final String priorityFilter;
  final String dueFilter;
  final Function(Set<String>, String, String) onApply;

  const KanbanFilterBottomSheet({
    super.key,
    required this.selectedCategories,
    required this.priorityFilter,
    required this.dueFilter,
    required this.onApply,
  });

  @override
  State<KanbanFilterBottomSheet> createState() => _KanbanFilterBottomSheetState();
}

class _KanbanFilterBottomSheetState extends State<KanbanFilterBottomSheet> {
  late Set<String> _cats;
  late String _prio;
  late String _due;

  @override
  void initState() {
    super.initState();
    _cats = Set.from(widget.selectedCategories);
    _prio = widget.priorityFilter;
    _due = widget.dueFilter;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final catKeys = ["Work", "Study", "Personal", "Health", "Finance", "General"];
    final prioOptions = [
      ['', l.filterAll],
      ['high', l.priorityHigh],
      ['medium', l.priorityMedium],
      ['low', l.priorityLow],
    ];
    final dueOptions = [
      ['', l.filterAll],
      ['Today', l.dueTodayOption],
      ['This Week', l.dueThisWeekOption],
      ['Overdue', l.dueOverdueOption],
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.filterTasksTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),

          _Section(l.categoryFilterLabel),
          Wrap(
            spacing: 8,
            children: catKeys.map((c) {
              final isSelected = _cats.contains(c);
              return FilterChip(
                label: Text(TaskL10n.category(c, l)),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) _cats.add(c); else _cats.remove(c);
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          _Section(l.priorityFilterLabel),
          Wrap(
            spacing: 8,
            children: prioOptions.map((opt) {
              final value = opt[0];
              final display = opt[1];
              final isSelected = value == _prio;
              return ChoiceChip(
                label: Text(display),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _prio = value);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          _Section(l.dueDateFilterLabel),
          Wrap(
            spacing: 8,
            children: dueOptions.map((opt) {
              final value = opt[0];
              final display = opt[1];
              final isSelected = value == _due;
              return ChoiceChip(
                label: Text(display),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _due = value);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_cats, _prio, _due);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l.applyFilters),
            ),
          ),
        ],
      ),
    );
  }

  Widget _Section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
  );
}

// ---------------------------------------------------------------------------
// 5. HELPER WIDGETS
// ---------------------------------------------------------------------------

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBgColor(category),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        TaskL10n.category(category, l).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getCxColor(category),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getBgColor(String c) {
    final s = c.toLowerCase();
    if (s == 'work') return Colors.blue.withOpacity(0.1);
    if (s == 'personal') return Colors.green.withOpacity(0.1);
    if (s == 'study') return Colors.purple.withOpacity(0.1);
    return Colors.grey.withOpacity(0.1);
  }

  Color _getCxColor(String c) {
    final s = c.toLowerCase();
    if (s == 'work') return Colors.blue[700]!;
    if (s == 'personal') return Colors.green[700]!;
    if (s == 'study') return Colors.purple[700]!;
    return Colors.grey[700]!;
  }
}

class _PriorityIndicator extends StatelessWidget {
  final String priority;
  const _PriorityIndicator({required this.priority});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = priority.toLowerCase();
    Color color;
    String label;

    if (p == 'high') {
      color = Colors.red;
      label = l.priorityHighAbbr;
    } else if (p == 'medium') {
      color = Colors.orange;
      label = l.priorityMedAbbr;
    } else {
      color = Colors.green;
      label = l.priorityLowAbbr;
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
