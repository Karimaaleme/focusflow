// lib/screens/ai_planner_screen.dart
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/ai_plan_response.dart';
import '../models/ai_plan_item.dart';
import 'focus_session_screen.dart';

class AIPlannerScreen extends StatefulWidget {
  final String token;

  const AIPlannerScreen({super.key, required this.token});

  @override
  State<AIPlannerScreen> createState() => _AIPlannerScreenState();
}

class _AIPlannerScreenState extends State<AIPlannerScreen> {
  late Future<AIPlanResponse> _future;

  // local reorder (UX) – לא שומר בשרת כרגע
  List<AIPlanItem> _localItems = [];
  bool _hasLocal = false;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getAIPlan(widget.token);
  }

  Future<void> _reload({bool clearLocal = false}) async {
    if (clearLocal) {
      _hasLocal = false;
      _localItems = [];
    }
    setState(() {
      _future = ApiService.getAIPlan(widget.token);
    });
  }

  List<AIPlanItem> _itemsFrom(AIPlanResponse plan) {
    if (_hasLocal) return _localItems;
    return plan.items;
  }

  Future<void> _markDone(AIPlanItem item) async {
    if (item.taskId == null) return;
    try {
      await ApiService.updateTaskStatus(
        token: widget.token,
        id: item.taskId!,
        status: 'done',
      );
      await ApiService.toggleTaskComplete(
        token: widget.token,
        id: item.taskId!,
      );
      if (!mounted) return;
      await _reload(clearLocal: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark done: $e")),
      );
    }
  }

  Future<void> _skipToTomorrow(AIPlanItem item) async {
    if (item.taskId == null) return;
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await ApiService.updateTaskDueDate(
        token: widget.token,
        id: item.taskId!,
        dueDatetime: tomorrow,
      );
      if (!mounted) return;
      await _reload(clearLocal: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to move task: $e")),
      );
    }
  }

  void _openFocus(AIPlanItem item) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FocusSessionScreen(
        block: item,
        token: widget.token,
      ),
    ),
  );
}


  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _localItems.removeAt(oldIndex);
      _localItems.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Planner"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Regenerate plan",
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _reload(clearLocal: true),
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<AIPlanResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  "Failed to load plan:\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final plan = snapshot.data!;
          final items = _itemsFrom(plan);

          // init local list once (for reorder UX)
          if (!_hasLocal) {
            _localItems = List<AIPlanItem>.from(plan.items);
          }

          if (items.isEmpty) {
            return const Center(
              child: Text(
                "No tasks to plan for today.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: Column(
              children: [
                _TopBanner(plan: plan),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    onReorder: (oldIndex, newIndex) {
                      // אם אין local עדיין, הופכים ל-local
                      if (!_hasLocal) {
                        _hasLocal = true;
                        _localItems = List<AIPlanItem>.from(plan.items);
                      }
                      _reorder(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _PlanCard(
                        key: ValueKey("${item.taskId}_${item.startTime}_${item.endTime}_$index"),
                        item: item,
                        onTap: () => _openFocus(item),
                        onDone: item.taskId == null ? null : () => _markDone(item),
                        onSkip: item.taskId == null ? null : () => _skipToTomorrow(item),
                      );
                    },
                  ),
                ),
                if (_hasLocal)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _hasLocal = false;
                                _localItems = [];
                              });
                            },
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text("Reset order"),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopBanner extends StatelessWidget {
  final AIPlanResponse plan;

  const _TopBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    final bg = plan.overloaded ? Colors.red[50] : Colors.blueGrey[50];
    final fg = plan.overloaded ? Colors.red[800] : Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: bg,
      child: Column(
        children: [
          Text(
            plan.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Planned time: ${plan.totalMinutes} min",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final AIPlanItem item;
  final VoidCallback onTap;
  final VoidCallback? onDone;
  final VoidCallback? onSkip;

  const _PlanCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDone,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final hasActions = item.taskId != null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // title + actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (hasActions) ...[
                    IconButton(
                      tooltip: "Mark done",
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      onPressed: onDone,
                    ),
                    IconButton(
                      tooltip: "Skip to tomorrow",
                      icon: const Icon(Icons.skip_next, size: 20),
                      onPressed: onSkip,
                    ),
                  ],
                  const ReorderableDragStartListener(
                    index: 0, // overridden internally by ReorderableListView keys
                    child: Icon(Icons.drag_indicator, size: 20, color: Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.timeRangeLabel,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(item.reason, style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 8),
              Text(
                "${item.estimatedMinutes} minutes",
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
