// lib/screens/add_task_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/task.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? existingTask;
  final Task? template; // NEW for suggestions

  const AddTaskScreen({
    super.key,
    this.existingTask,
    this.template,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final estimatedCtrl = TextEditingController();
  final actualCtrl = TextEditingController();
  final intervalCtrl = TextEditingController(text: "1"); // NEW

  final List<SubTask> _subtasks = [];
  final _subtaskCtrl = TextEditingController();

  String priority = "medium";
  String status = "todo";
  String category = "general"; // ADDED
  
  // Recurring vars
  bool isRecurring = false;
  String recurrenceType = "daily"; // daily, weekly, monthly

  DateTime? dueDate;
  TimeOfDay? dueTime;

  DateTime? reminderDate;
  TimeOfDay? reminderTime;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final t = widget.existingTask ?? widget.template;
    if (t != null) {
      titleCtrl.text = t.title;
      descCtrl.text = t.description;
      priority = t.priority;
      status = t.status;
      category = t.category; // ADDED
      estimatedCtrl.text = t.estimatedMinutes.toString();
      actualCtrl.text = t.actualMinutes.toString();
      _subtasks.addAll(t.subtasks);

      if (t.dueDatetime != null) {
        dueDate = DateTime(
          t.dueDatetime!.year,
          t.dueDatetime!.month,
          t.dueDatetime!.day,
        );
        dueTime = TimeOfDay.fromDateTime(t.dueDatetime!);
      }

      if (t.reminderDateTime != null) {
         reminderDate = DateTime(
          t.reminderDateTime!.year,
          t.reminderDateTime!.month,
          t.reminderDateTime!.day,
        );
        reminderTime = TimeOfDay.fromDateTime(t.reminderDateTime!);
      }
      
      // Recurrence
      isRecurring = t.isRecurring;
      recurrenceType = t.recurrence ?? "daily";
      intervalCtrl.text = (t.recurrenceInterval ?? 1).toString();
      
    } else {
      estimatedCtrl.text = "30";
      actualCtrl.text = "0";
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    estimatedCtrl.dispose();
    actualCtrl.dispose();
    intervalCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({bool isReminder = false}) async {
    final now = DateTime.now();
    final initial = isReminder ? (reminderDate ?? now) : (dueDate ?? now);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 700)),
    );
    if (picked != null) {
      setState(() {
         if (isReminder) {
           reminderDate = picked;
         } else {
           dueDate = picked;
         }
      });
    }
  }

  Future<void> _pickTime({bool isReminder = false}) async {
    final now = TimeOfDay.now();
    final initial = isReminder ? (reminderTime ?? now) : (dueTime ?? now);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isReminder) {
           reminderTime = picked;
         } else {
           dueTime = picked;
         }
      });
    }
  }

  DateTime? _combinedDateTime(DateTime? d, TimeOfDay? t) {
    if (d == null) return null;
    final time = t ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(
      d.year,
      d.month,
      d.day,
      time.hour,
      time.minute,
    );
  }

  void _addSubtask() {
    if (_subtaskCtrl.text.trim().isEmpty) return;
    setState(() {
      _subtasks.add(SubTask(title: _subtaskCtrl.text.trim(), isCompleted: false));
      _subtaskCtrl.clear();
    });
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtasks.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final remDt = _combinedDateTime(reminderDate, reminderTime);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.existingTask == null ? AppLocalizations.of(context).createTask : AppLocalizations.of(context).editTask),
        centerTitle: true,
        elevation: 0,
        actions: const [LanguageToggleButton()],
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(context, AppLocalizations.of(context).taskDetailsSection),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).titleLabel,
                hintText: AppLocalizations.of(context).taskTitleHint,
                prefixIcon: const Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).descriptionLabel,
                hintText: AppLocalizations.of(context).taskDescHint,
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),

            
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: category.toLowerCase(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).categoryLabel,
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              dropdownColor: theme.cardColor,
              items: [
                DropdownMenuItem(value: "general", child: Text(AppLocalizations.of(context).categoryGeneral)),
                DropdownMenuItem(value: "work", child: Text(AppLocalizations.of(context).categoryWork)),
                DropdownMenuItem(value: "personal", child: Text(AppLocalizations.of(context).categoryPersonal)),
                DropdownMenuItem(value: "study", child: Text(AppLocalizations.of(context).categoryStudy)),
                DropdownMenuItem(value: "health", child: Text(AppLocalizations.of(context).categoryHealth)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => category = v);
              },
            ),

            const SizedBox(height: 24),
            _sectionLabel(context, AppLocalizations.of(context).statusAndPriority),
            const SizedBox(height: 12),
            
            // Priority & Status Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _priorityChip(context, "low", Colors.green),
                  const SizedBox(width: 8),
                  _priorityChip(context, "medium", Colors.orange),
                  const SizedBox(width: 8),
                  _priorityChip(context, "high", Colors.red),
                ],
              ),
            ),
             const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                   _statusChip(context, "todo"),
                   const SizedBox(width: 8),
                   _statusChip(context, "in_progress"),
                   const SizedBox(width: 8),
                   _statusChip(context, "done"),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _sectionLabel(context, AppLocalizations.of(context).recurrenceSection),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).recurringTask, style: theme.textTheme.bodyMedium),
              value: isRecurring,
              onChanged: (v) => setState(() => isRecurring = v),
            ),
            if (isRecurring) ...[
              Row(
                children: [
                   Expanded(
                     flex: 2,
                     child: DropdownButtonFormField<String>(
                       value: recurrenceType,
                       decoration: InputDecoration(labelText: AppLocalizations.of(context).repeatLabel),
                       dropdownColor: theme.cardColor,
                       style: theme.textTheme.bodyMedium,
                       items: [
                         DropdownMenuItem(value: "daily", child: Text(AppLocalizations.of(context).recurrenceDaily, style: theme.textTheme.bodyMedium)),
                         DropdownMenuItem(value: "weekly", child: Text(AppLocalizations.of(context).recurrenceWeekly, style: theme.textTheme.bodyMedium)),
                         DropdownMenuItem(value: "monthly", child: Text(AppLocalizations.of(context).recurrenceMonthly, style: theme.textTheme.bodyMedium)),
                       ],
                       onChanged: (v) {
                         if (v != null) setState(() => recurrenceType = v);
                       },
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     flex: 1,
                     child: TextField(
                       controller: intervalCtrl,
                       keyboardType: TextInputType.number,
                       style: theme.textTheme.bodyMedium,
                       decoration: InputDecoration(
                         labelText: AppLocalizations.of(context).intervalLabel,
                         suffixText: "x",
                       ),
                     ),
                   ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            _sectionLabel(context, AppLocalizations.of(context).timingReminders),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: estimatedCtrl,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).estMinutesLabel,
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: actualCtrl,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).actualMinutesLabel,
                      prefixIcon: const Icon(Icons.history_toggle_off),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
             // DUE DATE
             Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isReminder: false),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        dueDate == null
                            ? AppLocalizations.of(context).setDueDate
                            : DateFormat("MMM dd, yyyy").format(dueDate!),
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isReminder: false),
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        dueTime == null ? AppLocalizations.of(context).setTimeLabel : dueTime!.format(context),
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // REMINDER
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: Colors.purple),
                ),
                title: Text(
                  remDt == null
                     ? AppLocalizations.of(context).setReminder
                     : "Reminder: ${DateFormat("MMM dd, HH:mm").format(remDt)}",
                   style: TextStyle(
                     fontWeight: remDt != null ? FontWeight.bold : FontWeight.normal,
                     color: remDt != null ? Colors.purple : theme.textTheme.bodyMedium?.color,
                   ),
                ),
                onTap: () async {
                   await _pickDate(isReminder: true);
                   if (reminderDate != null && mounted) {
                     await _pickTime(isReminder: true);
                   }
                },
                trailing: remDt == null 
                   ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                   : IconButton(
                       icon: const Icon(Icons.close, color: Colors.grey),
                       onPressed: () => setState(() {
                         reminderDate = null;
                         reminderTime = null;
                       }),
                   ),
              ),


            const SizedBox(height: 24),
            _sectionLabel(context, AppLocalizations.of(context).subtasksSection),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskCtrl,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).addSubtaskHint,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addSubtask,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_subtasks.isEmpty)
              Text(
                AppLocalizations.of(context).noSubtasksYet,
                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              )
            else
              ..._subtasks.asMap().entries.map((entry) {
                final idx = entry.key;
                final sub = entry.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: sub.isCompleted,
                    onChanged: (v) {
                       setState(() {
                         _subtasks[idx] = SubTask(
                           title: sub.title,
                           isCompleted: v ?? false
                         );
                       });
                    },
                  ),
                  title: Text(
                    sub.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeSubtask(idx),
                  ),
                );
              }),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(
                  widget.existingTask == null ? AppLocalizations.of(context).createTask : AppLocalizations.of(context).saveChanges,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _priorityChip(BuildContext context, String val, Color color) {
    final theme = Theme.of(context);
    final isSelected = priority == val;
    return ChoiceChip(
      label: Text(val.toUpperCase()),
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      backgroundColor: theme.canvasColor,
      labelStyle: TextStyle(
        color: isSelected ? color : (theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.black54),
        fontWeight: FontWeight.w700,
      ),
      checkmarkColor: color,
      onSelected: (_) => setState(() => priority = val),
      side: isSelected ? BorderSide(color: color) : BorderSide(color: Colors.grey.withOpacity(0.3)),
    );
  }

  Widget _statusChip(BuildContext context, String val) {
    final theme = Theme.of(context);
    final isSelected = status == val;
    return ChoiceChip(
      label: Text(val.replaceAll("_", " ").toUpperCase()),
      selected: isSelected,
      backgroundColor: theme.canvasColor,
      labelStyle: isSelected ? const TextStyle(color: Colors.white) : TextStyle(color: theme.textTheme.bodyMedium?.color),
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: Colors.white,
      onSelected: (_) => setState(() => status = val),
      side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3)),
    );
  }

  Future<void> _submit() async {
    if (titleCtrl.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final minutes = int.tryParse(estimatedCtrl.text) ?? 30;
    final actual = int.tryParse(actualCtrl.text) ?? 0;
    final interval = int.tryParse(intervalCtrl.text) ?? 1;
    final due = _combinedDateTime(dueDate, dueTime);
    final reminder = _combinedDateTime(reminderDate, reminderTime);

    try {
      if (widget.existingTask == null) {
        await ApiService.createTask(
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim(),
          category: category, // UPDATED
          priority: priority,
          status: status,
          estimatedMinutes: minutes,
          actualMinutes: actual,
          dueDatetime: due,
          reminderDateTime: reminder,
          isRecurring: isRecurring,
          recurrence: recurrenceType,
          recurrenceInterval: interval,
          subtasks: _subtasks,
        );
      } else {
        await ApiService.updateTask(
          id: widget.existingTask!.id,
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim(),
          category: category, // UPDATED
          priority: priority,
          status: status,
          estimatedMinutes: minutes,
          actualMinutes: actual,
          dueDatetime: due,
          reminderDateTime: reminder,
          isRecurring: isRecurring,
          recurrence: recurrenceType,
          recurrenceInterval: interval,
          subtasks: _subtasks,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("${AppLocalizations.of(context).errorSavingTask}: $e")),
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
