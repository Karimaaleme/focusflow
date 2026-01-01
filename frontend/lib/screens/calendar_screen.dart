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

          // LIST HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  _selectedDay == null ? "Tasks" : "Tasks for ${_formatHeaderDate(_selectedDay!)}",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${tasksForDay.length}",
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
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
                      // Reusing KanbanTaskCard but disabling drag
                      return KanbanTaskCard(
                        task: task,
                        onEdit: () async {
                           final updated = await Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => AddTaskScreen(
                                 existingTask: task,
                               ),
                             ),
                           );
                           if (updated == true) {
                             loadTasks();
                           }
                        },
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
}
