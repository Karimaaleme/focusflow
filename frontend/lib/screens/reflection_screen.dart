import 'package:flutter/material.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';

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

  String _moodLabel(int m, AppLocalizations l) {
    switch (m) {
      case 1: return l.moodVeryLow;
      case 2: return l.moodLow;
      case 3: return l.moodOkay;
      case 4: return l.moodGood;
      case 5: return l.moodGreat;
      default: return "";
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      appBar: AppBar(
        title: Text(l.dailyReflection),
        centerTitle: true,
        backgroundColor: const Color(0xFFF6F6F4),
        elevation: 0,
        actions: const [LanguageToggleButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              l.howWasYourDay,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 12),

            // ---------------- MOOD ----------------
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.moodSectionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
                      _moodLabel(mood, l),
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
                  Text(
                    l.whatWentWell,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: wentWellCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l.whatWentWellHint,
                      border: const OutlineInputBorder(),
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
                  Text(
                    l.whatCouldImprove,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: improveCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l.whatCouldImproveHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---------------- SAVE ----------------
            saved
                ? Center(
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          l.reflectionSaved,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: Text(l.saveReflection),
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
