import '../models/task.dart';
import '../models/user_profile.dart';
import '../l10n/app_localizations.dart';

class AIInsight {
  final String Function(AppLocalizations l) getText;
  final AIAction action;

  AIInsight({required this.getText, required this.action});
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
        getText: (l) => l.aiInsightManyTasks(remaining.length),
        action: AIAction.openPlanner,
      );
    }

    // ---- Rule 2: postponed tasks (simple heuristic)
    final overdue = remaining
        .where((t) => t.dueDatetime != null && t.dueDatetime!.isBefore(DateTime.now()))
        .toList();

    if (overdue.isNotEmpty) {
      return AIInsight(
        getText: (l) => l.aiInsightOverdue(overdue.length),
        action: AIAction.quickFocus,
      );
    }

    // ---- Rule 2.5: Any remaining tasks (Proactive Focus)
    if (remaining.isNotEmpty) {
      return AIInsight(
        getText: (l) => l.aiInsightRemaining(remaining.length),
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
        getText: (l) => l.aiInsightHeavyWorkload,
        action: AIAction.quickFocus,
      );
    }

    // ---- Rule 4: personalization by user type
    final userType = profile?.userType.toLowerCase() ?? "";
    if (userType.contains("student")) {
      return AIInsight(
        getText: (l) => l.aiInsightStudent,
        action: AIAction.quickFocus,
      );
    }

    // ---- Default
    return AIInsight(
      getText: (l) => l.aiInsightDoingWell,
      action: AIAction.none,
    );
  }
}
