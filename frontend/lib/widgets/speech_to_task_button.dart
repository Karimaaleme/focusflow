import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

// ─── Public button — drop anywhere ───────────────────────────────────────────

class SpeechToTaskButton extends StatelessWidget {
  final VoidCallback? onTaskCreated;
  final String? heroTag;

  const SpeechToTaskButton({
    super.key,
    this.onTaskCreated,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag ?? 'fab_speech_to_task',
      onPressed: () => _showSheet(context),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      tooltip: AppLocalizations.of(context).speechToTask,
      child: const Icon(Icons.mic_rounded),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpeechSheet(onTaskCreated: onTaskCreated),
    );
  }
}

// ─── Sheet states ─────────────────────────────────────────────────────────────

enum _SheetState { idle, listening, processing, preview, error }

// ─── Bottom sheet ─────────────────────────────────────────────────────────────

class _SpeechSheet extends StatefulWidget {
  final VoidCallback? onTaskCreated;
  const _SpeechSheet({this.onTaskCreated});

  @override
  State<_SpeechSheet> createState() => _SpeechSheetState();
}

class _SpeechSheetState extends State<_SpeechSheet>
    with SingleTickerProviderStateMixin {
  final SpeechToText _stt = SpeechToText();

  _SheetState _state = _SheetState.idle;
  String _transcript = '';
  Map<String, dynamic>? _preview;
  String _errorMsg = '';
  bool _sttAvailable = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initStt();
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (e) => _setError(e.errorMsg),
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            _state == _SheetState.listening &&
            _transcript.isNotEmpty) {
          _processTranscript();
        } else if ((status == 'done' || status == 'notListening') &&
            _state == _SheetState.listening &&
            _transcript.isEmpty) {
          if (mounted) setState(() => _state = _SheetState.idle);
        }
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stt.cancel();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_sttAvailable) {
      _setError(AppLocalizations.of(context).speechNotAvailable);
      return;
    }
    final isHebrew = AppLocalizations.of(context).isHebrew;
    setState(() {
      _state = _SheetState.listening;
      _transcript = '';
    });
    _pulseCtrl.repeat(reverse: true);

    await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
        // Don't auto-process here — wait for onStatus 'done' so the full
        // sentence is captured before we send to AI.
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
      partialResults: true,
      localeId: isHebrew ? 'he-IL' : 'en-US',
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    _pulseCtrl.stop();
    if (_transcript.isNotEmpty) {
      _processTranscript();
    } else {
      if (mounted) setState(() => _state = _SheetState.idle);
    }
  }

  Future<void> _processTranscript() async {
    if (_transcript.isEmpty) return;
    _pulseCtrl.stop();
    setState(() => _state = _SheetState.processing);
    try {
      final data = await ApiService.speechToTask(_transcript);
      if (mounted) setState(() { _preview = data; _state = _SheetState.preview; });
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _confirmCreate(Map<String, dynamic> edited) async {
    setState(() => _state = _SheetState.processing);
    try {
      DateTime? due;
      final rawDue = edited['due_datetime'];
      if (rawDue != null && rawDue.toString().isNotEmpty) {
        try { due = DateTime.parse(rawDue.toString()); } catch (_) {}
      }

      await ApiService.createTask(
        title: (edited['title'] as String? ?? '').isNotEmpty
            ? edited['title'] as String
            : 'New Task',
        description: edited['description'] as String? ?? '',
        category: edited['category'] as String? ?? 'General',
        priority: edited['priority'] as String? ?? 'medium',
        status: 'todo',
        estimatedMinutes: (edited['estimated_minutes'] as num?)?.toInt() ?? 30,
        dueDatetime: due,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onTaskCreated?.call();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).taskCreatedFromSpeech),
          backgroundColor: Colors.deepPurple,
        ));
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setError(String msg) {
    _pulseCtrl.stop();
    if (mounted) setState(() { _state = _SheetState.error; _errorMsg = msg; });
  }

  void _reset() => setState(() {
    _state = _SheetState.idle;
    _transcript = '';
    _preview = null;
    _errorMsg = '';
  });

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            l.speechToTask,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Content by state
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStateContent(l),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStateContent(AppLocalizations l) {
    switch (_state) {
      case _SheetState.idle:
        return _IdleContent(
          key: const ValueKey('idle'),
          label: l.tapMicToSpeak,
          onTap: _startListening,
        );

      case _SheetState.listening:
        return _ListeningContent(
          key: const ValueKey('listening'),
          transcript: _transcript,
          pulseAnim: _pulseAnim,
          stopLabel: l.tapToStop,
          onStop: _stopListening,
        );

      case _SheetState.processing:
        return _ProcessingContent(
          key: const ValueKey('processing'),
          label: l.processingTask,
        );

      case _SheetState.preview:
        return _PreviewContent(
          key: const ValueKey('preview'),
          preview: _preview!,
          transcript: _transcript,
          l: l,
          onConfirm: (edited) => _confirmCreate(edited),
          onRetry: _reset,
        );

      case _SheetState.error:
        return _ErrorContent(
          key: const ValueKey('error'),
          message: _errorMsg,
          retryLabel: l.tryAgain,
          onRetry: _reset,
        );
    }
  }
}

