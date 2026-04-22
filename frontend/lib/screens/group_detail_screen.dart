import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/group_service.dart';
import '../services/api_service.dart';
import '../services/focus_presence_service.dart';
import '../services/group_chat_service.dart';
import 'focus_session_screen.dart';
import 'group_chat_screen.dart';
import '../models/ai_plan_item.dart';

class GroupDetailScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _groupService = GroupService();
  Map<String, dynamic>? _groupDetails;
  bool _loading = true;
  int? _currentUserId; // To check permissions

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
         // Optionally load full profile if needed, but we just need email to match for now
         // final profile = await ApiService.loadProfile(user.email!);
         if (mounted) {
           setState(() {
             // Trigger rebuild to check matching email
           });
         }
      }
    } catch (e) {
      debugPrint("Error loading user: $e");
    }
  }

  Future<void> _loadDetails() async {
    setState(() => _loading = true);
    try {
      final details = await _groupService.getGroupDetails(widget.groupId);
      // Fetch Analytics
      Map<String, dynamic>? analytics;
      try {
        analytics = await _groupService.getGroupAnalytics(widget.groupId);
      } catch (e) {
        debugPrint("Analytics error: $e");
      }

      if (mounted) {
        setState(() {
          _groupDetails = details;
          if (analytics != null) {
            _groupDetails!['analytics'] = analytics;
          }
          
          // Determine My ID
          final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
          if (currentUserEmail != null) {
             final members = (_groupDetails?['members'] as List? ?? []);
             final me = members.firstWhere((m) => m['user']['email'] == currentUserEmail, orElse: () => null);
             if (me != null) {
               _currentUserId = me['user']['id'];
             }
          }
        });
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _inviteUser() async {
    final controller = TextEditingController();
    
    // Custom stylish bottom sheet for invite
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Invite a Member",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter the exact username to invite them to '${widget.groupName}'",
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Username",
                  filled: true,
                  fillColor: Colors.indigo.shade50.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.person_search_rounded, color: Colors.indigo),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await _groupService.inviteUser(widget.groupId, controller.text.trim());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Invitation sent!"),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          )
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Send Invitation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeMember(int userId, String username) async {
    // Optimistic UI Update: Remove immediately from list
    final memberIndex = (_groupDetails?['members'] as List).indexWhere((m) => m['user']['id'] == userId);
    final backupMember = memberIndex != -1 ? (_groupDetails?['members'] as List)[memberIndex] : null;

    setState(() {
      if (memberIndex != -1) {
        (_groupDetails?['members'] as List).removeAt(memberIndex);
      }
    });

    try {
      await _groupService.removeMember(widget.groupId, userId);
      // Success
    } catch (e) {
      // Revert if failed
      if (mounted && backupMember != null) {
        setState(() {
           (_groupDetails?['members'] as List).insert(memberIndex, backupMember);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
  
  Future<void> _leaveGroup() async {
    if (_currentUserId == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Leave Group?"),
        content: const Text("Are you sure you want to leave? You will need an invite to rejoin."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Leave", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
       try {
        await _groupService.removeMember(widget.groupId, _currentUserId!);
        if (mounted) {
           Navigator.pop(context); // Close screen
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You left the group")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Group?"),
        content: const Text("This action cannot be undone. All history and data will be lost."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
       try {
        await _groupService.deleteGroup(widget.groupId);
        if (mounted) {
           Navigator.pop(context); // Close screen
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group deleted")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _showRenameGroupDialog() async {
    final controller = TextEditingController(text: widget.groupName);
    final descController = TextEditingController(text: _groupDetails?['description'] ?? "");

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Group"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextField(controller: controller, decoration: const InputDecoration(labelText: "Group Name")),
             TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _groupService.updateGroup(widget.groupId, controller.text, descController.text);
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group updated!")));
                   _loadDetails(); 
                 }
              } catch (e) {
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0C29),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    
    // Premium background
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: const Text(""), // Custom header handles title
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupChatScreen(
                  groupId: widget.groupId,
                  groupName: widget.groupName,
                ),
              ),
            ),
            tooltip: "Group Chat",
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add, color: Colors.white, size: 20),
            ),
            onPressed: _inviteUser,
            tooltip: "Invite Member",
          ),
           // Group Options Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'leave') _leaveGroup();
              if (value == 'delete') _deleteGroup();
            },
            itemBuilder: (context) {
              final isOwner = _currentUserId != null && _groupDetails?['owner_id'] == _currentUserId;
              return [
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.black87),
                      SizedBox(width: 8),
                      Text("Leave Group"),
                    ],
                  ),
                ),
                if (isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Delete Group", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ];
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. Hero Header Background
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 280,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6A11CB), // Rich Purple
                          Color(0xFF2575FC), // Vibrant Blue
                        ],
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                    ),
                    child: Stack(
                      children: [
                         // Decorative glowing circles
                         Positioned(
                           top: -50,
                           left: -50,
                           child: Container(
                             width: 200,
                             height: 200,
                             decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.1),
                               shape: BoxShape.circle,
                               boxShadow: [
                                 BoxShadow(
                                   color: Colors.white.withOpacity(0.1),
                                   blurRadius: 50,
                                   spreadRadius: 10,
                                 )
                               ]
                             ),
                           ),
                         ),
                      ],
                    ),
                  ),
                ),

                // 2. Content
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // Header Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.groupName,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (_currentUserId != null && _groupDetails?['owner_id'] == _currentUserId)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                                    onPressed: _showRenameGroupDialog,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _groupDetails?['description'] ?? "Studying together",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                             Row(
                               children: [
                                 _buildStatBadge(
                                   icon: Icons.people, 
                                   text: "${(_groupDetails?['members'] as List? ?? []).length} Members"
                                 ),
                                 const SizedBox(width: 12),
                                 _buildStatBadge(
                                   icon: Icons.calendar_today, 
                                   text: "Since ${_groupDetails?['created_at'].toString().split('T')[0]}"
                                 ),
                               ],
                             ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),

                      // Phase 4: Leaderboard & Analytics
                      _buildAnalyticsSection(),
                      
                      // Members List
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 12),
                                child: Text(
                                  "GROUP MEMBERS",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final members = (_groupDetails?['members'] as List? ?? []);
                                    // Sort members by minutes (high to low)
                                    final sortedMembers = List<Map<String, dynamic>>.from(members);
                                    sortedMembers.sort((a, b) {
                                      final minsA = _validMinutes(a);
                                      final minsB = _validMinutes(b);
                                      return minsB.compareTo(minsA); // Descending
                                    });

                                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                      stream: FocusPresenceService.presenceStream(widget.groupId),
                                      builder: (context, snapshot) {
                                        final presenceMap = <String, Map<String, dynamic>>{};
                                        if (snapshot.hasData) {
                                          for (final doc in snapshot.data!.docs) {
                                            final data = doc.data();
                                            final email = data['email'] as String?;
                                            if (email != null) presenceMap[email] = data;
                                          }
                                        }
                                        return ListView.builder(
                                          padding: const EdgeInsets.only(bottom: 100),
                                          itemCount: sortedMembers.length,
                                          itemBuilder: (context, index) {
                                            final member = sortedMembers[index];
                                            final email = member['user']?['email'] as String?;
                                            final presence = email != null ? presenceMap[email] : null;
                                            return _buildMemberCard(member, index + 1, presence: presence);
                                          },
                                        );
                                      },
                                    );
                                  }
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
       floatingActionButton: _groupDetails != null ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FocusSessionScreen(
                block: AIPlanItem(
                  title: "Group Session: ${widget.groupName}",
                  startTime: DateTime.now(),
                  endTime: DateTime.now().add(const Duration(minutes: 25)),
                  estimatedMinutes: 25,
                  reason: "Study Together",
                ),
                groupId: widget.groupId, // Pass Group ID
              ),
            ),
          ).then((_) => _loadDetails()); 
        },
        label: const Text("Start Session"),
        icon: const Icon(Icons.bolt),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6A11CB),
        elevation: 4,
      ) : null,
    );
  }

   Widget _buildAnalyticsSection() {
     // Safety check
     final analytics = _groupDetails?['analytics'];
     if (analytics == null) return const SizedBox.shrink();

     final activeMembers = analytics['active_members'] ?? 0;
     final weeklyActivity = (analytics['weekly_activity'] as List?) ?? [];
     final recentSessions = (analytics['recent_sessions'] as List?) ?? [];

     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
        if (activeMembers > 1) 
         Row(
           children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.timer,
                  color: Colors.indigo.shade400,
                  value: "${(analytics['total_minutes'] ?? 0)}m",
                  label: "Total Focused"
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.group_work,
                  color: Colors.purple.shade400,
                  value: "$activeMembers",
                  label: "Active Learners"
                )
              ),
           ],
         ),
       
       const SizedBox(height: 16),
       
       // Analytics Button
       SizedBox(
         width: double.infinity,
         child: OutlinedButton.icon(
           onPressed: () => _showDetailedAnalytics(context, weeklyActivity, recentSessions),
           icon: const Icon(Icons.bar_chart_rounded, color: Colors.indigo),
           label: const Text("View Detailed Analytics", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
           style: OutlinedButton.styleFrom(
             padding: const EdgeInsets.symmetric(vertical: 16),
             side: BorderSide(color: Colors.indigo.shade100, width: 2),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
             backgroundColor: Colors.white,
           ),
         ),
       ),
       const SizedBox(height: 24),

       const Padding(
         padding: EdgeInsets.symmetric(horizontal: 4),
         child: Text("LEADERBOARD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
       ),
       const SizedBox(height: 12),
     ],
   );
 }

 void _showDetailedAnalytics(BuildContext context, List weeklyActivity, List recentSessions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
               // Handle
               Center(
                 child: Container(
                   width: 40, 
                   height: 4, 
                   margin: const EdgeInsets.symmetric(vertical: 12),
                   decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
                 )
               ),
               Expanded(
                 child: ListView(
                   controller: scrollController,
                   padding: const EdgeInsets.all(24),
                   children: [
                      const Text("Detailed Analytics", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 24),
                      
                      // Weekly Activity Chart
                      if (weeklyActivity.isNotEmpty) ...[
                          const Text("WEEKLY ACTIVITY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                          const SizedBox(height: 12),
                          Container(
                            height: 200,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))
                              ]
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: weeklyActivity.map<Widget>((day) {
                                  final mins = day['minutes'] as int;
                                  final maxMins = (weeklyActivity.map((e) => e['minutes'] as int).reduce((a, b) => a > b ? a : b));
                                  final double chartMax = maxMins > 0 ? maxMins.toDouble() : 100.0;
                                  final double barHeight = (mins / chartMax) * 120; 
                                  
                                  final date = DateTime.parse(day['date']);
                                  final weekDay = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][date.weekday - 1];

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (mins > 0) 
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                          child: Text("$mins", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                                        ),
                                      Container(
                                        width: 16 + (MediaQuery.of(context).size.width / 50),
                                        height: 4 + barHeight.clamp(4.0, 120.0),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: mins > 0 
                                              ? [const Color(0xFF6A11CB), const Color(0xFF2575FC)] 
                                              : [Colors.grey.shade200, Colors.grey.shade300],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(weekDay, style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 32),
                      ],

                      // Recent Sessions Feed
                      if (recentSessions.isNotEmpty) ...[
                          const Text("RECENT SESSIONS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                          const SizedBox(height: 12),
                          ...recentSessions.map<Widget>((session) {
                            final endedAt = DateTime.parse(session['ended_at']);
                            final timeAgo = DateTime.now().difference(endedAt);
                            String timeLabel = "Just now";
                            if (timeAgo.inMinutes < 60) timeLabel = "${timeAgo.inMinutes}m ago";
                            else if (timeAgo.inHours < 24) timeLabel = "${timeAgo.inHours}h ago";
                            else timeLabel = "${timeAgo.inDays}d ago";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.indigo.shade50, 
                                      child: Text((session['username'] as String)[0].toUpperCase(), style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(session['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text("Focused for ${session['minutes']} min", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Text(timeLabel, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 24),
                      ] else 
                        const Center(child: Text("No recent sessions yet", style: TextStyle(color: Colors.grey))),
                   ],
                 ),
               ),
            ],
          ),
        ),
      ),
    );
 }

 Widget _buildInfoCard({required IconData icon, required Color color, required String value, required String label}) {
   return Container(
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(20),
       boxShadow: [
         BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
       ],
     ),
     child: Column(
       children: [
         Icon(icon, color: color, size: 28),
         const SizedBox(height: 8),
         Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
         Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
       ],
     ),
   );
 }

  Widget _buildStatBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  int _validMinutes(Map<String, dynamic> member) {

    if (_groupDetails == null || _groupDetails!['analytics'] == null) return 0;
    final leaderboard = (_groupDetails!['analytics']['leaderboard'] as List? ?? []);
    final userId = member['user']['id'];
    
    // Safety check for user details
    if (userId == null) return 0; 

    final entry = leaderboard.firstWhere(
      (e) => e['user_id'] == userId,
      orElse: () => null,
    );
    
    return entry != null ? entry['minutes'] : 0;
  }

  Widget _buildMemberCard(dynamic member, int rank, {Map<String, dynamic>? presence}) {
    final user = member['user'];
    final username = user != null ? (user['username'] ?? user['email']) : "Unknown";
    final role = member['role'];
    final bool isFocusing = presence != null
        ? presence['is_focusing'] == true
        : (user != null && user['is_focusing'] == true);

    DateTime? focusStartedAt;
    if (isFocusing && presence?['started_at'] != null) {
      focusStartedAt = (presence!['started_at'] as Timestamp).toDate();
    }
    
    // Rank Styling
    Color rankColor = Colors.grey.shade400;
    double rankSize = 14;
    FontWeight rankWeight = FontWeight.bold;
    
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankSize = 18;
      rankWeight = FontWeight.w900;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankSize = 16;
      rankWeight = FontWeight.w800;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankSize = 16;
      rankWeight = FontWeight.w800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
             // Rank Number
             Container(
               width: 30,
               alignment: Alignment.center,
               margin: const EdgeInsets.only(right: 12),
               child: Text(
                 "#$rank",
                 style: TextStyle(
                   color: rankColor,
                   fontSize: rankSize,
                   fontWeight: rankWeight,
                   fontStyle: FontStyle.italic
                 ),
               ),
             ),
             
             // Avatar
             Stack(
               children: [
                 Container(
                   width: 50,
                   height: 50,
                   decoration: BoxDecoration(
                     gradient: LinearGradient(
                       colors: [Colors.purple.shade100, Colors.blue.shade100],
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight,
                     ),
                     borderRadius: BorderRadius.circular(18),
                   ),
                   child: Center(
                     child: Text(
                       (username.isNotEmpty) ? username[0].toUpperCase() : "?",
                       style: TextStyle(
                         color: Colors.purple.shade700,
                         fontWeight: FontWeight.bold,
                         fontSize: 20
                       ),
                     ),
                   ),
                 ),
                 if (isFocusing)
                   Positioned(
                     right: -2,
                     top: -2,
                     child: Container(
                       padding: const EdgeInsets.all(2),
                       decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.bolt, color: Colors.orange, size: 16),
                     ),
                   )
               ],
             ),
             
             const SizedBox(width: 16),
             
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Text(
                         username,
                         style: const TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: 16,
                         ),
                       ),
                       if (role == 'admin') ...[
                         const SizedBox(width: 8),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: Colors.amber.withOpacity(0.2),
                             borderRadius: BorderRadius.circular(6),
                             border: Border.all(color: Colors.amber.withOpacity(0.5)),
                           ),
                           child: const Text(
                             "ADMIN",
                             style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                           ),
                         ),
                       ],
                       const Spacer(),
                       // Kick Button (Admin Only)
                       if (_currentUserId != null && _groupDetails?['owner_id'] == _currentUserId && member['user']['id'] != _currentUserId)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _removeMember(member['user']['id'], username),
                          ),
                     ],
                   ),
                   const SizedBox(height: 4),
                   if (isFocusing)
                     focusStartedAt != null
                         ? _LiveElapsedTimer(startedAt: focusStartedAt)
                         : const Text(
                             "🔥 Focusing...",
                             style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                           )
                   else
                     Padding(
                       padding: const EdgeInsets.only(top: 4.0),
                       child: Row(
                         children: [
                           Text(
                             "Joined ${member['joined_at'].toString().split('T')[0]}",
                             style: TextStyle(color: Colors.grey[500], fontSize: 12),
                           ),
                           const SizedBox(width: 8),
                           Text(
                             "${_validMinutes(member)} min",
                             style: TextStyle(
                               color: Colors.indigo.shade400, 
                               fontSize: 12, 
                               fontWeight: FontWeight.bold
                             ),
                           ),
                         ],
                       ),
                     ),
                 ],
               ),
             ),
          ],
        ),
      ),
    );
  }
}

class _LiveElapsedTimer extends StatefulWidget {
  final DateTime startedAt;
  const _LiveElapsedTimer({required this.startedAt});

  @override
  State<_LiveElapsedTimer> createState() => _LiveElapsedTimerState();
}

class _LiveElapsedTimerState extends State<_LiveElapsedTimer> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final m = elapsed.inMinutes;
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '🔥 Focusing — ${m}m ${s}s',
      style: const TextStyle(
        color: Colors.orange,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
