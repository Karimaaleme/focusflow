import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/group_service.dart';
import 'group_detail_screen.dart';
import 'social_discovery_screen.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';

class StudyTogetherScreen extends StatefulWidget {
  const StudyTogetherScreen({super.key});

  @override
  State<StudyTogetherScreen> createState() => _StudyTogetherScreenState();
} // Closing brace for StatefulWidget

class _StudyTogetherScreenState extends State<StudyTogetherScreen> {
  final _groupService = GroupService();
  List<dynamic> _groups = [];
  List<dynamic> _invitations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final groups = await _groupService.getMyGroups();
      final invites = await _groupService.getInvitations();
      setState(() {
        _groups = groups;
        _invitations = invites;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorLoadingStudy(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respondToInvite(int inviteId, String action) async {
    try {
      await _groupService.respondInvitation(inviteId, action);
      _loadData(); // Refresh
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(action == 'accept' ? AppLocalizations.of(context).welcomeToGroupMessage : AppLocalizations.of(context).invitationDeclinedMessage)),
         );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    final l = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.createNewGroupTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l.groupNameInputLabel,
                hintText: l.groupNameHint,
              ),
            ),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: l.descriptionOptionalLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.pop(context);
              try {
                await _groupService.createGroup(
                  nameController.text,
                  descController.text.isEmpty ? null : descController.text,
                );
                _loadData();
              } catch (e) {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: Text(l.createButton),
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Premium Light Background
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), 
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).studyGroups, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black87),
        actions: [
          const LanguageToggleButton(),
          IconButton(
            icon: const Icon(Icons.person_search, color: Colors.black87),
            onPressed: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (_) => const SocialDiscoveryScreen()),
               );
            },
          ),
        ],
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator()) 
          : CustomScrollView(

              slivers: [
                _buildHeroAppBar(),
                
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                       if (_invitations.isNotEmpty) ...[
                         _buildSectionHeader(AppLocalizations.of(context).pendingInvitationsHeader, Icons.mail_outline),
                         const SizedBox(height: 16),
                         ..._invitations.map((invite) => _buildInvitationCard(invite)),
                         const SizedBox(height: 32),
                       ],

                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           _buildSectionHeader(AppLocalizations.of(context).myGroupsHeader, Icons.group_work_outlined),
                           IconButton(
                             icon: const Icon(Icons.add_circle, color: Colors.indigoAccent, size: 28),
                             onPressed: _createGroup,
                             tooltip: AppLocalizations.of(context).createGroupTooltip,
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       
                       if (_groups.isEmpty)
                         _buildEmptyState()
                       else
                         ..._groups.map((group) => _buildGroupCard(group)),
                         
                       const SizedBox(height: 80), // Bottom spacing
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: false, // Don't pin the colorful header, let the clean white AppBar take over
      backgroundColor: Colors.transparent,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          margin: const EdgeInsets.only(bottom: 20), // Slight overlap feel if needed or just spacing
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6A11CB), // Rich Purple
                Color(0xFF2575FC), // Vibrant Blue
              ],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        AppLocalizations.of(context).connectAndGrowLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).studyTogether,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).studyTogetherTagline,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.indigoAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationCard(dynamic invite) {
    // API returns flat sender_name/group_name; also support nested objects as fallback
    final senderObj = invite['sender'];
    final groupObj = invite['group'];

    final sender = (invite['sender_name'] as String?)?.isNotEmpty == true
        ? invite['sender_name'] as String
        : (senderObj != null
            ? (senderObj['username'] ?? senderObj['email'] ?? 'Unknown')
            : 'Unknown');

    final groupName = (invite['group_name'] as String?)?.isNotEmpty == true
        ? invite['group_name'] as String
        : (groupObj != null ? (groupObj['name'] ?? 'Unknown Group') : 'Unknown Group');
    final date = invite['created_at'].toString().split('T')[0];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orangeAccent.shade100,
                  child: const Icon(Icons.mail, color: Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                         AppLocalizations.of(context).invitationFromUser(sender),
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).toJoinGroupLabel(groupName),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToInvite(invite['id'], 'decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(AppLocalizations.of(context).declineButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respondToInvite(invite['id'], 'accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(AppLocalizations.of(context).acceptButton),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(dynamic group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(
                  groupId: group['id'], 
                  groupName: group['name']
                )
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      group['name'][0].toUpperCase(),
                      style: const TextStyle(
                         fontSize: 22,
                         fontWeight: FontWeight.bold,
                         color: Colors.indigo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group['description'] ?? AppLocalizations.of(context).noDescriptionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.groups_3_outlined, size: 40, color: Colors.indigo.shade300),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).noGroupsYetMessage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).createOrWaitInvite,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
