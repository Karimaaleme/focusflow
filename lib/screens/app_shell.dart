import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import 'home_screen.dart';
import 'ai_planner_screen.dart';
import 'kanban_screen.dart';
import 'analytics_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

enum AppTab { home, planner, kanban, analytics, calendar, profile }

class AppShell extends StatelessWidget {
  final String token;
  final String email;
  final UserProfile? profile;

  final AppTab current;
  final Widget child;

  /// Optional: pass a FAB (e.g., Add Task)
  final Widget? floatingActionButton;

  const AppShell({
    super.key,
    required this.token,
    required this.email,
    required this.profile,
    required this.current,
    required this.child,
    this.floatingActionButton,
  });

  void _go(BuildContext context, AppTab tab) {
    if (tab == current) return;

    Widget page;
    switch (tab) {
      case AppTab.home:
        page = HomeScreen(token: token, email: email, initialProfile: profile);
        break;
      case AppTab.planner:
        page = AIPlannerScreen(token: token);
        break;
      case AppTab.kanban:
        page = KanbanScreen(token: token, profile: profile);
        break;
      case AppTab.analytics:
        page = AnalyticsScreen(token: token);
        break;
      case AppTab.calendar:
        page = CalendarScreen(token: token);
        break;
      case AppTab.profile:
        page = ProfileScreen(profile: profile, fallbackEmail: email, token: token);
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = email.isNotEmpty ? email[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              current: current,
              initials: initials,
              avatar: profile?.profileImageBytes != null
                  ? MemoryImage(profile!.profileImageBytes!)
                  : null,
              onSelect: (tab) => _go(context, tab),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final AppTab current;
  final String initials;
  final ImageProvider? avatar;
  final ValueChanged<AppTab> onSelect;

  const _Sidebar({
    required this.current,
    required this.initials,
    required this.avatar,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      margin: const EdgeInsets.fromLTRB(14, 10, 0, 10),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          const Icon(Icons.bubble_chart, size: 26),
          const SizedBox(height: 14),

          _NavIcon(
            icon: Icons.home_rounded,
            selected: current == AppTab.home,
            onTap: () => onSelect(AppTab.home),
            tooltip: "Home",
          ),
          _NavIcon(
            icon: Icons.auto_awesome_rounded,
            selected: current == AppTab.planner,
            onTap: () => onSelect(AppTab.planner),
            tooltip: "Planner",
          ),
          _NavIcon(
            icon: Icons.view_kanban_rounded,
            selected: current == AppTab.kanban,
            onTap: () => onSelect(AppTab.kanban),
            tooltip: "Kanban",
          ),
          _NavIcon(
            icon: Icons.insights_rounded,
            selected: current == AppTab.analytics,
            onTap: () => onSelect(AppTab.analytics),
            tooltip: "Analytics",
          ),
          _NavIcon(
            icon: Icons.calendar_month_rounded,
            selected: current == AppTab.calendar,
            onTap: () => onSelect(AppTab.calendar),
            tooltip: "Calendar",
          ),

          const Spacer(),

          GestureDetector(
            onTap: () => onSelect(AppTab.profile),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.06),
                image: avatar != null ? DecorationImage(image: avatar!, fit: BoxFit.cover) : null,
              ),
              child: avatar == null
                  ? Center(
                      child: Text(
                        initials,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 54,
            height: 46,
            decoration: BoxDecoration(
              color: selected ? Colors.black.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? Colors.black.withValues(alpha: 0.10)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? Colors.black87 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
