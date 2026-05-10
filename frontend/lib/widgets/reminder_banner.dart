import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../l10n/app_localizations.dart';

class ReminderBanner extends StatelessWidget {
  final Task task;
  final Function(Task, Duration) onDelay;

  const ReminderBanner({required this.task, required this.onDelay});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dt = task.dueDatetime ?? DateTime.now();
    final timeStr = DateFormat('h:mm a').format(dt);
    final isOverdue = dt.isBefore(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.3) : Colors.purple.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red : Colors.purple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverdue ? l.overdueTask : l.upNext,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : Colors.purple,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isOverdue ? l.dueAt(timeStr) : l.dueTodayAt(timeStr),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Delay Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _delayButton(context, l.delay1h, const Duration(hours: 1)),
              const SizedBox(width: 8),
              _delayButton(context, l.delay1d, const Duration(days: 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _delayButton(BuildContext context, String label, Duration dur) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: () => onDelay(task, dur),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: Theme.of(context).dividerColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
