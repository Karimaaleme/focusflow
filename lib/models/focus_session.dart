class FocusSession {
  final int? taskId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int focusedMinutes;

  FocusSession({
    required this.taskId,
    required this.startedAt,
    required this.endedAt,
    required this.focusedMinutes,
  });

  Map<String, dynamic> toJson() => {
        "task_id": taskId,
        "started_at": startedAt.toIso8601String(),
        "ended_at": endedAt.toIso8601String(),
        "focused_minutes": focusedMinutes,
      };
}
