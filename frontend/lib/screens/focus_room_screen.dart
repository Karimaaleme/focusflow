import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/focus_room.dart';
import '../services/forest_service.dart';
import '../services/group_service.dart';
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
  final _myRoomsKey = GlobalKey<_MyRoomsTabState>();
  String? _myDisplayName;
  bool _loadingName = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 2 && !_tabController.indexIsChanging) {
        _myRoomsKey.currentState?._load();
      }
    });
    _initName();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initName() async {
    final name = await UserDisplayService.getMyDisplayName();
    // Sync username to Firestore so leaderboard stays current
    await ForestService.syncUsername();
    if (mounted) {
      setState(() {
        _myDisplayName = name;
        _loadingName = false;
      });
    }
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
            Tab(text: 'Create'),
            Tab(text: 'Join'),
            Tab(text: 'My Rooms'),
          ],
        ),
      ),
      body: _loadingName
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF52B788)))
          : TabBarView(
              controller: _tabController,
              children: [
                _CreateRoomTab(
                  displayName: _myDisplayName ?? 'Grower',
                  onRoomNavigated: () => _myRoomsKey.currentState?._load(),
                ),
                _JoinRoomTab(
                  displayName: _myDisplayName ?? 'Grower',
                  onRoomNavigated: () => _myRoomsKey.currentState?._load(),
                ),
                _MyRoomsTab(key: _myRoomsKey, displayName: _myDisplayName ?? 'Grower'),
              ],
            ),
    );
  }
}

// ── Create Room Tab ───────────────────────────────────────────────────────────

class _CreateRoomTab extends StatefulWidget {
  final String displayName;
  final VoidCallback? onRoomNavigated;
  const _CreateRoomTab({required this.displayName, this.onRoomNavigated});

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
      ).then((_) {
        widget.onRoomNavigated?.call();
        if (mounted) setState(() => _creating = false);
      });
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
  final VoidCallback? onRoomNavigated;
  const _JoinRoomTab({required this.displayName, this.onRoomNavigated});

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
      ).then((_) {
        widget.onRoomNavigated?.call();
        if (mounted) setState(() => _joining = false);
      });
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

// ── My Rooms Tab ──────────────────────────────────────────────────────────────

class _MyRoomsTab extends StatefulWidget {
  final String displayName;
  const _MyRoomsTab({super.key, required this.displayName});

  @override
  State<_MyRoomsTab> createState() => _MyRoomsTabState();
}

