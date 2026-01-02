import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';

import '../models/task.dart';
import '../models/user_profile.dart';
import '../models/ai_plan_item.dart';
import '../models/ai_plan_response.dart' hide AIPlanItem;
import '../widgets/reminder_banner.dart';


import '../theme/theme_provider.dart';
import '../services/api_service.dart';

import 'profile_screen.dart';
import 'kanban_screen.dart';
import 'analytics_screen.dart';
import 'calendar_screen.dart';
import 'ai_planner_screen.dart';
import 'focus_session_screen.dart';
import 'add_task_screen.dart';
import 'focus_setup_screen.dart'; // Added

import '../ai/ai_insights.dart';

class HomeScreen extends StatefulWidget {
  final String email;
  final UserProfile? initialProfile;

  const HomeScreen({
    super.key,
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

      profile ??= await ApiService.loadProfile(widget.email);
      tasks = await ApiService.getTasks();

      try {
        plan = await ApiService.getAIPlan();
      } catch (_) {
        plan = null;
      }

      try {
        insight = AIInsightsEngine.generate(
          tasks: tasks,
          profile: profile,
        );
      } catch (e) {
        insight = null;
      }

      // Update Theme from Profile
      if (profile != null) {
          // Priority: themeMode (system/light/dark) -> overrides 'theme' kind of?
          // Actually, 'theme' has 'focus', 'calm'.
          // Let's use 'theme' as the primary mode if set to Focus/Calm, 
          // else use themeMode.
          
          String mode = 'light';
          
          if (profile!.theme == 'focus') mode = 'focus';
          else if (profile!.theme == 'calm') mode = 'calm';
          else if (profile!.themeMode != null && profile!.themeMode != 'system') {
            mode = profile!.themeMode!;
          } else if (profile!.theme == 'dark') {
            mode = 'dark'; // legacy
          }
          
          // Using ThemeProvider (import it)
          ThemeProvider.instance.update(mode: mode, accent: profile!.accentColor);
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
      (_) => false,
    );
  }

  // ---------------- getters ----------------

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 18) return "Good afternoon";
    return "Good evening";
  }

  String _getPersonalizedSubtitle() {
    final type = profile?.userType ?? "";
    if (type == "Student") return "Ready to ace your goals?";
    if (type == "Employee") return "Let's crush your tasks.";
    if (type == "Freelancer") return "Your business, your flow.";
    return "Let's be productive today.";
  }

  int get completed => tasks.where((t) => t.isCompleted).length;
  double get progress => tasks.isEmpty ? 0 : completed / tasks.length;

  Task? _getTopNotification() {
    // 1. Filter out completed
    final active = tasks.where((t) => !t.isCompleted).toList();
    if (active.isEmpty) return null;

    final now = DateTime.now();
    // 2. Sort by urgency: Overdue > Today > Priority
    active.sort((a, b) {
      // Overdue check
      bool aOver = a.dueDatetime != null && a.dueDatetime!.isBefore(now);
      bool bOver = b.dueDatetime != null && b.dueDatetime!.isBefore(now);
      if (aOver != bOver) return aOver ? -1 : 1;

      // Due Today check
      bool aToday = a.dueDatetime != null && _isSameDay(a.dueDatetime!, now);
      bool bToday = b.dueDatetime != null && _isSameDay(b.dueDatetime!, now);
      if (aToday != bToday) return aToday ? -1 : 1;

      // Priority check (High > Med > Low)
      final pMap = {"high": 3, "medium": 2, "low": 1};
      int aP = pMap[a.priority.toLowerCase()] ?? 2;
      int bP = pMap[b.priority.toLowerCase()] ?? 2;
      return bP.compareTo(aP);
    });

    // Return top task if it's urgent (overdue, today, or high priority)
    final top = active.first;
    bool isUrgent = (top.dueDatetime != null && top.dueDatetime!.isBefore(now.add(const Duration(hours: 24)))) || 
                    top.priority.toLowerCase() == 'high';
    
    return isUrgent ? top : null;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _handleDelay(Task task, Duration duration) async {
    try {
      final newDue = (task.dueDatetime ?? DateTime.now()).add(duration);
      final updated = task.copyWith(dueDatetime: newDue);
      
      await ApiService.updateTask(
        id: updated.id,
        title: updated.title,
        description: updated.description,
        status: updated.status,
        category: updated.category,
        priority: updated.priority,
        estimatedMinutes: updated.estimatedMinutes,
        actualMinutes: updated.actualMinutes,
        dueDatetime: updated.dueDatetime,
        reminderDateTime: updated.reminderDateTime,
        isRecurring: updated.isRecurring,
        recurrence: updated.recurrence,
        recurrenceInterval: updated.recurrenceInterval,
        subtasks: updated.subtasks,
      );
      _load(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delayed '${task.title}' by ${duration.inHours}h")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delay: $e")),
        );
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text("Retry")),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _logout,
                child: const Text("Logout (Fix Auth)"),
              ),
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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddTaskScreen()),
          );
          if (res == true) _load();
        },
        icon: const Icon(Icons.add_task),
        label: const Text("Add Task"),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 80,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_greeting()}, ${(profile?.fullName != null && profile!.fullName!.isNotEmpty) ? profile!.fullName! : (profile?.email.split('@').first ?? 'User')}",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getPersonalizedSubtitle(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final p = await Navigator.push<UserProfile?>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          profile: profile,
                          fallbackEmail: widget.email,
                        ),
                      ),
                    );
                    if (p != null) setState(() => profile = p);
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: profile?.profileImageBytes != null
                        ? MemoryImage(profile!.profileImageBytes!)
                        : null,
                    child: profile?.profileImageBytes == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
              ],
            ),
            actions: [
               IconButton(
                  icon: Icon(Icons.logout, color: Colors.grey[500]),
                  onPressed: _logout,
                ),
                const SizedBox(width: 8),
            ],
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildPulseGradientCard(theme, safeInsight),
                  const SizedBox(height: 24),
                  if (_getTopNotification() != null) ...[
                    ReminderBanner(task: _getTopNotification()!, onDelay: _handleDelay),
                    const SizedBox(height: 24),
                  ],
                  _buildFocusRing(theme),
                  const SizedBox(height: 24),
                  const Text(
                    "QUICK ACCESS",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGridActions(context),
                  const SizedBox(height: 100), // Spacing for FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseGradientCard(ThemeData theme, AIInsight insight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary, // Ensure tertiary exisits or use secondary
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "AI Insight",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (insight.action != AIAction.none)
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: () => _handleAction(insight.action),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Take Action"),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(AIAction action) async {
    if (action == AIAction.openPlanner) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const AIPlannerScreen()),
      );
    } else if (action == AIAction.quickFocus) {
      // User wants to choose a task and focus
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const FocusSetupScreen(),
        ),
      );
      if (res == true && mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Focus session logged! stats updated.")),
        );
      }
    }
  }

  Widget _buildFocusRing(ThemeData theme) {
    final perc = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // Softer shadow
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 100,
            width: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1, // Full ring background
                  strokeWidth: 8,
                  color: theme.dividerColor.withOpacity(0.1), // Dynamic grey
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: theme.colorScheme.secondary,
                ),
                Center(
                  child: Text(
                    "$perc%",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "$completed",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      " / ${tasks.length}",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                Text(
                  "Tasks Completed",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _actionCard(
              context,
              icon: Icons.calendar_month_outlined,
              label: "Calendar",
              color: Colors.purple,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CalendarScreen()),
                );
                _load();
              },
            ),
            _actionCard(
              context,
              icon: Icons.view_kanban_outlined,
              label: "Kanban",
              color: Colors.orange,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        KanbanScreen(profile: profile),
                  ),
                );
                _load();
              },
            ),
             _actionCard(
              context,
              icon: Icons.auto_graph_outlined,
              label: "Analytics",
              color: Colors.teal,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AnalyticsScreen()),
                );
                _load();
              },
            ),
            _actionCard(
              context,
              icon: Icons.psychology_outlined,
              label: "Smart Plan",
              color: Colors.indigo,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AIPlannerScreen()),
                );
                _load(); // In case plan changes
              },
            ),
             _actionCard(
              context,
              icon: Icons.timer_outlined,
              label: "Focus",
              color: Colors.pinkAccent,
              onTap: () async {
                await _handleAction(AIAction.quickFocus);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _actionCard(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color ?? theme.cardColor, // Dynamic
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: () {
          debugPrint("Home Action Tapped: $label");
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  // Color will adapt from textTheme (White in dark, Black in light)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
