// lib/screens/add_task_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/task.dart';

class AddTaskScreen extends StatefulWidget {
  final String token;
  final Task? existingTask;

  const AddTaskScreen({
    super.key,
    required this.token,
    this.existingTask,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final estimatedCtrl = TextEditingController();

  String priority = "medium";
  String status = "todo";

  DateTime? dueDate;
  TimeOfDay? dueTime;

  @override
  void initState() {
    super.initState();

    final t = widget.existingTask;
    if (t != null) {
      titleCtrl.text = t.title;
      descCtrl.text = t.description;
      priority = t.priority;
      status = t.status;
      estimatedCtrl.text = t.estimatedMinutes.toString();

      if (t.dueDatetime != null) {
        dueDate = DateTime(
          t.dueDatetime!.year,
          t.dueDatetime!.month,
          t.dueDatetime!.day,
        );
        dueTime = TimeOfDay.fromDateTime(t.dueDatetime!);
      }
    } else {
      estimatedCtrl.text = "30";
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    estimatedCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => dueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => dueTime = picked);
    }
  }

  DateTime? _combinedDueDateTime() {
    if (dueDate == null) return null;

    final time = dueTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(
      dueDate!.year,
      dueDate!.month,
      dueDate!.day,
      time.hour,
      time.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.35),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.90,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingTask == null ? "Create Task" : "Edit Task",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),

                _field("Title", titleCtrl),
                const SizedBox(height: 16),
                _field("Description", descCtrl, maxLines: 4),
                const SizedBox(height: 16),
                _field(
                  "Estimated time (minutes)",
                  estimatedCtrl,
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 22),

                /// 📅 Due date & time
                const Text(
                  "Due date",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        dueDate == null
                            ? "Pick date"
                            : DateFormat("dd MMM yyyy").format(dueDate!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        dueTime == null
                            ? "Pick time"
                            : dueTime!.format(context),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                const Text("Priority",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _selector(["low", "medium", "high"], priority,
                    (v) => setState(() => priority = v)),

                const SizedBox(height: 22),

                const Text("Status",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _selector(["todo", "in_progress", "done"], status,
                    (v) => setState(() => status = v)),

                const SizedBox(height: 26),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text(
                        widget.existingTask == null ? "Create" : "Save"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: const InputDecoration(
            filled: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _selector(
    List<String> values,
    String selected,
    void Function(String) onSelect,
  ) {
    return Row(
      children: values.map((v) {
        final isSelected = v == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(v.replaceAll("_", " ").toUpperCase()),
            selected: isSelected,
            onSelected: (_) => onSelect(v),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _submit() async {
    if (titleCtrl.text.trim().isEmpty) return;

    final minutes = int.tryParse(estimatedCtrl.text) ?? 30;
    final due = _combinedDueDateTime();

    if (widget.existingTask == null) {
      await ApiService.createTask(
        token: widget.token,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        category: "general",
        priority: priority,
        status: status,
        estimatedMinutes: minutes,
      );
    } else {
      await ApiService.updateTask(
        token: widget.token,
        id: widget.existingTask!.id,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        priority: priority,
        status: status,
        estimatedMinutes: minutes,
        dueDatetime: due,
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
