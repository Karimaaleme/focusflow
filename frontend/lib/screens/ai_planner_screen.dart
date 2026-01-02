import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/api_service.dart';
import '../models/ai_plan_response.dart';
import 'package:intl/intl.dart';
import '../widgets/reminder_banner.dart';
import 'add_task_screen.dart';
import '../models/task.dart';

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
          var items = List<AIPlanItem>.from(plan.items);

          // Client-side fallback: Ensure we have suggestions for selected categories
          if (_selectedCategories.isNotEmpty) {
             final now = DateTime.now();
             
             // Specific suggestions map
             final Map<String, List<String>> suggestionsMap = {
               "Health": ["Go for a walk", "Do push ups", "Yoga session", "Drink water & stretch", "Meal prep"],
               "Work": ["Clear inbox", "Plan tomorrow's tasks", "Deep work session", "Organize files"],
               "Study": ["Review notes", "Read a chapter", "Practice problems", "Summarize key points"],
               "Finance": ["Review budget", "Track expenses", "Pay bills"],
               "Personal": ["Read a book", "Call a friend", "Meditate", "Journaling"],
               "General": ["Tidy up", "Plan the week"]
             };

             // Determine start time for new suggestions (after last task or at start)
             var t = items.isNotEmpty 
                 ? items.last.endTime.add(const Duration(minutes: 15))
                 : DateTime(now.year, now.month, now.day, _dayStart.hour, _dayStart.minute);
             
             for (final cat in _selectedCategories) {
                // Heuristic: Do we already have a task for this category?
                final alreadyHas = items.any((i) => 
                    i.title.toLowerCase().contains(cat.toLowerCase()) || 
                    (i.reason ?? "").toLowerCase().contains(cat.toLowerCase())
                );
                
                if (!alreadyHas) {
                    final dur = 30;
                    final endTime = t.add(Duration(minutes: dur));
                    
                    // Pick a random specific topic
                    String topic = "$cat Activity";
                    if (suggestionsMap.containsKey(cat)) {
                      final list = List<String>.from(suggestionsMap[cat]!);
                      list.shuffle();
                      topic = list.first;
                    }
                    
                    items.add(AIPlanItem(
                       taskId: null, // Suggestion
                       title: "[$cat] $topic",
                       startTime: t,
                       startTimeStr: "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}",
                       endTime: endTime,
                       estimatedMinutes: dur,
                       priority: "medium",
                       reason: "AI Suggestion for $cat",
                    ));
                    
                    t = endTime.add(const Duration(minutes: 15));
                }
             }
             
             // Update plan stats if we added items
             if (items.length > plan.items.length) {
                 _currentPlan = AIPlanResponse(
                    items: items,
                    totalMinutes: items.fold(0, (sum, i) => sum + i.estimatedMinutes),
                    overloaded: false, 
                    message: "Plan generated with specific suggestions.",
                    workload: plan.workload ?? WorkloadAnalysis(status: "balanced", summary: "Enhanced with specific suggestions", recommendation: "Good loop"),
                 );
             }
          }

          _planItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to generate: $e")),
        );
      }
    }
  }

  String _fmtTimeOfDay(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

 List<AIPlanItem> _itemsFrom(AIPlanResponse plan) {
  return plan.items.map((e) {
    return AIPlanItem(
      taskId: e.taskId,
      title: e.title,
      startTime: e.startTime,
      startTimeStr: e.startTimeStr,
      endTime: e.endTime,
      estimatedMinutes: e.estimatedMinutes,
      reason: e.reason,
      priority: e.priority,
    );
  }).toList();
}



  Future<void> _acceptPlan() async {
    if (_planItems.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Gather task IDs in the new order
      final orderedIds = _planItems
          .where((it) => it.taskId != null)
          .map((it) => it.taskId!)
          .toList();

      if (orderedIds.isNotEmpty) {
        await ApiService.updateTaskOrder(orderedIds);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        // Navigate back or show success
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Plan accepted! Tasks reorganized.")),
        );
        Navigator.pop(context); // Optional: go back to home/smart plan root
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save order: $e")),
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
      appBar: AppBar(
        title: const Text("Smart Planner"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Calendar Sync Settings",
            icon: const Icon(Icons.sync),
            onPressed: () => _showSyncSettings(context),
          ),
          IconButton(
            tooltip: "Regenerate",
            icon: const Icon(Icons.refresh),
            onPressed: _generate,
          ),
        ],
      ),
      floatingActionButton: _planItems.isNotEmpty && !_isLoading 
        ? FloatingActionButton.extended(
            onPressed: _acceptPlan,
            icon: const Icon(Icons.check),
            label: const Text("Accept Plan"),
            backgroundColor: theme.colorScheme.primary,
          )
        : null,
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
                            title: "Start time",
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
                        child: Text("Generate", style: TextStyle(color: theme.colorScheme.onPrimary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text("Focus Categories:", style: theme.textTheme.bodySmall),
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
                  // Initial state or error (already snackbared)
                  return const Center(child: Text("Ready to generate plan."));
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
                                  "Workload: ${plan.workload!.status.toUpperCase()}",
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
                                "Tip: ${plan.workload!.recommendation}",
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
                          const Text(
                            "AI optimized schedule ready.",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text("Planned time: ${plan.totalMinutes} min"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: Center(child: Text("No items returned.")),
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
                               SnackBar(content: Text("Removed ${it.title} from plan")),
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
                                  description: it.reason ?? "",
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
                                    const SnackBar(content: Text("Task accepted and added!")),
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
                  child: Text("Duration: $m min", style: theme.textTheme.bodyMedium),
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
                 title: const Text("Calendar Integration"),
                 content: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      SwitchListTile(
                        title: const Text("Google Calendar"),
                        subtitle: const Text("Sync events from Google"),
                        value: _syncGoogle,
                        secondary: const Icon(Icons.calendar_month, color: Colors.blue),
                        onChanged: (v) {
                            setStateDialog(() => _syncGoogle = v);
                            setState(() {}); 
                        },
                      ),
                      SwitchListTile(
                        title: const Text("Outlook Calendar"),
                        subtitle: const Text("Sync events from Outlook"),
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
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings saved. Regenerating...")));
                     }, 
                     child: const Text("Save & Regenerate")
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
    
    final subtitle = (item.reason ?? "").trim().isEmpty ? "Scheduled" : item.reason;
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
              Text("${item.estimatedMinutes} minutes", style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.5))),
            ]),
          ),
          if (onAccept != null)
             IconButton(
               icon: const Icon(Icons.add_circle, color: Colors.green),
               onPressed: onAccept,
               tooltip: "Accept & Edit",
             ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: onDelete,
              tooltip: "Remove from plan",
            ),
        ],
      ),
    );
  }
}