class _MyRoomsTabState extends State<_MyRoomsTab> {
  List<FocusRoom> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rooms = await ForestService.getMyRooms();
    if (mounted) setState(() { _rooms = rooms; _loading = false; });
  }

  String _statusLabel(FocusRoom r) {
    switch (r.status) {
      case FocusRoomStatus.active: return '🟢 Active';
      case FocusRoomStatus.completed: return '🌳 Completed';
      default: return '⏳ Waiting';
    }
  }

  Color _statusColor(FocusRoom r) {
    switch (r.status) {
      case FocusRoomStatus.active: return const Color(0xFF52B788);
      case FocusRoomStatus.completed: return Colors.white38;
      default: return const Color(0xFFFFD700);
    }
  }

  String _plantEmoji(String type) {
    switch (type) {
      case 'pine': return '🌲';
      case 'bonsai': return '🪴';
      case 'flower': return '🌺';
      case 'cherry': return '🌸';
      case 'cactus': return '🌵';
      default: return '🌳';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF52B788)));
    }
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No rooms yet',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Create or join a room to get started',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF52B788),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rooms.length,
        itemBuilder: (_, i) {
          final room = _rooms[i];
          final canRejoin = room.status != FocusRoomStatus.completed;
          final isHost = room.hostUid == FirebaseAuth.instance.currentUser?.uid;
          return GestureDetector(
            onTap: canRejoin
                ? () async {
                    final memberStatus =
                        room.status == FocusRoomStatus.active ? 'focusing' : 'ready';
                    await ForestService.rejoinRoom(
                      room.id,
                      widget.displayName,
                      room.plantType,
                      memberStatus,
                    );
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ActiveRoomScreen(
                          room: room,
                          displayName: widget.displayName,
                          isHost: isHost,
                        ),
                      ),
                    ).then((_) => _load());
                  }
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: room.status == FocusRoomStatus.active
                      ? const Color(0xFF52B788).withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Text(_plantEmoji(room.plantType),
                      style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _statusLabel(room),
                              style: TextStyle(
                                  color: _statusColor(room), fontSize: 12),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${room.durationMinutes}m  •  ${room.inviteCode}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                        if (isHost)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'You are the host',
                              style: TextStyle(
                                  color: const Color(0xFF52B788).withOpacity(0.7),
                                  fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (canRejoin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF52B788).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                const Color(0xFF52B788).withOpacity(0.5)),
                      ),
                      child: Text(
                        room.status == FocusRoomStatus.active
                            ? 'Join In'
                            : 'Rejoin',
                        style: const TextStyle(
                            color: Color(0xFF52B788),
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
  bool _isPaused = false;
  int? _backendSessionId;

  bool _isOnBreak = false;
  int _breakTotalSeconds = 0;
  int _breakSecondsLeft = 0;
  Timer? _breakTimer;
  bool _breakHostEnded = false;

  StreamSubscription? _memberSub;
  StreamSubscription? _roomSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Restore timer when rejoining a room that is already active
    if (widget.room.status == FocusRoomStatus.active) {
      _sessionStarted = true;
      final elapsed = widget.room.startTime != null
          ? DateTime.now().difference(widget.room.startTime!).inSeconds
          : 0;
      _remainingSeconds =
          (widget.room.durationMinutes * 60 - elapsed).clamp(0, widget.room.durationMinutes * 60);
      _startTimer();
    } else {
      _remainingSeconds = widget.room.durationMinutes * 60;
    }

    _memberSub = ForestService.roomMembersStream(widget.room.id).listen((members) {
      if (mounted) setState(() => _members = members);
    });

    // Non-host members learn when the host ends the room via this stream
    _roomSub = ForestService.roomStream(widget.room.id).listen((room) {
      if (!mounted) return;
      if (room.status == FocusRoomStatus.completed &&
          !_mySessionDone &&
          !_isOnBreak) {
        _timer?.cancel();
        setState(() {
          _mySessionDone = true;
          _isPaused = false;
        });
        _startBreak(hostEnded: true);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    _breakTimer?.cancel();
    _memberSub?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _completeSession();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  Future<void> _startSession() async {
    setState(() {
      _sessionStarted = true;
      _isPaused = false;
    });
    if (widget.isHost) {
      await ForestService.startRoom(widget.room.id);
      if (!mounted) return;
      await ForestService.sendRoomAnnouncement(
          widget.room.id, '${widget.displayName} started the focus session 🌱');
    } else {
      await ForestService.updateRoomMemberStatus(widget.room.id, 'focusing');
      if (!mounted) return;
      await ForestService.sendRoomAnnouncement(
          widget.room.id, '${widget.displayName} is now focusing 🌿');
    }
    if (!mounted) return;

    try {
      final gs = GroupService();
      final session = await gs.startFocusSession(
        widget.room.durationMinutes,
        plantType: widget.room.plantType,
      );
      if (mounted) _backendSessionId = session['id'] as int?;
    } catch (_) {}

    if (!mounted) return;
    _startTimer();
  }

  Future<void> _pauseSession() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _isPaused = true);
    await ForestService.updateRoomMemberStatus(widget.room.id, 'paused');
  }

  Future<void> _resumeSession() async {
    if (!mounted) return;
    setState(() => _isPaused = false);
    await ForestService.updateRoomMemberStatus(widget.room.id, 'focusing');
    if (!mounted) return;
    _startTimer();
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _mySessionDone = true;
      _isPaused = false;
    });

    await ForestService.completeRoom(widget.room.id, true);
    await ForestService.sendRoomAnnouncement(
        widget.room.id, '${widget.displayName} completed the session! 🌳');

    if (_backendSessionId != null) {
      try {
        await GroupService().endFocusSession(_backendSessionId!, completed: true);
      } catch (_) {}
    }

    if (widget.isHost) {
      await ForestService.endRoomAsHost(widget.room.id);
    }

    await ForestService.saveCompletedSession(
      plantType: widget.room.plantType,
      focusedMinutes: widget.room.durationMinutes,
      plannedMinutes: widget.room.durationMinutes,
      isSuccess: true,
      taskTitle: widget.room.name,
    );
    if (!mounted) return;
    _startBreak(hostEnded: false);
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Room?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your progress will be saved up to this point. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay', style: TextStyle(color: Color(0xFF52B788))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _timer?.cancel();

    if (_sessionStarted && !_mySessionDone) {
      final elapsed = (widget.room.durationMinutes * 60 - _remainingSeconds) ~/ 60;
      if (elapsed > 0) {
        await ForestService.saveCompletedSession(
          plantType: widget.room.plantType,
          focusedMinutes: elapsed,
          plannedMinutes: widget.room.durationMinutes,
          isSuccess: false,
          taskTitle: widget.room.name,
        );
        if (!mounted) return;
        if (_backendSessionId != null) {
          try {
            await GroupService().endFocusSession(_backendSessionId!, completed: false);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      await ForestService.completeRoom(widget.room.id, false);
    }

    if (!mounted) return;
    await ForestService.leaveRoom(widget.room.id, widget.displayName);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _endRoomAsHost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Room for Everyone?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will end the session for all members. Everyone keeps their progress.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF52B788))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Room', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _timer?.cancel();
    final elapsed = (widget.room.durationMinutes * 60 - _remainingSeconds) ~/ 60;

    await ForestService.sendRoomAnnouncement(
        widget.room.id, 'Host ended the room. Great work everyone! 🌳');
    if (!mounted) return;
    await ForestService.endRoomAsHost(widget.room.id);

    if (elapsed > 0) {
      await ForestService.saveCompletedSession(
        plantType: widget.room.plantType,
        focusedMinutes: elapsed,
        plannedMinutes: widget.room.durationMinutes,
        isSuccess: elapsed >= widget.room.durationMinutes * 0.8,
        taskTitle: widget.room.name,
      );
      if (!mounted) return;
      if (_backendSessionId != null) {
        try {
          await GroupService().endFocusSession(
            _backendSessionId!,
            completed: elapsed >= widget.room.durationMinutes * 0.8,
          );
        } catch (_) {}
      }
    }

    if (mounted) Navigator.pop(context);
  }

  void _showCompletionDialog({bool hostEnded = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          hostEnded ? '🌳 Session Ended' : '🌳 Session Complete!',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          hostEnded
              ? 'The host ended the room. Great work!'
              : 'You grew a tree with your focus room!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              if (mounted) Navigator.pop(context); // leave room screen
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF52B788)),
            child: const Text('Return to Zone'),
          ),
        ],
      ),
    );
  }

  static int _breakSecondsFor(int plannedMinutes) {
    if (plannedMinutes <= 20) return 3 * 60;
    if (plannedMinutes <= 35) return 5 * 60;
    if (plannedMinutes <= 60) return 10 * 60;
    return 20 * 60;
  }

  void _startBreak({required bool hostEnded}) {
    if (!mounted) return;
    final seconds = _breakSecondsFor(widget.room.durationMinutes);
    setState(() {
      _isOnBreak = true;
      _breakHostEnded = hostEnded;
      _breakTotalSeconds = seconds;
      _breakSecondsLeft = seconds;
    });
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_breakSecondsLeft <= 0) {
        _onBreakEnd();
        return;
      }
      setState(() => _breakSecondsLeft--);
    });
  }

  void _onBreakEnd() {
    _breakTimer?.cancel();
    if (!mounted) return;
    setState(() => _isOnBreak = false);
    _showCompletionDialog(hostEnded: _breakHostEnded);
  }

  Widget _buildBreakOverlay() {
    final progress = _breakTotalSeconds > 0
        ? (_breakTotalSeconds - _breakSecondsLeft) / _breakTotalSeconds
        : 0.0;
    final m = _breakSecondsLeft ~/ 60;
    final s = _breakSecondsLeft % 60;
    final timeStr =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final breakLabel = '${_breakTotalSeconds ~/ 60} min break';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF0A1628).withOpacity(0.92),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('☕', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                _breakHostEnded ? 'SESSION ENDED' : 'BREAK TIME',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _breakHostEnded
                    ? 'Great work everyone! Take a $breakLabel'
                    : 'Amazing session! Take a $breakLabel',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 44),
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF4CC9F0)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w200,
                            letterSpacing: -2,
                          ),
                        ),
                        Text(
                          'REST',
                          style: TextStyle(
                            color: const Color(0xFF4CC9F0).withOpacity(0.8),
                            fontSize: 10,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 44),
              OutlinedButton(
                onPressed: () {
                  _breakTimer?.cancel();
                  setState(() => _isOnBreak = false);
                  _showCompletionDialog(hostEnded: _breakHostEnded);
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Skip Break',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: _sessionStarted && !_mySessionDone ? _leaveRoom : () => Navigator.pop(context),
        ),
        title: Text(
          widget.room.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Invite code copy
          GestureDetector(
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: widget.room.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite code copied!')),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      color: Color(0xFF52B788), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    widget.room.inviteCode,
                    style: const TextStyle(
                      color: Color(0xFF52B788),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Host: End Room button
          if (widget.isHost && _sessionStarted && !_mySessionDone)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              tooltip: 'End Room',
              onPressed: _endRoomAsHost,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  _buildTimer(),
                  const SizedBox(height: 28),
                  _buildMembersSection(),
                  const SizedBox(height: 20),
                  if (!_sessionStarted)
                    Column(
                      children: [
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
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _leaveRoom,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            child: const Text('Leave Room',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    )
                  else if (!_mySessionDone)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D6A4F).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFF52B788).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_isPaused ? '⏸ ' : '🌿 ',
                                  style: const TextStyle(fontSize: 18)),
                              Text(
                                _isPaused ? 'Paused' : 'Growing together...',
                                style: TextStyle(
                                  color: _isPaused
                                      ? Colors.white60
                                      : const Color(0xFF52B788),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isPaused ? _resumeSession : _pauseSession,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _isPaused
                                        ? const Color(0xFF52B788)
                                        : Colors.white38,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  _isPaused ? '▶  Resume' : '⏸  Pause',
                                  style: TextStyle(
                                    color: _isPaused
                                        ? const Color(0xFF52B788)
                                        : Colors.white60,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _leaveRoom,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text(
                                  'Leave',
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _RoomChatSection(
            roomId: widget.room.id,
            displayName: widget.displayName,
          ),
            ],
          ),
          if (_isOnBreak) _buildBreakOverlay(),
        ],
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
                    ? (_mySessionDone
                        ? 'COMPLETED 🌳'
                        : _isPaused
                            ? 'PAUSED ⏸'
                            : 'GROWING...')
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
      case 'paused':
        return Colors.white54;
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
      case 'paused':
        return '⏸ Paused';
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

// ── Room Chat ─────────────────────────────────────────────────────────────────

class _RoomChatSection extends StatefulWidget {
  final String roomId;
  final String displayName;

  const _RoomChatSection({required this.roomId, required this.displayName});

  @override
  State<_RoomChatSection> createState() => _RoomChatSectionState();
}

class _RoomChatSectionState extends State<_RoomChatSection> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _msgs =>
      _db.collection('focus_rooms').doc(widget.roomId).collection('messages');

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      _msgs.orderBy('timestamp').limitToLast(40).snapshots();

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await _msgs.add({
      'sender_uid': _uid,
      'sender_name': widget.displayName,
      'message': text,
      'is_announcement': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  'GROUP CHAT',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Color(0xFF52B788)),
                    ),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hi to your focus group! 👋',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3), fontSize: 12),
                    ),
                  );
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final isAnnouncement = d['is_announcement'] == true;
                    final isOwn = !isAnnouncement && d['sender_uid'] == _uid;
                    final name = d['sender_name'] as String? ?? 'Member';
                    final msg = d['message'] as String? ?? '';

                    // Announcement bubble
                    if (isAnnouncement) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              msg,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: isOwn
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isOwn)
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D6A4F).withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isOwn
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isOwn)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, bottom: 1),
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                          color: const Color(0xFF52B788)
                                              .withOpacity(0.8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isOwn
                                        ? const Color(0xFF2D6A4F)
                                            .withOpacity(0.6)
                                        : Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft:
                                          Radius.circular(isOwn ? 12 : 3),
                                      bottomRight:
                                          Radius.circular(isOwn ? 3 : 12),
                                    ),
                                  ),
                                  child: Text(
                                    msg,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 12,
                                        height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, 12 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 13),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Message the group...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3), fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFF52B788),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
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
