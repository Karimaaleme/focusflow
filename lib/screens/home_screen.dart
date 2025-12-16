import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

import '../models/task.dart';
import '../models/user_profile.dart';
import '../models/ai_plan_item.dart';
import '../models/ai_plan_response.dart' hide AIPlanItem;


import '../services/api_service.dart';

import 'profile_screen.dart';
import 'kanban_screen.dart';
import 'analytics_screen.dart';
import 'calendar_screen.dart';
import 'ai_planner_screen.dart';
import 'focus_session_screen.dart';
import 'add_task_screen.dart';

import '../ai/ai_insights.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  final String email;
  final UserProfile? initialProfile;

  const HomeScreen({
    super.key,
    required this.token,
    required this.email,
    this.initialProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  String? error;

  UserProfile? profile;
  List<Task> tasks = [];
  AIPlanResponse? plan;

  // ✅ nullable → no startup crash
  AIInsight? insight;

  @override
  void initState() {
    super.initState();
    profile = widget.initialProfile;
    _load();
  }

  Future<void> _load() async {
    try {
      if (!mounted) return;
      setState(() {
        loading = true;
        error = null;
      });

      profile ??= await ApiService.loadProfile(widget.token, widget.email);
      tasks = await ApiService.getTasks(widget.token);

      try {
        plan = await ApiService.getAIPlan(widget.token);
      } catch (_) {
        plan = null;
      }

      try {
  insight = AIInsightsEngine.generate(
    tasks: tasks,
    profile: profile,
  );
} catch (e, s) {
  debugPrint("AIInsight error: $e");
  debugPrintStack(stackTrace: s);
  insight = null;
}

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }
Future<void> _logout() async {
  await FirebaseAuth.instance.signOut();

  if (!mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false, // 🔒 removes navigation history
  );
}

  // ---------------- helpers ----------------

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 18) return "Good afternoon";
    return "Good evening";
  }

  String _personaLine() {
    final t = (profile?.userType ?? "").toLowerCase();
    if (t.contains("student")) return "Focus on learning today 🎓";
    if (t.contains("employee")) return "Protect your deep work time 💼";
    if (t.contains("freelancer")) return "Ship meaningful progress 🚀";
    return "Build a focused day ✨";
  }

  int get completed => tasks.where((t) => t.isCompleted).length;

  double get progress => tasks.isEmpty ? 0 : completed / tasks.length;

  AIPlanItem? _firstBlock() {
    if (plan == null || plan!.items.isEmpty) return null;
    final e = plan!.items.first;
return AIPlanItem(
  title: e.title,
  startTime: e.startTime,
  endTime: e.endTime,
  estimatedMinutes: e.estimatedMinutes,
  reason: e.reason,
);

  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final initials =
        widget.email.isNotEmpty ? widget.email[0].toUpperCase() : "?";

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    final safeInsight = insight ??
        AIInsight(
          text: "You're ready. Pick one task and start small.",
          action: AIAction.openPlanner,
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF6F6F4),
        title: const Text("FocusFlow"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () async {
                final updated = await Navigator.push<UserProfile?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      profile: profile,
                      fallbackEmail: widget.email,
                      token: widget.token,
                    ),
                  ),
                );
                if (updated != null && mounted) {
                  setState(() => profile = updated);
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundImage: profile?.profileImageBytes != null
                    ? MemoryImage(profile!.profileImageBytes!)
                    : null,
                child:
                    profile?.profileImageBytes == null ? Text(initials) : null,
              ),
            ),
        
          ),
          //LOGOUT BUTTON (NEW)
  IconButton(
    icon: const Icon(Icons.logout),
    tooltip: "Logout",
    onPressed: _logout,
  ),
        ],
        
      ),

      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(
              title: "${_greeting()}, ${widget.email.split('@').first}",
              subtitle: _personaLine(),
              chip: profile?.userType ?? "Other",
            ),
            const SizedBox(height: 16),
            _FocusRing(progress: progress),
            const SizedBox(height: 16),
            _InsightCard(
              insight: safeInsight,
              onApply: () {
                if (safeInsight.action == AIAction.openPlanner) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AIPlannerScreen(token: widget.token),
                    ),
                  );
                  return;
                }

                if (safeInsight.action == AIAction.quickFocus) {
                  final block = _firstBlock();

                  if (block == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No plan yet. Opening planner."),
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AIPlannerScreen(token: widget.token),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FocusSessionScreen(
                        block: block,
                        token: widget.token,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            _QuickActions(
              onPlanner: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AIPlannerScreen(token: widget.token),
                ),
              ),
              onKanban: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      KanbanScreen(token: widget.token, profile: profile),
                ),
              ),
              onAnalytics: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnalyticsScreen(token: widget.token),
                ),
              ),
              onCalendar: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CalendarScreen(token: widget.token),
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTaskScreen(token: widget.token),
            ),
          );

          if (created == true) {
            _load();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/* ================= UI COMPONENTS ================= */

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final String chip;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _Chip(text: chip),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _FocusRing extends StatelessWidget {
  final double progress;

  const _FocusRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return _Card(
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                ),
                Center(
                  child: Text(
                    "$percent%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              "Daily focus progress\nStay consistent.",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AIInsight insight;
  final VoidCallback onApply;

  const _InsightCard({
    required this.insight,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "AI Insight",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(insight.text),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onApply,
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onPlanner;
  final VoidCallback onKanban;
  final VoidCallback onAnalytics;
  final VoidCallback onCalendar;

  const _QuickActions({
    required this.onPlanner,
    required this.onKanban,
    required this.onAnalytics,
    required this.onCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Action(icon: Icons.auto_awesome, label: "Planner", onTap: onPlanner),
        _Action(icon: Icons.view_kanban, label: "Kanban", onTap: onKanban),
        _Action(icon: Icons.insights, label: "Analytics", onTap: onAnalytics),
        _Action(
          icon: Icons.calendar_month,
          label: "Calendar",
          onTap: onCalendar,
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: _Card(
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
