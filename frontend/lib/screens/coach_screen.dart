import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chatbot_screen.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.getDailyInsight();
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0C29),
                  Color(0xFF302B63),
                  Color(0xFF24243E),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: _loading
                      ? _buildLoading()
                      : _error != null
                          ? _buildError()
                          : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            AppLocalizations.of(context).aiCoachTitle,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
          const LanguageToggleButton(onGradient: true),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 20),
          Builder(builder: (ctx) => Text(AppLocalizations.of(ctx).analyzingProductivity,
              style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).couldNotLoadCoaching,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF)),
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final personality = d['personality'] as String? ?? 'balanced';
    final burnoutScore = (d['burnout_score'] as num?)?.toInt() ?? 0;
    final burnoutRisk = d['burnout_risk'] as String? ?? 'low';
    final personalityLabel = d['personality_label'] as String? ?? personality;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          _GreetingCard(
            greeting: d['greeting'] as String? ?? 'Hello!',
            personality: personality,
            personalityLabel: personalityLabel,
          ),
          const SizedBox(height: 16),

          // Burnout Indicator
          _BurnoutCard(score: burnoutScore, risk: burnoutRisk),
          const SizedBox(height: 16),

          // Week Summary
          _InsightCard(
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF6C63FF),
            title: AppLocalizations.of(context).yourWeekLabel,
            body: d['summary'] as String? ?? '',
          ),
          const SizedBox(height: 12),

          // Main Insight
          _InsightCard(
            icon: Icons.lightbulb_rounded,
            color: Colors.amber.shade600,
            title: AppLocalizations.of(context).keyInsightLabel,
            body: d['main_insight'] as String? ?? '',
          ),
          const SizedBox(height: 12),

          // Today's Suggestion
          _InsightCard(
            icon: Icons.rocket_launch_rounded,
            color: Colors.teal.shade400,
            title: AppLocalizations.of(context).todaysActionLabel,
            body: d['suggestion'] as String? ?? '',
            highlighted: true,
          ),
          const SizedBox(height: 12),

          // Encouragement
          _EncouragementCard(text: d['encouragement'] as String? ?? ''),
          const SizedBox(height: 24),

          // CTA — open chatbot
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatbotScreen()),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: Text(AppLocalizations.of(context).chatWithAI),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Greeting Card ────────────────────────────────────────────────────────────

class _GreetingCard extends StatelessWidget {
  final String greeting;
  final String personality;
  final String personalityLabel;

  const _GreetingCard({
    required this.greeting,
    required this.personality,
    required this.personalityLabel,
  });

  static const _badges = {
    'procrastinator': ('⏰', 'Getting Started', Color(0xFFFF6B6B)),
    'consistent': ('🔥', 'Consistent Achiever', Color(0xFF4CAF50)),
    'distracted': ('🧠', 'Finding Focus', Color(0xFFFF9800)),
    'overachiever': ('⚡', 'High Performer', Color(0xFF9C27B0)),
    'balanced': ('✨', 'Well Balanced', Color(0xFF2196F3)),
  };

  @override
  Widget build(BuildContext context) {
    final badge = _badges[personality] ?? _badges['balanced']!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badge.$3.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: badge.$3.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(badge.$1,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      badge.$2,
                      style: TextStyle(
                          color: badge.$3,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            greeting,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ─── Burnout Card ─────────────────────────────────────────────────────────────

class _BurnoutCard extends StatelessWidget {
  final int score;
  final String risk;

  const _BurnoutCard({required this.score, required this.risk});

  Color get _riskColor {
    switch (risk) {
      case 'high':
        return Colors.red.shade400;
      case 'moderate':
        return Colors.orange.shade400;
      default:
        return Colors.green.shade400;
    }
  }

  String _riskLabel(AppLocalizations l) {
    switch (risk) {
      case 'high': return l.burnoutRiskHigh;
      case 'moderate': return l.burnoutRiskModerate;
      default: return l.burnoutRiskLow;
    }
  }

  String get _riskEmoji {
    switch (risk) {
      case 'high':
        return '🚨';
      case 'moderate':
        return '⚠️';
      default:
        return '✅';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _riskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _riskColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: _riskColor,
                  strokeWidth: 6,
                ),
                Text(
                  '$score',
                  style: TextStyle(
                      color: _riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_riskEmoji Burnout Risk: ${_riskLabel(l)}',
                  style: TextStyle(
                      color: _riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  score < 35
                      ? l.burnoutManagingWell
                      : score < 65
                          ? l.burnoutWatchPace
                          : l.burnoutTakeAction,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Insight Card ─────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool highlighted;

  const _InsightCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withOpacity(0.12)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: highlighted
            ? Border.all(color: color.withOpacity(0.5))
            : Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Encouragement Card ───────────────────────────────────────────────────────

class _EncouragementCard extends StatelessWidget {
  final String text;
  const _EncouragementCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.3),
            const Color(0xFF3D3BF3).withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Text('💬', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
