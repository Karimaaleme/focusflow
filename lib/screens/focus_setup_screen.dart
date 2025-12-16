// lib/screens/focus_setup_screen.dart
import 'package:flutter/material.dart';

import '../models/ai_plan_item.dart';
import 'focus_session_screen.dart';

class FocusSetupScreen extends StatefulWidget {
  final AIPlanItem block;
  final String token;

  const FocusSetupScreen({
    super.key,
    required this.block,
    required this.token,
  });

  @override
  State<FocusSetupScreen> createState() => _FocusSetupScreenState();
}

class _FocusSetupScreenState extends State<FocusSetupScreen> {
  int selectedMinutes = 25;

  final List<int> presets = [15, 25, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F4),
        elevation: 0,
        title: const Text("Focus"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _TaskCard(title: widget.block.title),

            const SizedBox(height: 24),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: presets.map((m) {
                final active = m == selectedMinutes;
                return ChoiceChip(
                  label: Text("$m min"),
                  selected: active,
                  onSelected: (_) => setState(() => selectedMinutes = m),
                  selectedColor: Colors.black,
                  labelStyle: TextStyle(
                    color: active ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),

const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FocusSessionScreen(
                        block: AIPlanItem(
  title: widget.block.title,
  startTime: widget.block.startTime,
  endTime: widget.block.endTime,
  estimatedMinutes: selectedMinutes,
  reason: widget.block.reason,
),

                        token: widget.token,
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  "Start Focus",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;

  const _TaskCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
