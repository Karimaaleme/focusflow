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
  final DateTime createdAt;

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
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      priority: json['priority'] as String,
      dueDatetime: json['due_datetime'] != null
          ? DateTime.parse(json['due_datetime'])
          : null,
      isRecurring: json['is_recurring'] as bool,
      recurrence: json['recurrence'] as String?,
      isCompleted: json['is_completed'] as bool,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
