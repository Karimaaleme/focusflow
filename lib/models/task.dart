// lib/models/task.dart
class Task {
  final int id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final DateTime? dueDatetime;
  final bool isRecurring;
  final String? recurrence;
  final bool isCompleted;
  final int orderIndex;
  final String status; // "todo" / "in_progress" / "done"
  final DateTime createdAt;

  // NEW: estimated minutes to complete this task
  final int estimatedMinutes;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.dueDatetime,
    required this.isRecurring,
    required this.recurrence,
    required this.isCompleted,
    required this.orderIndex,
    required this.status,
    required this.createdAt,
    required this.estimatedMinutes,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      description: (json['description'] ?? '') as String,
      category: (json['category'] ?? 'general') as String,
      priority: (json['priority'] ?? 'medium') as String,
      dueDatetime: json['due_datetime'] != null
          ? DateTime.parse(json['due_datetime'] as String)
          : null,
      isRecurring: (json['is_recurring'] as bool?) ?? false,
      recurrence: json['recurrence'] as String?,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      orderIndex: (json['order_index'] as int?) ?? 0,
      status: (json['status'] as String?) ?? "todo",
      createdAt: DateTime.parse(json['created_at'] as String),

      estimatedMinutes: (json['estimated_minutes'] as int?) ?? 30,
    );
  }
}
