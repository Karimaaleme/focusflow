import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/ai_plan_response.dart';
import 'package:intl/intl.dart';
import '../widgets/gradient_header.dart';
import '../widgets/language_toggle_button.dart';
import 'add_task_screen.dart';
import '../models/task.dart';
import '../l10n/app_localizations.dart';

class AIPlannerScreen extends StatefulWidget {

  const AIPlannerScreen({super.key});

  @override
  State<AIPlannerScreen> createState() => _AIPlannerScreenState();
}

class _AIPlannerScreenState extends State<AIPlannerScreen> {
  TimeOfDay _dayStart = const TimeOfDay(hour: 9, minute: 0);
  int _plannedMinutes = 240; 
  bool _syncGoogle = true;
  bool _syncOutlook = false;

  AIPlanResponse? _currentPlan;
  List<AIPlanItem> _planItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generate(); // Load initially
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _dayStart,
    );
    if (t != null && mounted) {
      setState(() => _dayStart = t);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _currentPlan = null;
    });

    try {
      final plan = await ApiService.getAIPlan(
        dayStart: _dayStart,
        plannedMinutes: _plannedMinutes,
        categories: _selectedCategories.isNotEmpty ? _selectedCategories : null,
        enableGoogle: _syncGoogle,
        enableOutlook: _syncOutlook,
      );
      if (mounted) {
        setState(() {
          _currentPlan = plan;
          _planItems = List<AIPlanItem>.from(plan.items);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context).failedToGenerate}: $e")),
        );
      }
    }
  }

  String _fmtTimeOfDay(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _acceptPlan() async {
    if (_planItems.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Use the new API to apply the plan (syncs to DB)
      await ApiService.applyPlan(_planItems);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Show success and actions
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).planSyncedSuccessfully, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context).planSyncedDesc, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                
                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx); // Close sheet
                      Navigator.pop(context); // Close planner
                      // TODO: Navigate to Home/Focus?
                    }, 
                    icon: const Icon(Icons.calendar_today),
                    label: Text(AppLocalizations.of(context).viewInTaskList),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                if (_planItems.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                         Navigator.pop(ctx);
                         // Find first task
                         final firstItem = _planItems.first;
                         if (firstItem.taskId != null) {
                           // Navigate to focus session?! 
                           // For now just pop back with result
                           Navigator.pop(context, firstItem.taskId);
                         } else {
                           Navigator.pop(context);
                         }
                      },
                      icon: const Icon(Icons.timer),
                      label: Text(AppLocalizations.of(context).startFirstTask(_planItems.first.title)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context).failedToApplyPlan}: $e")),
        );
      }
    }
  }

  // Common categories (could be fetched, but hardcoded for now)
  final List<String> _allCategories = ["Work", "Personal", "Health", "Study", "Finance", "General"];
  List<String> _selectedCategories = [];

  Widget _categorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _allCategories.map((cat) {
          final isSelected = _selectedCategories.contains(cat);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedCategories.add(cat);
                  } else {
                    _selectedCategories.remove(cat);
                  }
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _planItems.isNotEmpty && !_isLoading
        ? FloatingActionButton.extended(
            onPressed: _acceptPlan,
            icon: const Icon(Icons.check),
            label: Text(AppLocalizations.of(context).acceptPlan),
            backgroundColor: theme.colorScheme.primary,
          )
        : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
           return [
             SliverGradientHeader(
               title: AppLocalizations.of(context).smartPlanner,
               subtitle: AppLocalizations.of(context).aiPowered,
               action: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    const LanguageToggleButton(onGradient: true),
                    IconButton(
                      tooltip: AppLocalizations.of(context).calendarSyncSettings,
                      icon: const Icon(Icons.sync, color: Colors.white),
                      onPressed: () => _showSyncSettings(context),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).regenerate,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _generate,
                    ),
                 ],
               ),
             ),
           ];
        },
        body: Column(
        children: [
          // Controls bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                       Expanded(
                        child: InkWell(
                          onTap: _pickStartTime,
                          child: _controlTile(
                            title: AppLocalizations.of(context).startTimeLabel,
                            value: _fmtTimeOfDay(_dayStart),
                            icon: Icons.access_time,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _minutesDropdown(),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary, // Dynamic button color
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _generate,
                        child: Text(AppLocalizations.of(context).generate, style: TextStyle(color: theme.colorScheme.onPrimary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(AppLocalizations.of(context).focusCategoriesLabel, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                _categorySelector(),
              ],
            ),
          ),


          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final plan = _currentPlan;
                if (plan == null) {
                  return Center(child: Text(AppLocalizations.of(context).readyToGenerate));
                }

                // Use _planItems which is mutable
                final items = _planItems;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 80), // extra padding for FAB
                  children: [
                    // WORKLOAD ANALYSIS BANNER
                    if (plan.workload != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.1),
                              theme.colorScheme.primary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.analytics, color: theme.colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context).workloadStatus(plan.workload!.status),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(plan.workload!.summary, style: theme.textTheme.bodyMedium),
                            if (plan.workload!.recommendation.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context).tipLabel(plan.workload!.recommendation),
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),

                    // SUMMARY
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(context).aiScheduleReady,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(AppLocalizations.of(context).plannedTimeLabel(plan.totalMinutes)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Center(child: Text(AppLocalizations.of(context).noItemsReturned)),
                      )
                    else
                      ...items.asMap().entries.map((entry) {
                         final index = entry.key;
                         final it = entry.value;
                         return Dismissible(
                           key: ValueKey("${it.taskId}_${it.startTimeStr}_$index"),
                           background: Container(
                             color: Colors.redAccent,
                             alignment: Alignment.centerRight,
                             padding: const EdgeInsets.only(right: 20),
                             child: const Icon(Icons.delete, color: Colors.white),
                           ),
                           direction: DismissDirection.endToStart,
                           onDismissed: (direction) {
                             setState(() {
                               _planItems.removeAt(index);
                             });
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text(AppLocalizations.of(context).removedFromPlan(it.title))),
                             );
                           },
                           child: _PlanCard(
                             item: it, 
                             onDelete: it.taskId == null ? () {
                               setState(() {
                                 _planItems.removeAt(index);
                               });
                             } : null,
                             onAccept: it.taskId == null ? () async {
                                final titleClean = it.title.replaceAll(RegExp(r"\[.*?\]\s*"), "");
                                var cat = "general";
                                final match = RegExp(r"\[(.*?)\]").firstMatch(it.title);
                                if (match != null) cat = match.group(1) ?? "general";

                                final t = Task(
                                  id: 0, 
                                  title: titleClean,
                                  description: it.reason,
                                  category: cat,
                                  priority: it.priority ?? "medium",
                                  status: "todo",
                                  estimatedMinutes: it.estimatedMinutes,
                                  actualMinutes: 0,
                                  isRecurring: false,
                                  recurrence: null,
                                  recurrenceInterval: 1,
                                  orderIndex: 0,
                                  subtasks: [],
                                  dueDatetime: it.startTime,
                                  createdAt: DateTime.now(), 
                                );
                                
                                final res = await Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (_) => AddTaskScreen(template: t))
                                );
                                
                                if (res == true) {
                                  setState(() {
                                    _planItems.removeAt(index);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppLocalizations.of(context).taskAcceptedAdded)),
                                  );
                                }
                             } : null,
                           ),
                         );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _minutesDropdown() {
    final theme = Theme.of(context);
    final options = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _plannedMinutes,
          isExpanded: true,
          dropdownColor: theme.cardTheme.color ?? theme.cardColor,
          items: options
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(AppLocalizations.of(context).durationMinutes(m), style: theme.textTheme.bodyMedium),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _plannedMinutes = v);
          },
        ),
      ),
    );
  }

  Widget _controlTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.iconTheme.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6))),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  void _showSyncSettings(BuildContext context) {
      showDialog(
        context: context, 
        builder: (ctx) {
           return StatefulBuilder(
             builder: (context, setStateDialog) {
               return AlertDialog(
                 title: Text(AppLocalizations.of(context).calendarIntegration),
                 content: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      SwitchListTile(
                        title: Text(AppLocalizations.of(context).googleCalendar),
                        subtitle: Text(AppLocalizations.of(context).syncFromGoogle),
                        value: _syncGoogle,
                        secondary: const Icon(Icons.calendar_month, color: Colors.blue),
                        onChanged: (v) {
                            setStateDialog(() => _syncGoogle = v);
                            setState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: Text(AppLocalizations.of(context).outlookCalendar),
                        subtitle: Text(AppLocalizations.of(context).syncFromOutlook),
                        value: _syncOutlook,
                        secondary: const Icon(Icons.mail, color: Colors.blueAccent),
                        onChanged: (v) {
                             setStateDialog(() => _syncOutlook = v);
                             setState(() {});
                        },
                      ),
                   ],
                 ),
                 actions: [
                   ElevatedButton(
                     onPressed: () {
                       Navigator.pop(ctx);
                       _generate();
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).settingsSavedRegenerating)));
                     },
                     child: Text(AppLocalizations.of(context).saveAndRegenerate)
                   )
                 ],
               );
             }
           );
        }
      );
  }
}

