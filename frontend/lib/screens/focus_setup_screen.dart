// lib/screens/focus_setup_screen.dart
import 'package:flutter/material.dart';

import '../models/ai_plan_item.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../widgets/gradient_header.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';
import 'focus_session_screen.dart';

class FocusSetupScreen extends StatefulWidget {
  final AIPlanItem? block;

  const FocusSetupScreen({
    super.key,
    this.block,
  });

  @override
  State<FocusSetupScreen> createState() => _FocusSetupScreenState();
}

class _FocusSetupScreenState extends State<FocusSetupScreen> {
  int selectedMinutes = 25;
  final List<int> presets = [15, 25, 45, 60];

  List<Task> _tasks = [];
  Task? _selectedTask;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final all = await ApiService.getTasks();
      // Filter for actionable tasks
      final actionable = all.where((t) => t.status != 'done').toList();
      
      setState(() {
        _tasks = actionable;

        // Try to find the passed block in the existing tasks
        if (widget.block?.taskId != null) {
          try {
            _selectedTask = actionable.firstWhere((t) => t.id == widget.block!.taskId);
          } catch (_) {}
        }
        
        // If not found (or no taskId), try to match by title loosely or just don't select one properly?
        // Actually, if we are setting up a focus session, we essentially WANT a task.
        // If _selectedTask is null, we can stick with the "block" info loosely, 
        // OR we can force user to pick if they want to track it properly.
        // For now, let's allow "Custom / Block" focus if no task selected, 
        // but if they pick a task, we switch to it.
      });
    } catch (_) {}
  }

  void _showTaskSelector() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                 Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    AppLocalizations.of(context).selectTaskToFocusOn,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final t = _tasks[i];
                      final isSelected = t.id == _selectedTask?.id;
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedTask = t);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? (theme.brightness == Brightness.dark ? theme.colorScheme.primary : Colors.black)
                                : theme.cardTheme.color ?? theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      AppLocalizations.of(context).focusedMinutesLabel(t.actualMinutes),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white.withOpacity(0.7) : Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Effective title
    final l = AppLocalizations.of(context);
    final displayTitle = _selectedTask?.title ?? widget.block?.title ?? l.quickSession;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            title: l.focusZone,
            subtitle: l.getInTheZone,
            action: const LanguageToggleButton(onGradient: true),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   GestureDetector(
                    onTap: _showTaskSelector,
                    child: _TaskCard(
                      title: displayTitle,
                      subtitle: _selectedTask != null ? l.tapToChangeTask : l.tapToSelectTask,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const SizedBox(height: 24),
                  // Time selection moved to next screen to avoid duplication
                  Text(
                    l.startSessionChooseDuration,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FocusSessionScreen(
                              block: AIPlanItem(
                                // Use selected task ID if available
                                taskId: _selectedTask?.id, 
                                title: displayTitle,
                                startTime: widget.block?.startTime ?? DateTime.now(),
                                endTime: widget.block?.endTime ?? DateTime.now(), // End time will be dynamic
                                estimatedMinutes: 25, // Default, user picks in next screen
                                reason: widget.block?.reason ?? "Quick Focus",
                              ),
                            ),
                          ),
                        );
                        if (mounted && result == true) {
                          Navigator.pop(context, true);
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        l.startFocusLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TaskCard({
    required this.title, 
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 12, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}
