import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/focus_room.dart';
import '../services/forest_service.dart';
import '../services/user_display_service.dart';
import 'focus_session_forest_screen.dart' show TreeGrowthPainter;

class FocusRoomScreen extends StatefulWidget {
  const FocusRoomScreen({super.key});

  @override
  State<FocusRoomScreen> createState() => _FocusRoomScreenState();
}

class _FocusRoomScreenState extends State<FocusRoomScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _myDisplayName;
  bool _loadingName = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initName();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initName() async {
    final name = await UserDisplayService.getMyDisplayName();
    setState(() {
      _myDisplayName = name;
      _loadingName = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Focus Room',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF52B788),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF52B788),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Create Room'),
            Tab(text: 'Join Room'),
          ],
        ),
      ),
      body: _loadingName
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF52B788)))
          : TabBarView(
              controller: _tabController,
              children: [
                _CreateRoomTab(displayName: _myDisplayName ?? 'Grower'),
                _JoinRoomTab(displayName: _myDisplayName ?? 'Grower'),
              ],
            ),
    );
  }
}

// ── Create Room Tab ───────────────────────────────────────────────────────────

class _CreateRoomTab extends StatefulWidget {
  final String displayName;
  const _CreateRoomTab({required this.displayName});

  @override
  State<_CreateRoomTab> createState() => _CreateRoomTabState();
}

class _CreateRoomTabState extends State<_CreateRoomTab> {
  final _nameCtrl = TextEditingController();
  int _duration = 25;
  String _plantType = 'oak';
  bool _creating = false;
  String? _error;

  final _durations = [15, 25, 30, 45, 60, 90];
  final _plants = [
    {'id': 'oak', 'emoji': '🌳', 'name': 'Oak'},
    {'id': 'pine', 'emoji': '🌲', 'name': 'Pine'},
    {'id': 'bonsai', 'emoji': '🪴', 'name': 'Bonsai'},
    {'id': 'flower', 'emoji': '🌺', 'name': 'Flower'},
    {'id': 'cherry', 'emoji': '🌸', 'name': 'Cherry'},
    {'id': 'cactus', 'emoji': '🌵', 'name': 'Cactus'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a room name');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final room = await ForestService.createRoom(
        name: name,
        durationMinutes: _duration,
        plantType: _plantType,
        hostName: widget.displayName,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ActiveRoomScreen(
            room: room,
            displayName: widget.displayName,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to create room: $e';
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SectionLabel('Room Name'),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Study Squad, Deep Work...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF52B788)),
              ),
              prefixIcon: Icon(Icons.group_rounded,
                  color: Colors.white.withOpacity(0.4)),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Focus Duration'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durations.map((m) {
              final sel = _duration == m;
              return GestureDetector(
                onTap: () => setState(() => _duration = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF52B788).withOpacity(0.25)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF52B788)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    '${m}m',
                    style: TextStyle(
                      color: sel ? const Color(0xFF52B788) : Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Group Plant'),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _plants.length,
              itemBuilder: (_, i) {
                final p = _plants[i];
                final sel = _plantType == p['id'];
                return GestureDetector(
                  onTap: () => setState(() => _plantType = p['id']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 70,
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF2D6A4F).withOpacity(0.4)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF52B788)
                            : Colors.white.withOpacity(0.08),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p['emoji']!,
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          p['name']!,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _creating ? null : _createRoom,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF52B788),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('🌿  Create Focus Room',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Join Room Tab ─────────────────────────────────────────────────────────────

class _JoinRoomTab extends StatefulWidget {
  final String displayName;
  const _JoinRoomTab({required this.displayName});

  @override
  State<_JoinRoomTab> createState() => _JoinRoomTabState();
}

class _JoinRoomTabState extends State<_JoinRoomTab> {
  final _codeCtrl = TextEditingController();
  String _plantType = 'oak';
  bool _joining = false;
  String? _error;

  final _plants = [
    {'id': 'oak', 'emoji': '🌳'},
    {'id': 'pine', 'emoji': '🌲'},
    {'id': 'bonsai', 'emoji': '🪴'},
    {'id': 'flower', 'emoji': '🌺'},
    {'id': 'cherry', 'emoji': '🌸'},
    {'id': 'cactus', 'emoji': '🌵'},
  ];

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter a valid 6-character code');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final room = await ForestService.joinRoomByCode(
        code,
        widget.displayName,
        _plantType,
      );
      if (room == null) {
        setState(() {
          _error = 'Room not found or no longer accepting members.';
          _joining = false;
        });
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ActiveRoomScreen(
            room: room,
            displayName: widget.displayName,
            isHost: false,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to join: $e';
        _joining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Invite code visual
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF52B788).withOpacity(0.3), width: 2),
              ),
              child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 60)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Enter Room Code',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Ask your friend for the 6-character code',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
          ),
          const SizedBox(height: 28),
          // Code input
          TextField(
            controller: _codeCtrl,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: 8),
            textAlign: TextAlign.center,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9a-z]')),
            ],
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  letterSpacing: 6,
                  fontSize: 22),
              counterText: '',
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Your Plant'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _plants.map((p) {
              final sel = _plantType == p['id'];
              return GestureDetector(
                onTap: () => setState(() => _plantType = p['id']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF2D6A4F).withOpacity(0.4)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF52B788)
                          : Colors.white.withOpacity(0.08),
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(p['emoji']!,
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _joining ? null : _joinRoom,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF52B788),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: _joining
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Join Room',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active Room Screen ────────────────────────────────────────────────────────

