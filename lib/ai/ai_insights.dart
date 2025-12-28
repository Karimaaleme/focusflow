import '../models/task.dart';
import '../models/user_profile.dart';

class AIInsight {
  final String text;
  final AIAction action;

  AIInsight({required this.text, required this.action});
}

enum AIAction {
  openPlanner,
  quickFocus,
  none,
}

class AIInsightsEngine {
  static AIInsight generate({
    required List<Task> tasks,
    required UserProfile? profile,
  }) {
    final remaining = tasks.where((t) => !t.isCompleted).toList();
    final completed = tasks.where((t) => t.isCompleted).toList();

    // ---- Rule 1: many unfinished tasks
    if (remaining.length >= 5) {
      return AIInsight(
        text:
            "You have ${remaining.length} unfinished tasks. Planning your day could reduce overload.",
        action: AIAction.openPlanner,
      );
    }

    // ---- Rule 2: postponed tasks (simple heuristic)
    final overdue = remaining
        .where((t) => t.dueDatetime != null && t.dueDatetime!.isBefore(DateTime.now()))
        .toList();

    if (overdue.isNotEmpty) {
      return AIInsight(
        text:
            "You postponed ${overdue.length} task(s). Want to catch up with a focus session?",
        action: AIAction.quickFocus,
      );
    }
    
    // ---- Rule 2.5: Any remaining tasks (Proactive Focus)
    if (remaining.isNotEmpty) {
       return AIInsight(
        text: "You have ${remaining.length} tasks to do. Ready to focus?",
        action: AIAction.quickFocus,
      );
    }

    // ---- Rule 3: productivity balance
    final doneMinutes =
        completed.fold<int>(0, (s, t) => s + t.estimatedMinutes);
    final todoMinutes =
        remaining.fold<int>(0, (s, t) => s + t.estimatedMinutes);

    if (todoMinutes > doneMinutes * 2 && todoMinutes > 120) {
      return AIInsight(
        text:
            "Your remaining workload is heavy today. Consider starting a focused session now.",
        action: AIAction.quickFocus,
      );
    }

    // ---- Rule 4: personalization by user type
    final userType = profile?.userType.toLowerCase() ?? "";
    if (userType.contains("student")) {
      return AIInsight(
        text:
            "Students often focus best in short sessions. Try a focused study block now.",
        action: AIAction.quickFocus,
      );
    }

    // ---- Default
    return AIInsight(
      text: "You're doing well. Keep the momentum going.",
      action: AIAction.none,
    );
  }
}
