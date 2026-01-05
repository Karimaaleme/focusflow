import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../models/task.dart';
import '../widgets/kanban_widgets.dart'; // Reused card
import 'add_task_screen.dart'; // Add import

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Task> allTasks = [];
  Map<DateTime, List<Task>> tasksByDate = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      final tasks = await ApiService.getTasks();
      if (mounted) {
        setState(() {
          allTasks = tasks;
          _groupTasksByDate(tasks);
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _groupTasksByDate(List<Task> tasks) {
    tasksByDate = {};

    for (var task in tasks) {
      if (task.dueDatetime == null) continue;

      final date = DateTime(
        task.dueDatetime!.year,
        task.dueDatetime!.month,
        task.dueDatetime!.day,
      );

      if (!tasksByDate.containsKey(date)) {
        tasksByDate[date] = [];
      }

      tasksByDate[date]!.add(task);
    }
  }

  List<Task> _getTasksForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return tasksByDate[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final tasksForDay = _selectedDay == null ? <Task>[] : _getTasksForDay(_selectedDay!);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Calendar", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: theme.iconTheme,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // CALENDAR CARD
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.only(bottom: 12),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getTasksForDay,
              
              // STYLES
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.bold) ?? const TextStyle(),
                leftChevronIcon: Icon(Icons.chevron_left, color: theme.colorScheme.primary),
                rightChevronIcon: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
                weekendTextStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey) ?? const TextStyle(),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.secondary, 
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                outsideDaysVisible: false,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                weekendStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;
                  
                  final tasks = events as List<Task>;
                  bool hasOverdue = false;
                  bool hasHighPriority = false;
                  
                  for (var t in tasks) {
                    if (t.dueDatetime != null && t.dueDatetime!.isBefore(DateTime.now()) && !t.isCompleted && !isSameDay(t.dueDatetime, DateTime.now())) {
                      hasOverdue = true;
                    }
                    if (t.priority.toLowerCase() == 'high' && !t.isCompleted) {
                      hasHighPriority = true;
                    }
                  }

                  // Max 2 dots
                  List<Color> dotColors = [];
                  if (hasOverdue) dotColors.add(Colors.red);
                  else if (hasHighPriority) dotColors.add(Colors.orange);
                  else dotColors.add(Colors.grey); // Default existence dot

                  // If we have space and strictly distinguishing
                  if (hasOverdue && hasHighPriority) {
                     // already added red, maybe add orange too?
                     dotColors.add(Colors.orange);
                  } else if (dotColors.length < 2 && tasks.length > 3) {
                     dotColors.add(Colors.grey.withOpacity(0.5));
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dotColors.map((c) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    )).toList(),
                  );
                },
              ),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused; 
                });
              },
              onPageChanged: (focused) {
                _focusedDay = focused;
              },
            ),
          ),

          // LIST HEADER & SUMMARY
          Padding(
             padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
             child: Column(
               children: [
                 Row(
                    children: [
                      Text(
                        _selectedDay == null ? "Tasks" : "Tasks for ${_formatHeaderDate(_selectedDay!)}",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Count Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${tasksForDay.length} Tasks",
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                 ),
                 if (tasksForDay.isNotEmpty) ...[
                   const SizedBox(height: 12),
                   _DailySummaryBanner(tasks: tasksForDay),
                 ]
               ],
             ),
          ),

          // TASK LIST
          Expanded(
            child: tasksForDay.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "No tasks for this day",
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tasksForDay.length,
                    itemBuilder: (context, index) {
                      final task = tasksForDay[index];
                      // Reusing KanbanTaskCard
                      return KanbanTaskCard(
                        task: task,
                        onEdit: () => _editTask(task),
                        onLongPress: () => _showCalendarQuickActions(task),
                        isDraggable: false,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatHeaderDate(DateTime date) {
    // Simple formatter to avoid intl dependency if not imported or reuse it
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[date.month - 1]} ${date.day}";
  }

  Future<void> _editTask(Task task) async {
    final updated = await Navigator.push(
       context,
       MaterialPageRoute(
         builder: (_) => AddTaskScreen(existingTask: task),
       ),
    );
    if (updated == true) loadTasks();
  }

  void _showCalendarQuickActions(Task task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           const SizedBox(height: 12),
           Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
           const SizedBox(height: 16),
           Text("Manage '${task.title}'", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
           const Divider(),
           ListTile(
             leading: const Icon(Icons.timer, color: Colors.blue),
             title: const Text("Start Focus Session"),
             onTap: () {
               Navigator.pop(ctx);
               // TODO: Navigate to Focus Session
             },
           ),
           ListTile(
             leading: const Icon(Icons.edit, color: Colors.black87),
             title: const Text("Edit Task"),
             onTap: () {
               Navigator.pop(ctx);
               _editTask(task);
             },
           ),
           ListTile(
             leading: const Icon(Icons.today, color: Colors.purple),
             title: const Text("Move to Another Day"),
             onTap: () async {
               Navigator.pop(ctx);
               final newDate = await showDatePicker(
                 context: context, 
                 initialDate: DateTime.now(), 
                 firstDate: DateTime.now().subtract(const Duration(days: 365)), 
                 lastDate: DateTime.now().add(const Duration(days: 365))
               );
               
               if (newDate != null) {
                  // Update task due date via API
                  try {
                    final updatedTask = task.copyWith(dueDatetime: newDate);
                    await ApiService.updateTask(
                      id: updatedTask.id,
                      title: updatedTask.title,
                      description: updatedTask.description,
                      priority: updatedTask.priority,
                      status: updatedTask.status,
                      category: updatedTask.category,
                      estimatedMinutes: updatedTask.estimatedMinutes,
                      actualMinutes: updatedTask.actualMinutes,
                      dueDatetime: updatedTask.dueDatetime,
                      subtasks: updatedTask.subtasks,
                    );
                    loadTasks();
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to move task")));
                  }
               }
             },
           ),
           if (!task.isCompleted)
           ListTile(
             leading: const Icon(Icons.check_circle_outline, color: Colors.green),
             title: const Text("Mark as Done"),
             onTap: () async {
               Navigator.pop(ctx);
               // Quick Update Status
                try {
                    final updatedTask = task.copyWith(status: 'done');
                    await ApiService.updateTask(
                      id: updatedTask.id,
                      title: updatedTask.title,
                      description: updatedTask.description,
                      priority: updatedTask.priority,
                      status: updatedTask.status,
                      category: updatedTask.category,
                      estimatedMinutes: updatedTask.estimatedMinutes,
                      actualMinutes: updatedTask.actualMinutes,
                      dueDatetime: updatedTask.dueDatetime,
                      subtasks: updatedTask.subtasks,
                    );
                    loadTasks();
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update task")));
                  }
             },
           ),
           const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DailySummaryBanner extends StatelessWidget {
  final List<Task> tasks;
  const _DailySummaryBanner({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final highPrio = tasks.where((t) => t.priority.toLowerCase() == 'high' && !t.isCompleted).length;
    final focusedMinutes = tasks.fold<int>(0, (sum, t) => sum + t.actualMinutes);
    final completed = tasks.where((t) => t.isCompleted).length;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: "High Priority", value: "$highPrio", icon: Icons.priority_high, color: Colors.orange),
          _Stat(label: "Focused", value: "${focusedMinutes}m", icon: Icons.timer, color: Colors.blue),
          _Stat(label: "Completed", value: "$completed/${tasks.length}", icon: Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  
  const _Stat({required this.label, required this.value, required this.icon, required this.color});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }
}
