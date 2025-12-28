import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/ai_plan_item.dart';
import '../models/ai_plan_response.dart' hide AIPlanItem;
import 'package:intl/intl.dart';

class AIPlannerScreen extends StatefulWidget {

  const AIPlannerScreen({super.key});

  @override
  State<AIPlannerScreen> createState() => _AIPlannerScreenState();
}

class _AIPlannerScreenState extends State<AIPlannerScreen> {
  TimeOfDay _dayStart = const TimeOfDay(hour: 9, minute: 0);
  int _plannedMinutes = 30;

  Future<AIPlanResponse>? _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getAIPlan(); // default
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

  void _generate() {
    setState(() {
      _future = null; // Force rebuild to show loading if we want, or just re-assign
    });
    // Small delay to let UI show loading if needed, or just immediate:
    setState(() {
      _future = ApiService.getAIPlan(
        dayStart: _dayStart,
        plannedMinutes: _plannedMinutes,
      );
    });
  }

  String _fmtTimeOfDay(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

 List<AIPlanItem> _itemsFrom(AIPlanResponse plan) {
  return plan.items.map((e) {
    return AIPlanItem(
      title: e.title,
      startTime: e.startTime,
      endTime: e.endTime,
      estimatedMinutes: e.estimatedMinutes,
      reason: e.reason,
    );
  }).toList();
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
            tooltip: "Regenerate",
            icon: const Icon(Icons.refresh),
            onPressed: _generate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
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
          ),

          Expanded(
            child: FutureBuilder<AIPlanResponse>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Failed to generate plan:\n${snap.error}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final plan = snap.data;
                if (plan == null) {
                  return const Center(child: Text("No plan."));
                }

                final items = _itemsFrom(plan);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "AI daily plan created successfully.",
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
                      ...items.map((it) => _PlanCard(item: it)),
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
    final options = [15, 30, 45, 60, 90, 120, 180];
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
}

class _PlanCard extends StatelessWidget {
  final AIPlanItem item;
  const _PlanCard({required this.item});

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
        ],
      ),
    );
  }
}
