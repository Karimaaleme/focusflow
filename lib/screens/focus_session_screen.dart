// lib/screens/focus_session_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/ai_plan_item.dart';
import '../services/api_service.dart';

class FocusSessionScreen extends StatefulWidget {
  final AIPlanItem block;

  /// token optional (web/flow)
  final String? token;

  const FocusSessionScreen({
    super.key,
    required this.block,
    this.token,
  });

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;

  // setup / running modes
  bool _started = false;
  bool _running = false;

  // planned + timer
  int _plannedMinutes = 25;
  int _totalSeconds = 0;
  int _remainingSeconds = 0;

  // real focused time (only while running)
  int _focusedSeconds = 0;

  DateTime? _startedAt;

  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    final mins = widget.block.estimatedMinutes <= 0 ? 25 : widget.block.estimatedMinutes;
    _plannedMinutes = mins;

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnim = Tween<double>(begin: 0.985, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  // ---------------- Timer controls ----------------

  void _startSession() {
    _totalSeconds = _plannedMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _focusedSeconds = 0;

    _startedAt = DateTime.now();
    _started = true;

    _pulse.repeat(reverse: true);
    _resume();
  }

  void _resume() {
    _timer?.cancel();
    _running = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_running) return;

      if (_remainingSeconds <= 0) {
        _finishSession(auto: true);
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
        _focusedSeconds += 1; // ✅ real focused time
      });
    });

    setState(() {});
  }

  void _pause() {
    _running = false;
    _timer?.cancel();
    setState(() {});
  }

  void _toggle() {
    if (!_started) return;
    if (_running) {
      _pause();
    } else {
      _resume();
    }
  }

  Future<void> _finishSession({bool auto = false}) async {
    _timer?.cancel();
    _running = false;
    _pulse.stop();

    final startedAt = _startedAt;
    final focusedMinutes = (_focusedSeconds / 60).round();
    final endedAt = DateTime.now();

    if (widget.token != null && startedAt != null && focusedMinutes > 0) {
final plannedMinutes = widget.block.estimatedMinutes ?? focusedMinutes;

  try {
    await ApiService.logFocusSession(
      token: widget.token!,
      taskId: widget.block.taskId,
      plannedMinutes: plannedMinutes,
      focusedMinutes: focusedMinutes,
      startedAt: startedAt,
      endedAt: endedAt,
    );

      } catch (_) {
        // ignore (offline / backend missing)
      }
    }

    if (!mounted) return;
    _showFinishedSheet(
      planned: _plannedMinutes,
      focused: focusedMinutes,
      auto: auto,
    );
  }

  // ---------------- UI helpers ----------------

  double get _progress {
    if (_totalSeconds <= 0) return 0;
    final done = _totalSeconds - _remainingSeconds;
    return (done / _totalSeconds).clamp(0.0, 1.0);
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _showFinishedSheet({required int planned, required int focused, required bool auto}) {
    final efficiency = planned == 0 ? 0 : (focused / planned).clamp(0.0, 1.0);
    final percent = (efficiency * 100).round();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Icon(auto ? Icons.check_circle : Icons.verified, size: 44),
              const SizedBox(height: 10),
              const Text(
                "Session Summary",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Text(
                  widget.block.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: _miniStat("Planned", "$planned min")),
                  const SizedBox(width: 10),
                  Expanded(child: _miniStat("Focused", "$focused min")),
                  const SizedBox(width: 10),
                  Expanded(child: _miniStat("Efficiency", "$percent%")),
                ],
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Back",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF6F6F4);
    final muted = Colors.black.withValues(alpha: 0.62);
    final subtle = Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: const Text("Focus", style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (_started && (_running || _focusedSeconds > 0)) {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Exit focus?"),
                  content: const Text("You will lose this session progress."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Exit")),
                  ],
                ),
              );
              if (ok != true) return;
            }
            if (!mounted) return;
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            children: [
              // task card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: subtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.self_improvement),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.block.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _started
                                ? (_running ? "Focus running" : "Paused")
                                : "Pick duration, then start",
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // PRE-START UI
              if (!_started) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Duration", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withValues(alpha: 0.75))),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [15, 25, 45, 60].map((m) {
                    final selected = _plannedMinutes == m;
                    return ChoiceChip(
                      label: Text("$m min", style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : Colors.black)),
                      selected: selected,
                      onSelected: (_) => setState(() => _plannedMinutes = m),
                      selectedColor: Colors.black,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
                      ),
                    );
                  }).toList(),
                ),
const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _startSession,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Start Focus", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],

              // RUNNING UI
              if (_started) ...[
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: ScaleTransition(
                      scale: _running ? _pulseAnim : const AlwaysStoppedAnimation(1),
                      child: _Ring(
                        progress: _progress,
                        timeLabel: _mmss(_remainingSeconds),
                        percentLabel: "${(_progress * 100).round()}%",
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _toggle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.black.withValues(alpha: 0.14)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(_running ? "Pause" : "Resume", style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _finishSession(auto: false),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Finish", style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Focused so far: ${(_focusedSeconds / 60).round()} min",
                  style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   RING WIDGET
========================= */

class _Ring extends StatelessWidget {
  final double progress;
  final String timeLabel;
  final String percentLabel;

  const _Ring({
    required this.progress,
    required this.timeLabel,
    required this.percentLabel,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = Colors.black.withValues(alpha: 0.07);

    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: subtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: _RingPainter(progress),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  percentLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "remaining",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.50),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    final basePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      basePaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
