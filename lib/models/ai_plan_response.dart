// lib/models/ai_plan_response.dart
import 'ai_plan_item.dart';

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
    final list = json['items'] as List<dynamic>? ?? [];
    return AIPlanResponse(
      items: list
          .map((e) => AIPlanItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalMinutes: json['total_minutes'] as int? ?? 0,
      overloaded: json['overloaded'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}
