class SubTask {
  final String title;
  final bool isCompleted;

  SubTask({required this.title, required this.isCompleted});

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      title: json['title'] ?? '',
      isCompleted: json['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        "title": title,
        "is_completed": isCompleted,
      };
}

class Task {
  final int id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final DateTime? dueDatetime;
  final DateTime? reminderDateTime;
  final bool isRecurring;
  final String? recurrence; // "daily", "weekly", "monthly"
  final int? recurrenceInterval; // e.g. 2 for "every 2 weeks"
  // final bool isCompleted; // REPLACED BY GETTER
  final String status;
  final int orderIndex;
  final int estimatedMinutes;
  final int actualMinutes;
  final DateTime createdAt;
  final List<SubTask> subtasks;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.dueDatetime,
    this.reminderDateTime, // Optional
    required this.isRecurring,
    required this.recurrence,
    this.recurrenceInterval, // Optional
    required this.status,
    required this.orderIndex,
    required this.estimatedMinutes,
    required this.actualMinutes,
    required this.createdAt,
    required this.subtasks,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? due;
    final rawDue = json['due_datetime'];
    if (rawDue is String && rawDue.trim().isNotEmpty) {
      due = DateTime.tryParse(rawDue);
    }

    DateTime? reminder;
    final rawReminder = json['reminder_datetime'];
    if (rawReminder is String && rawReminder.trim().isNotEmpty) {
      reminder = DateTime.tryParse(rawReminder);
    }

    var subList = <SubTask>[];
    if (json['subtasks'] != null && json['subtasks'] is List) {
      subList = (json['subtasks'] as List)
          .map((e) => SubTask.fromJson(e))
          .toList();
    }

    // Prioritize status for completion source of truth
    final statusStr = (json['status'] ?? 'todo').toString();

    return Task(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 'medium',
      dueDatetime: due,
      reminderDateTime: reminder,
      isRecurring: json['is_recurring'] ?? false,
      recurrence: json['recurrence'],
      recurrenceInterval: json['recurrence_interval'],
      // Ignore backend boolean if status disagrees, or just rely on status
      status: statusStr,
      orderIndex: json['order_index'] ?? 0,
      estimatedMinutes: json['estimated_minutes'] ?? 30,
      actualMinutes: json['actual_minutes'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      subtasks: subList,
    );
  }

  // Derived property ensures consistency across UI
  bool get isCompleted => status == 'done';

  Map<String, dynamic> toCreateJson() {
    return {
      "title": title,
      "description": description,
      "category": category,
      "priority": priority,
      "due_datetime": dueDatetime?.toIso8601String(),
      "reminder_datetime": reminderDateTime?.toIso8601String(),
      "is_recurring": isRecurring,
      "recurrence": recurrence,
      "recurrence_interval": recurrenceInterval,
      "status": status,
      "estimated_minutes": estimatedMinutes,
      "actual_minutes": actualMinutes,
      "subtasks": subtasks.map((e) => e.toJson()).toList(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
     return {
      "title": title,
      "description": description,
      "category": category,
      "priority": priority,
      "due_datetime": dueDatetime?.toIso8601String(),
      "reminder_datetime": reminderDateTime?.toIso8601String(),
      "is_recurring": isRecurring,
      "recurrence": recurrence,
      "recurrence_interval": recurrenceInterval,
      "status": status,
      "estimated_minutes": estimatedMinutes,
      "actual_minutes": actualMinutes,
      "subtasks": subtasks.map((e) => e.toJson()).toList(),
    };
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? dueDatetime,
    DateTime? reminderDateTime,
    bool? isRecurring,
    String? recurrence,
    int? recurrenceInterval,
    String? status,
    int? orderIndex,
    int? estimatedMinutes,
    int? actualMinutes,
    DateTime? createdAt,
    List<SubTask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDatetime: dueDatetime ?? this.dueDatetime,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: recurrence ?? this.recurrence,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      status: status ?? this.status,
      orderIndex: orderIndex ?? this.orderIndex,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      createdAt: createdAt ?? this.createdAt,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}