class _PlanCard extends StatelessWidget {
  final AIPlanItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onAccept; // NEW

  const _PlanCard({required this.item, this.onDelete, this.onAccept});

  @override
  Widget build(BuildContext context) {
    // Assumes AIPlanItem has: title, startTime, endTime, minutes, note/reason, maybe due
    final title = item.title;
    
    final fmt = DateFormat("h:mm a");
    final startStr = fmt.format(item.startTime);
    final endStr = fmt.format(item.endTime);
    final time = "$startStr – $endStr";
    
    final l = AppLocalizations.of(context);
    final subtitle = item.reason.trim().isEmpty ? l.scheduledLabel : item.reason;
    final theme = Theme.of(context);

    // Color code priority if desired, or keep simple
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(time, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6))),
              const SizedBox(height: 6),
              Text(subtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(AppLocalizations.of(context).minutesLabel(item.estimatedMinutes), style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.5))),
            ]),
          ),
          if (onAccept != null)
             IconButton(
               icon: const Icon(Icons.add_circle, color: Colors.green),
               onPressed: onAccept,
               tooltip: AppLocalizations.of(context).acceptAndEdit,
             ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: onDelete,
              tooltip: AppLocalizations.of(context).removeFromPlanLabel,
            ),
        ],
      ),
    );
  }
}
