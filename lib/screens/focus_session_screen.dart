// lib/screens/focus_session_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../models/ai_plan_item.dart';

class FocusSessionScreen extends StatefulWidget {
  final AIPlanItem block;

  const FocusSessionScreen({super.key, required this.block});

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  late Duration _remaining;
  Timer? _timer;
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _remaining = Duration(minutes: widget.block.estimatedMinutes);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds <= 1) {
          _remaining = Duration.zero;
          _isRunning = false;
          timer.cancel();
        } else {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.block.estimatedMinutes == 0
        ? 0.0
        : 1.0 -
            (_remaining.inSeconds /
                (widget.block.estimatedMinutes * 60).clamp(1, 100000));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Focus Session"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              widget.block.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.block.reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 220,
              width: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 220,
                    width: 220,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 10,
                    ),
                  ),
                  Text(
                    _formatDuration(_remaining),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: _toggleTimer,
                  child: Text(_isRunning ? "Pause" : "Resume"),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(context, true); // “session done”
                  },
                  child: const Text("Finish"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
