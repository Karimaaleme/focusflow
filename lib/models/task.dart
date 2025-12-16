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
  final String status;
  final int orderIndex;
  final int estimatedMinutes;
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
    required this.status,
    required this.orderIndex,
    required this.estimatedMinutes,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? due;
    final rawDue = json['due_datetime'];
    if (rawDue is String && rawDue.trim().isNotEmpty) {
      due = DateTime.tryParse(rawDue);
    }

    return Task(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 'medium',
      dueDatetime: due,
      isRecurring: json['is_recurring'] ?? false,
      recurrence: json['recurrence'],
      isCompleted: json['is_completed'] ?? false,
      status: (json['status'] ?? 'todo').toString(),
      orderIndex: json['order_index'] ?? 0,
      estimatedMinutes: json['estimated_minutes'] ?? 30,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      "title": title,
      "description": description,
      "category": category,
      "priority": priority,
      "due_datetime": dueDatetime?.toIso8601String(),
      "is_recurring": isRecurring,
      "recurrence": recurrence,
      "status": status,
      "estimated_minutes": estimatedMinutes,
    };
  }
}