class _ActiveRoomScreen extends StatefulWidget {
  final FocusRoom room;
  final String displayName;
  final bool isHost;

  const _ActiveRoomScreen({
    required this.room,
    required this.displayName,
    required this.isHost,
  });

  @override
  State<_ActiveRoomScreen> createState() => _ActiveRoomScreenState();
}

class _ActiveRoomScreenState extends State<_ActiveRoomScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  List<FocusRoomMember> _members = [];
  bool _sessionStarted = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _mySessionDone = false;

  StreamSubscription? _memberSub;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.room.durationMinutes * 60;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Listen to members in real time
    _memberSub = ForestService.roomMembersStream(widget.room.id).listen((members) {
      if (mounted) setState(() => _members = members);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    _memberSub?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _sessionStarted = true);
    if (widget.isHost) {
      await ForestService.startRoom(widget.room.id);
    } else {
      await ForestService.updateRoomMemberStatus(widget.room.id, 'focusing');
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _completeSession();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    setState(() => _mySessionDone = true);
    await ForestService.completeRoom(widget.room.id, true);
    await ForestService.saveCompletedSession(
      plantType: widget.room.plantType,
      focusedMinutes: widget.room.durationMinutes,
      plannedMinutes: widget.room.durationMinutes,
      isSuccess: true,
      taskTitle: widget.room.name,
    );
    if (!mounted) return;
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🌳 Session Complete!',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'You grew a tree with your focus room!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // active room
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF52B788)),
            child: const Text('Return to Zone'),
          ),
        ],
      ),
    );
  }

  String get _timeStr {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.room.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Invite code
          Center(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: widget.room.inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Invite code copied!')),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF52B788).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded,
                        color: Color(0xFF52B788), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.room.inviteCode,
                      style: const TextStyle(
                        color: Color(0xFF52B788),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Timer
            _buildTimer(),
            const SizedBox(height: 28),
            // Members grid
            _buildMembersSection(),
            const SizedBox(height: 28),
            // Start button (if not started)
            if (!_sessionStarted)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _startSession,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF52B788),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    widget.isHost
                        ? '🌱  Start Group Focus'
                        : '🌱  Ready to Focus',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              )
            else if (!_mySessionDone)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF52B788).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🌿 ', style: TextStyle(fontSize: 18)),
                    Text('Growing together...',
                        style: TextStyle(
                            color: Color(0xFF52B788),
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Text(
                _sessionStarted ? _timeStr : '${widget.room.durationMinutes}:00',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w100,
                  letterSpacing: -2,
                ),
              ),
              Text(
                _sessionStarted
                    ? (_mySessionDone ? 'COMPLETED 🌳' : 'GROWING...')
                    : 'WAITING FOR START',
                style: TextStyle(
                  color: _mySessionDone
                      ? const Color(0xFF52B788)
                      : Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              // Group plant preview
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: TreeGrowthPainter(
                    progress: _sessionStarted
                        ? 1.0 -
                            (_remainingSeconds /
                                (widget.room.durationMinutes * 60))
                        : 0.05,
                    plantType: widget.room.plantType,
                    isCompleted: _mySessionDone,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MEMBERS (${_members.length})',
          style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        if (_members.isEmpty)
          const Center(
            child: Text('Waiting for members...',
                style: TextStyle(color: Colors.white54)),
          )
        else
          ...(_members.map((m) => _MemberRow(member: m))),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final FocusRoomMember member;

  const _MemberRow({required this.member});

  Color get _statusColor {
    switch (member.status) {
      case 'completed':
        return const Color(0xFF52B788);
      case 'failed':
        return Colors.redAccent;
      case 'focusing':
        return const Color(0xFFFFD700);
      default:
        return Colors.white38;
    }
  }

  String get _statusLabel {
    switch (member.status) {
      case 'completed':
        return '🌳 Completed';
      case 'failed':
        return '🥀 Left early';
      case 'focusing':
        return '🌱 Growing...';
      default:
        return '⏳ Ready';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Text(member.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(_statusLabel,
                    style: TextStyle(color: _statusColor, fontSize: 11)),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _statusColor.withOpacity(0.5), blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.45),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }
}