// ─── State content widgets ────────────────────────────────────────────────────

class _IdleContent extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _IdleContent({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.deepPurple.shade700,
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(height: 16),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ListeningContent extends StatelessWidget {
  final String transcript;
  final Animation<double> pulseAnim;
  final String stopLabel;
  final VoidCallback onStop;

  const _ListeningContent({
    super.key,
    required this.transcript,
    required this.pulseAnim,
    required this.stopLabel,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScaleTransition(
          scale: pulseAnim,
          child: GestureDetector(
            onTap: onStop,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade700,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 38),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(stopLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 16),
        if (transcript.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              transcript,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
              textAlign: TextAlign.center,
            ),
          )
        else
          const Text('...', style: TextStyle(color: Colors.white38, fontSize: 24)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ProcessingContent extends StatelessWidget {
  final String label;
  const _ProcessingContent({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.deepPurple),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

class _PreviewContent extends StatefulWidget {
  final Map<String, dynamic> preview;
  final String transcript;
  final AppLocalizations l;
  final void Function(Map<String, dynamic>) onConfirm;
  final VoidCallback onRetry;

  const _PreviewContent({
    super.key,
    required this.preview,
    required this.transcript,
    required this.l,
    required this.onConfirm,
    required this.onRetry,
  });

  @override
  State<_PreviewContent> createState() => _PreviewContentState();
}

class _PreviewContentState extends State<_PreviewContent> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late String _priority;
  late String _category;
  late int _estMins;
  DateTime? _dueDate;
  DateTime? _suggestedDate;
  String _suggestionReason = '';

  static const _priorities = ['low', 'medium', 'high'];
  static const _categories = ['Work', 'Study', 'Health', 'Personal', 'Finance', 'General'];

  @override
  void initState() {
    super.initState();
    final p = widget.preview;
    _titleCtrl = TextEditingController(text: p['title'] as String? ?? '');
    _descCtrl  = TextEditingController(text: p['description'] as String? ?? '');
    _priority  = p['priority'] as String? ?? 'medium';
    _category  = p['category'] as String? ?? 'General';
    _estMins   = (p['estimated_minutes'] as num?)?.toInt() ?? 30;

    final rawDue = p['due_datetime'];
    if (rawDue != null && rawDue.toString().isNotEmpty) {
      try { _dueDate = DateTime.parse(rawDue.toString()); } catch (_) {}
    }

    // Parse AI suggestion for inline display
    final rawSug = p['suggested_due_datetime'];
    if (rawSug != null && rawSug.toString().isNotEmpty) {
      try { _suggestedDate = DateTime.parse(rawSug.toString()); } catch (_) {}
    }
    _suggestionReason = p['suggestion_reason'] as String? ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color _priorityColor(String p) =>
      p == 'high' ? Colors.red : p == 'medium' ? Colors.orange : Colors.green;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.deepPurple),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? now),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.deepPurple),
        ),
        child: child!,
      ),
    );
    setState(() {
      _dueDate = DateTime(
        picked.year, picked.month, picked.day,
        pickedTime?.hour ?? 9,
        pickedTime?.minute ?? 0,
      );
    });
  }

  void _submit() {
    widget.onConfirm({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'priority': _priority,
      'category': _category,
      'estimated_minutes': _estMins,
      'due_datetime': _dueDate?.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.taskPreviewTitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 10),

        // ── Editable card ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  hintText: 'Title',
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
              const SizedBox(height: 6),

              // Description
              TextField(
                controller: _descCtrl,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 2,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),

              const SizedBox(height: 14),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),

              // Priority chips
              Row(
                children: [
                  const Icon(Icons.flag_outlined, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  ..._priorities.map((p) {
                    final selected = _priority == p;
                    final color = _priorityColor(p);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected ? color.withOpacity(0.25) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? color : Colors.white24,
                            ),
                          ),
                          child: Text(
                            p[0].toUpperCase() + p.substring(1),
                            style: TextStyle(
                              color: selected ? color : Colors.white38,
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 10),

              // Category dropdown
              Row(
                children: [
                  const Icon(Icons.folder_outlined, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _categories.contains(_category) ? _category : 'General',
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(color: Colors.blue, fontSize: 13),
                    underline: const SizedBox(),
                    isDense: true,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) { if (v != null) setState(() => _category = v); },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Estimated minutes stepper
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _estMins = (_estMins - 5).clamp(5, 480)),
                    child: const Icon(Icons.remove_circle_outline, color: Colors.white38, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Text('$_estMins${l.minsAbbr}',
                      style: const TextStyle(color: Colors.teal, fontSize: 13)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _estMins = (_estMins + 5).clamp(5, 480)),
                    child: const Icon(Icons.add_circle_outline, color: Colors.white38, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Due date row
              if (_dueDate != null)
                // User has a date set — show it with edit/clear
                GestureDetector(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: Colors.purple, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEE, MMM d – HH:mm').format(_dueDate!),
                        style: TextStyle(color: Colors.purple.shade300, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _dueDate = null),
                        child: const Icon(Icons.close, color: Colors.white24, size: 14),
                      ),
                    ],
                  ),
                )
              else
                // No date — show AI suggestion inline
                _InlineDateSuggestion(
                  suggested: _suggestedDate,
                  reason: _suggestionReason,
                  l: widget.l,
                  onUse: () => setState(() => _dueDate = _suggestedDate),
                  onPick: _pickDate,
                ),
            ],
          ),
        ),

        // Transcript hint
        if (widget.transcript.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('"${widget.transcript}"',
              style: const TextStyle(
                  color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],

        const SizedBox(height: 20),

        // Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l.tryAgain),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(l.confirmAndCreate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorContent({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.mic_off_rounded, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(
          message.length > 120 ? '${message.substring(0, 120)}…' : message,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(retryLabel),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Inline date suggestion ───────────────────────────────────────────────────

class _InlineDateSuggestion extends StatelessWidget {
  final DateTime? suggested;
  final String reason;
  final AppLocalizations l;
  final VoidCallback onUse;
  final VoidCallback onPick;

  const _InlineDateSuggestion({
    required this.suggested,
    required this.reason,
    required this.l,
    required this.onUse,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (suggested == null) {
      // No suggestion from AI — just show a pick button
      return GestureDetector(
        onTap: onPick,
        child: Row(
          children: [
            const Icon(Icons.event_outlined, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text(l.noDueDate,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(width: 6),
            const Icon(Icons.add_circle_outline, color: Colors.white24, size: 14),
          ],
        ),
      );
    }

    final label = DateFormat('EEE, MMM d – HH:mm').format(suggested!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 12),
              const SizedBox(width: 4),
              Text(l.aiSuggests,
                  style: const TextStyle(
                      color: Colors.deepPurple, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    if (reason.isNotEmpty)
                      Text(reason,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Use button
              GestureDetector(
                onTap: onUse,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(l.useThisDate,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              // Change button
              GestureDetector(
                onTap: onPick,
                child: const Icon(Icons.edit_calendar_outlined,
                    color: Colors.white38, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Small meta chip ─────────────────────────────────────────────────────────

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Meta({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withOpacity(0.8)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.9), fontSize: 12)),
      ],
    );
  }
}
