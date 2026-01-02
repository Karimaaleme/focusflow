// lib/models/ai_plan_response.dart

class WorkloadAnalysis {
  final String status;
  final String summary;
  final String recommendation;

  WorkloadAnalysis({
    required this.status,
    required this.summary,
    required this.recommendation,
  });

  factory WorkloadAnalysis.fromJson(Map<String, dynamic> json) {
    return WorkloadAnalysis(
      status: json['status'] ?? 'balanced',
      summary: json['summary'] ?? '',
      recommendation: json['recommendation'] ?? '',
    );
  }
}

class AIPlanResponse {
  final List<AIPlanItem> items;
  final int totalMinutes;
  final bool overloaded;
  final String message;
  final WorkloadAnalysis? workload;

  AIPlanResponse({
    required this.items,
    required this.totalMinutes,
    required this.overloaded,
    required this.message,
    this.workload,
  });

  factory AIPlanResponse.fromJson(Map<String, dynamic> json) {
    return AIPlanResponse(
      items: (json['items'] as List?)
          ?.map((e) => AIPlanItem.fromJson(e))
          .toList() ?? [],
      totalMinutes: json['total_minutes'] ?? 0,
      overloaded: json['overloaded'] ?? false,
      message: json['message'] ?? '',
      workload: json['workload'] != null 
          ? WorkloadAnalysis.fromJson(json['workload'])
          : null,
    );
  }
}

class AIPlanItem {
  final int? taskId;
  final String title;
  final DateTime startTime; // Time as DateTime (today + time)
  final String startTimeStr; // Keep original formatting if needed
  final DateTime endTime;
  final int estimatedMinutes;
  final String reason;
  final String? priority;

  AIPlanItem({
    this.taskId,
    required this.title,
    required this.startTime,
    required this.startTimeStr,
    required this.endTime,
    required this.estimatedMinutes,
    required this.reason,
    this.priority,
  });

  factory AIPlanItem.fromJson(Map<String, dynamic> json) {
    // If backend returns full ISO string, DateTime.parse works.
    // If backend returns HH:MM, we need the manual split.
    DateTime parseTime(String t) {
      if (t.contains("T")) {
        return DateTime.parse(t);
      }
      // Fallback for HH:MM
      final now = DateTime.now();
      final parts = t.split(":");
      return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    }

    return AIPlanItem(
      taskId: json['task_id'],
      title: json['title'],
      startTime: parseTime(json['start_time']),
      startTimeStr: json['start_time'], 
      endTime: parseTime(json['end_time']),
      estimatedMinutes: json['estimated_minutes'],
      reason: json['reason'],
      priority: json['priority'],
    );
  }
}
