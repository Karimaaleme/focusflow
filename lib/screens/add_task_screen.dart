// lib/screens/add_task_screen.dart
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();

    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      titleCtrl.text = t.title;
      descCtrl.text = t.description;
      priority = t.priority;
      status = t.status;
      estimatedCtrl.text = t.estimatedMinutes.toString();
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
            border: Border.all(color: const Color(0xFFE7E7E2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
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
                    color: Color(0xFF2E2B29),
                  ),
                ),
                const SizedBox(height: 20),

                _notionField(
                  label: "Title",
                  controller: titleCtrl,
                  placeholder: "Write your task name...",
                ),
                const SizedBox(height: 16),

                _notionField(
                  label: "Description",
                  controller: descCtrl,
                  placeholder: "Add more details...",
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // Estimated minutes
                _notionField(
                  label: "Estimated time (minutes)",
                  controller: estimatedCtrl,
                  placeholder: "e.g., 30",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 22),

                const Text(
                  "Priority",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF3F3A36),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _prioritySelector(),

                const SizedBox(height: 22),

                const Text(
                  "Status",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF3F3A36),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _statusSelector(),

                const SizedBox(height: 26),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F3A36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.existingTask == null ? "Create" : "Save",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notionField({
    required String label,
    required TextEditingController controller,
    String placeholder = "",
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6D665E),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7E7E2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: placeholder,
              hintStyle: const TextStyle(color: Color(0xFF9A948C)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _prioritySelector() {
    return Row(
      children: [
        _pill("low", Colors.greenAccent),
        const SizedBox(width: 10),
        _pill("medium", Colors.orangeAccent),
        const SizedBox(width: 10),
        _pill("high", Colors.redAccent),
      ],
    );
  }

  Widget _statusSelector() {
    return Row(
      children: [
        _pill("todo", const Color(0xFFE26A6A)),
        const SizedBox(width: 10),
        _pill("in_progress", const Color(0xFFE8A04B)),
        const SizedBox(width: 10),
        _pill("done", const Color(0xFF65B67A)),
      ],
    );
  }

  Widget _pill(String value, Color color) {
    final bool isPriority = ["low", "medium", "high"].contains(value);
    final bool selected =
        isPriority ? (priority == value) : (status == value);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isPriority) {
            priority = value;
          } else {
            status = value;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : const Color(0xFFE7E7E2),
            width: 1.5,
          ),
        ),
        child: Text(
          value.replaceAll("_", " ").toUpperCase(),
          style: TextStyle(
            color: selected ? color : const Color(0xFF3F3A36),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (titleCtrl.text.trim().isEmpty) return;

    final minutes = int.tryParse(estimatedCtrl.text.trim()) ?? 30;

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
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
