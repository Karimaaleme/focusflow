import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../models/task.dart';

class CalendarScreen extends StatefulWidget {
  final String token;

  const CalendarScreen({super.key, required this.token});

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
    loadTasks();
  }

  Future<void> loadTasks() async {
    final tasks = await ApiService.getTasks(widget.token);

    setState(() {
      allTasks = tasks;
      _groupTasksByDate(tasks);
      loading = false;
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Calendar"),
        backgroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // CALENDAR
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getTasksForDay,
            calendarStyle: const CalendarStyle(
              todayDecoration:
                  BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
          ),

          const SizedBox(height: 12),

          // TASK LIST BELOW CALENDAR
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text("Select a date"))
                : _getTasksForDay(_selectedDay!).isEmpty
                    ? const Center(child: Text("No tasks for this day"))
                    : ListView(
                        children: _getTasksForDay(_selectedDay!)
                            .map(
                              (task) => ListTile(
                                leading: const Icon(Icons.task_alt),
                                title: Text(task.title),
                                subtitle: Text(task.description),
                              ),
                            )
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
