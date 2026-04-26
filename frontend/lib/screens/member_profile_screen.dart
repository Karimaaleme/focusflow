import 'package:flutter/material.dart';
import '../services/group_service.dart';
import '../services/private_message_service.dart';
import 'private_chat_screen.dart';

class MemberProfileScreen extends StatefulWidget {
  final int userId;
  final String displayName;
  final String email;

  const MemberProfileScreen({
    super.key,
    required this.userId,
    required this.displayName,
    required this.email,
  });

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final _groupService = GroupService();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId <= 0) {
      setState(() => _loading = false);
      return;
    }
    try {
      final stats = await _groupService.getMemberStats(widget.userId);
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _initials {
    final name = widget.displayName;
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text('Profile',
                      style: TextStyle(color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6C63FF),
                            const Color(0xFF3D3BF3),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(_initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name + status
                    Text(widget.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (_stats?['is_focusing'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.5)),
                        ),
                        child: const Text('🔥 Currently Focusing',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      )
                    else if (_stats?['user_type'] != null)
                      Text(
                        _stats!['user_type'] as String,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      )
                    else
                      const SizedBox.shrink(),

                    if (_stats?['bio'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _stats!['bio'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 14, height: 1.5),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Stats grid
                    if (_loading)
                      const CircularProgressIndicator(color: Colors.white54)
                    else if (_stats != null)
                      _StatsGrid(stats: _stats!),

                    const SizedBox(height: 28),

                    // Message button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Track conversation for inbox
                          await PrivateMessageService.markConversation(
                            widget.email,
                            widget.displayName,
                          );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrivateChatScreen(
                                otherEmail: widget.email,
                                otherName: widget.displayName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.message_rounded),
                        label: Text('Message ${widget.displayName.split(' ').first}'),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalMins = (stats['total_focus_minutes'] as num?)?.toInt() ?? 0;
    final sessions = (stats['focus_sessions_count'] as num?)?.toInt() ?? 0;
    final completed = (stats['completed_tasks'] as num?)?.toInt() ?? 0;
    final avg = (stats['avg_session_minutes'] as num?)?.toDouble() ?? 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
            label: 'Focus Time',
            value: '${totalMins}m',
            icon: Icons.timer_rounded,
            color: const Color(0xFF6C63FF)),
        _StatCard(
            label: 'Sessions',
            value: '$sessions',
            icon: Icons.bolt_rounded,
            color: Colors.orange),
        _StatCard(
            label: 'Tasks Done',
            value: '$completed',
            icon: Icons.check_circle_rounded,
            color: Colors.green),
        _StatCard(
            label: 'Avg Session',
            value: '${avg.round()}m',
            icon: Icons.bar_chart_rounded,
            color: Colors.teal),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
