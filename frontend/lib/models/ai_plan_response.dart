// lib/models/ai_plan_response.dart
class AIPlanResponse {
  final List<AIPlanItem> items;
  final int totalMinutes;
  final bool overloaded;
  final String message;

  AIPlanResponse({
    required this.items,
    required this.totalMinutes,
    required this.overloaded,
    required this.message,
  });

  factory AIPlanResponse.fromJson(Map<String, dynamic> json) {
    return AIPlanResponse(
      items: (json['items'] as List)
          .map((e) => AIPlanItem.fromJson(e))
          .toList(),
      totalMinutes: json['total_minutes'] ?? 0,
      overloaded: json['overloaded'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class AIPlanItem {
  final int taskId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final int estimatedMinutes;
  final String reason;
  final String priority;

  AIPlanItem({
    required this.taskId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.estimatedMinutes,
    required this.reason,
    required this.priority,
  });

  factory AIPlanItem.fromJson(Map<String, dynamic> json) {
    return AIPlanItem(
      taskId: json['task_id'],
      title: json['title'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      estimatedMinutes: json['estimated_minutes'],
      reason: json['reason'],
      priority: json['priority'],
    );
  }
}
