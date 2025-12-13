import 'package:flutter/material.dart';

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({super.key});

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  int mood = 3; // 1–5
  final TextEditingController wentWellCtrl = TextEditingController();
  final TextEditingController improveCtrl = TextEditingController();

  bool saved = false;

  @override
  void dispose() {
    wentWellCtrl.dispose();
    improveCtrl.dispose();
    super.dispose();
  }

  String _moodLabel(int m) {
    switch (m) {
      case 1:
        return "Very low 😞";
      case 2:
        return "Low 😕";
      case 3:
        return "Okay 🙂";
      case 4:
        return "Good 😊";
      case 5:
        return "Great 😄";
      default:
        return "";
    }
  }

  void _save() {
    setState(() => saved = true);

    // Later: save to backend / local DB / AI analysis
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      appBar: AppBar(
        title: const Text("Daily Reflection"),
        centerTitle: true,
        backgroundColor: const Color(0xFFF6F6F4),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              "How was your day?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 12),

            // ---------------- MOOD ----------------
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Mood",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: mood.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: mood.toString(),
                    onChanged: (v) => setState(() => mood = v.toInt()),
                  ),
                  Center(
                    child: Text(
                      _moodLabel(mood),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ---------------- WENT WELL ----------------
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What went well today?",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: wentWellCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Example: I finished my most important task.",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ---------------- IMPROVE ----------------
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What could be improved?",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: improveCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Example: Fewer distractions in the afternoon.",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---------------- SAVE ----------------
            saved
                ? const Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green, size: 48),
                        SizedBox(height: 8),
                        Text(
                          "Reflection saved ✔",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text("Save Reflection"),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------- UI CARD ----------------

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
