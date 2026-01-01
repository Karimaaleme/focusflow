// lib/models/ai_plan_item.dart
import 'package:intl/intl.dart';

class AIPlanItem {
  final int? taskId;          // can be null for "breaks" or generic blocks
  final String title;
  final String reason;
  final DateTime startTime;
  final DateTime endTime;
  final int estimatedMinutes;

  AIPlanItem({
    this.taskId,
    required this.title,
    required this.reason,
    required this.startTime,
    required this.endTime,
    required this.estimatedMinutes,
  });

  factory AIPlanItem.fromJson(Map<String, dynamic> json) {
    // Backend is assumed to return ISO timestamps
    final start = DateTime.parse(json['start_time'] as String);
    final end = DateTime.parse(json['end_time'] as String);

    return AIPlanItem(
      taskId: json['task_id'] as int?,
      title: json['title'] as String? ?? 'Untitled block',
      reason: json['reason'] as String? ?? '',
      startTime: start,
      endTime: end,
      estimatedMinutes: json['estimated_minutes'] as int? ??
          end.difference(start).inMinutes,
    );
  }

  String get timeRangeLabel {
    final fmt = DateFormat('HH:mm');
    return '${fmt.format(startTime)} – ${fmt.format(endTime)}';
  }
}
