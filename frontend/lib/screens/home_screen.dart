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
import '../services/group_service.dart'; // Added

import 'profile_screen.dart';
import 'kanban_screen.dart';
import 'analytics_screen.dart';
import 'calendar_screen.dart';
import 'ai_planner_screen.dart';
import 'focus_session_screen.dart';
import 'add_task_screen.dart';
import 'focus_setup_screen.dart';
import 'study_together_screen.dart';
import 'username_setup_screen.dart';
import 'chatbot_screen.dart'; // NEW

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
  int _pendingInvites = 0; // Added

  @override
  void initState() {
    super.initState();
    profile = widget.initialProfile;
    _load();
  }

  Future<void> _load() async {
    try {
      print("🏠 HomeScreen: Starting Load...");
      if (!mounted) return;
      setState(() {
        loading = true;
        error = null;
      });

      print("🏠 HomeScreen: Checking Profile...");
      profile ??= await ApiService.loadProfile(widget.email);
      print("🏠 HomeScreen: Profile OK. Fetching Tasks...");
      
      tasks = await ApiService.getTasks();
      print("🏠 HomeScreen: Tasks OK (${tasks.length}). Fetching AI Plan...");

      try {
        plan = await ApiService.getAIPlan();
        print("🏠 HomeScreen: AI Plan OK.");
      } catch (e) {
        print("⚠️ HomeScreen: AI Plan Failed: $e");
        plan = null;
      }

      print("🏠 HomeScreen: Generating Insights...");
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
          // ... existing theme logic ...
      }

      print("🏠 HomeScreen: Checking Invites...");
      // Check Invitations
      try {
        final invites = await GroupService().getInvitations();
        _pendingInvites = invites.length;
        print("🏠 HomeScreen: Invites OK ($_pendingInvites).");
      } catch (e) {
        debugPrint("Failed to load invites: $e");
        _pendingInvites = 0;
      }

      print("🏠 HomeScreen: Load Complete. Updating UI.");
      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      print("❌ HomeScreen: Critical Error: $e");
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "fab_chatbot",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatbotScreen()),
              ).then((_) => _load()); // Refresh in case tasks were created
            },
            backgroundColor: theme.colorScheme.primary,
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "fab_add_task",
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
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false, 
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 8),
                Text("FocusFlow", style: TextStyle(color: theme.colorScheme.onBackground, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            actions: [
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
                    radius: 18,
                    backgroundImage: profile?.profileImageBytes != null
                        ? MemoryImage(profile!.profileImageBytes!)
                        : null,
                    child: profile?.profileImageBytes == null
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout, color: Colors.grey[500]),
                  onPressed: _logout,
                ),
                const SizedBox(width: 8),
            ],
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  // NEW HEADER SECTION
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         children: [
                           Text(
                            _greeting(),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 24,
                              color: theme.colorScheme.onBackground.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _greeting().contains("morning") ? "☀️" : _greeting().contains("afternoon") ? "👋" : "🌙",
                            style: const TextStyle(fontSize: 24),
                          )
                         ],
                       ),
                       const SizedBox(height: 4),
                       Text(
                         (profile?.fullName != null && profile!.fullName!.isNotEmpty)
                            ? profile!.fullName!
                            : (profile?.username ?? FirebaseAuth.instance.currentUser?.displayName ?? 'User'),
                         style: theme.textTheme.displaySmall?.copyWith(
                           fontWeight: FontWeight.bold,
                           fontSize: 32,
                           color: theme.colorScheme.onBackground,
                           height: 1.1,
                         ),
                       ),
                       const SizedBox(height: 8),
                       Text(
                        _getPersonalizedSubtitle(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  _buildPulseGradientCard(theme, safeInsight),
                  const SizedBox(height: 24),
                  if (_pendingInvites > 0) ...[
                    // Notification Banner
                    GestureDetector(
                      onTap: () async {
                         await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StudyTogetherScreen()),
                        );
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "New Study Invites!",
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  Text(
                                    "You have $_pendingInvites pending invitations.",
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "AI Insight",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              // Decorative dot
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          if (insight.action != AIAction.none)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _handleAction(insight.action),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Icon(Icons.bolt_rounded, size: 20),
                     SizedBox(width: 8),
                     Text("Take Action", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
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
    final isFocus = theme.primaryColor == const Color(0xFF00F0FF); // Check if focus theme

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isFocus ? theme.cardTheme.color : Colors.white, // In light mode, ensure white base
        gradient: isFocus 
           ? null 
           : LinearGradient(colors: [Colors.white, const Color(0xFFF3F6FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32), // More rounded
        boxShadow: [
          if (isFocus) 
            BoxShadow(color: theme.primaryColor.withOpacity(0.15), blurRadius: 20, spreadRadius: 0),
          if (!isFocus)
            BoxShadow(
              color: const Color(0xFFE0E5EC),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
        border: Border.all(
          color: isFocus ? theme.primaryColor.withOpacity(0.1) : Colors.white,
          width: 1
        )
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
                  value: 1, 
                  strokeWidth: 8,
                  color: theme.dividerColor.withOpacity(0.1), 
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: isFocus ? theme.primaryColor : theme.colorScheme.secondary,
                  // Add a glow in custom painter if needed, but color change is a start
                ),
                Center(
                  child: Text(
                    "$perc%",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isFocus ? theme.primaryColor : theme.colorScheme.secondary,
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
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "$completed",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "/ ${tasks.length}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                Text(
                  "Tasks Completed",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
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
    // Logical Order:
    // Row 1 (Planning): Kanban | Calendar
    // Row 2 (Action): Focus Zone | Study Together
    // Row 3 (Insights): Smart Plan | Analytics
    
    const double cardHeight = 140;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionCard(
                context,
                icon: Icons.view_kanban_outlined,
                label: "Kanban",
                subtitle: "Tasks",
                color: const Color(0xFFFF9E00), // Orange
                height: cardHeight,
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionCard(
                context,
                icon: Icons.calendar_month_outlined,
                label: "Calendar",
                subtitle: "Schedule",
                color: Colors.purple,
                height: cardHeight,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CalendarScreen()),
                  );
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                context,
                icon: Icons.timer_outlined,
                label: "Focus Zone",
                subtitle: "Start Flow",
                color: const Color(0xFFF72585), // Vibrant Pink
                height: cardHeight,
                isPrimary: true, // Focus is key action
                onTap: () async {
                  await _handleAction(AIAction.quickFocus);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionCard(
                context,
                icon: Icons.group_work_outlined,
                label: "Study Together",
                subtitle: "Join Rooms",
                color: const Color(0xFF7209B7), // Deep Purple
                badgeCount: _pendingInvites > 0 ? _pendingInvites : null,
                height: cardHeight,
                isPrimary: true, 
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StudyTogetherScreen()),
                  );
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                context,
                icon: Icons.psychology_outlined,
                label: "Smart Plan",
                subtitle: "AI Assistant",
                color: const Color(0xFF4361EE), // Vibrant Blue
                height: cardHeight,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AIPlannerScreen()),
                  );
                  _load(); 
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionCard(
                context,
                icon: Icons.auto_graph_outlined,
                label: "Analytics",
                subtitle: "Insights",
                color: const Color(0xFF4CC9F0), // Cyan
                height: cardHeight,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AnalyticsScreen()),
                  );
                  _load();
                },
              ),
            ),
          ],
        ),
        // Add padding at bottom so FAB doesn't cover anything
        const SizedBox(height: 100), 
      ],
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    int? badgeCount,
    double height = 120,
    bool isPrimary = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isFocus = theme.primaryColor == const Color(0xFF00F0FF); 
    
    Color bgColor;
    Color iconColor;
    Color textColor;
    BoxBorder? border;
    List<BoxShadow>? shadows;
    LinearGradient? gradient;

    if (isFocus) {
      // Focus Mode (Dark Neon)
      if (isPrimary) {
        gradient = LinearGradient(
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        bgColor = Colors.transparent;
        iconColor = color; // Use the specific card color for variety in Focus mode too? Or stick to Neon Cyan?
        // User liked "Neon accents". Let's mix theme primary + card color.
        iconColor = Color.lerp(theme.primaryColor, color, 0.5)!;
        textColor = Colors.white;
        border = Border.all(color: iconColor.withOpacity(0.5));
        shadows = [
          BoxShadow(color: iconColor.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4))
        ];
      } else {
        bgColor = const Color(0xFF1A1A1A);
        iconColor = color.withOpacity(0.9);
        textColor = Colors.white70;
        border = Border.all(color: Colors.white10);
      }
    } else {
       // Light / Calm Mode
       // Make them look like soft, premium "Generic" cards or "Apple" style.
       bgColor = theme.cardTheme.color!;
       // Add a very subtle gradient overlay
       gradient = LinearGradient(
         colors: [
           color.withOpacity(0.08),
           color.withOpacity(0.02),
         ],
         begin: Alignment.topLeft,
         end: Alignment.bottomRight,
       );
       
       iconColor = color;
       textColor = theme.textTheme.titleMedium?.color ?? Colors.black87;
       border = Border.all(color: color.withOpacity(0.05)); // Subtle colored border
       shadows = [
         BoxShadow(
           color: color.withOpacity(0.05),
           blurRadius: 10,
           offset: const Offset(0, 5),
         )
       ];
    }

    return Material(
      color: Colors.transparent, 
      child: InkWell(
        onTap: () {
          debugPrint("Home Action Tapped: $label");
          onTap();
        },
        borderRadius: BorderRadius.circular(28), // Softer corners
        child: Container(
          height: height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: gradient == null ? bgColor : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            border: border,
            boxShadow: shadows,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isFocus ? Colors.black45 : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                      if (isPrimary)
                        Icon(Icons.arrow_forward_rounded, color: iconColor.withOpacity(0.5), size: 20),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: textColor,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]
                ],
              ),
              if (badgeCount != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30), // Apple Red
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: Text(
                      badgeCount > 9 ? "9+" : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
