import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/ai_plan_item.dart';
import '../services/api_service.dart';
import '../widgets/language_toggle_button.dart';
import '../services/group_service.dart';
import '../services/focus_presence_service.dart';
import '../services/group_chat_service.dart';
import '../services/user_display_service.dart';
import '../l10n/app_localizations.dart';

class FocusSessionScreen extends StatefulWidget {
  final AIPlanItem block;
  final int? groupId; // Add GroupID

  const FocusSessionScreen({
    super.key,
    required this.block,
    this.groupId,
  });

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> with TickerProviderStateMixin {
  final _groupService = GroupService(); // Service
  int? _activeSessionId; // Session ID from backend
  Timer? _timer;

  // Modes
  bool _started = false;
  bool _running = false;
  bool _isBreak = false;

  // Logic
  int _plannedMinutes = 25;
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  int _focusedSeconds = 0;

  DateTime? _startedAt;

  // Animations
  late final AnimationController _bgAnimController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    final mins = widget.block.estimatedMinutes <= 0 ? 25 : widget.block.estimatedMinutes;
    _plannedMinutes = mins;

    // Background mesh animation
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // Heartbeat/Pulse animation for active focus
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bgAnimController.dispose();
    _pulseController.dispose();
    if (_started) {
      ApiService.updateFocusStatus(false);
      if (widget.groupId != null) {
        FocusPresenceService.stopFocusing(widget.groupId!);
      }
    }
    super.dispose();
  }

  // ---------------- L O G I C ----------------

  Future<void> _startSession() async {
    setState(() {
      _totalSeconds = _plannedMinutes * 60;
      _remainingSeconds = _totalSeconds;
      _focusedSeconds = 0;
      _startedAt = DateTime.now();
      _started = true;
      _resume();
    });
    
    ApiService.updateFocusStatus(true);
    _pulseController.repeat(reverse: true);

    // Write live presence to Firestore for group sessions
    if (widget.groupId != null) {
      final displayName = await UserDisplayService.getMyDisplayName();
      FocusPresenceService.startFocusing(
        groupId: widget.groupId!,
        displayName: displayName,
      );
    }

    // Call Backend
    try {
      final session = await _groupService.startFocusSession(_plannedMinutes, groupId: widget.groupId);
      _activeSessionId = session['id'];
    } catch (e) {
      debugPrint("Backend Focus Start Error: $e");
    }
  }

  // ... resume, pause, toggle ...
  void _resume() {
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _finishSession(auto: true);
        return;
      }
      setState(() {
        _remainingSeconds--;
        _focusedSeconds++;
      });
    });
  }

  void _pause() {
    setState(() => _running = false);
    _timer?.cancel();
    _pulseController.stop();
  }

  void _toggle() {
    if (!_started) return;
    if (_running) {
      _pause();
    } else {
      _resume();
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _finishSession({bool auto = false}) async {
    _timer?.cancel();
    _running = false;
    _pulseController.stop();

    // Call Backend End
    if (_activeSessionId != null) {
      try {
        await _groupService.endFocusSession(_activeSessionId!);
        _activeSessionId = null;
      } catch (e) {
        debugPrint("Backend Focus End Error: $e");
      }
    }

    final startedAt = _startedAt;
    final focusedMinutes = (_focusedSeconds / 60).round();
    final endedAt = DateTime.now();

    ApiService.updateFocusStatus(false);
    if (widget.groupId != null) {
      FocusPresenceService.stopFocusing(widget.groupId!);
      // Post session summary to group chat
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && focusedMinutes > 0) {
        final senderName = await UserDisplayService.getMyDisplayName();
        await GroupChatService.postSessionSummary(
          groupId: widget.groupId!,
          senderEmail: user.email ?? '',
          senderName: senderName,
          focusedMinutes: focusedMinutes,
          taskName: widget.block.title.isNotEmpty ? widget.block.title : null,
        );
      }
    }

    if (!mounted) return;
    _showFinishedSheet(planned: _plannedMinutes, focused: focusedMinutes, auto: auto, isBreak: _isBreak);
  }

  void _startBreak() {
    Navigator.pop(context); // Close sheet
    setState(() {
      _isBreak = true;
      _plannedMinutes = 5; // Default break
      _started = false; // Manual start
      _running = false;
      _focusedSeconds = 0;
    });
    // Break likely doesn't need backend "Focus Session", or maybe a separate type?
    // For now, only main focus session is tracked.
  }

  // ---------------- U I ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black, // fallback
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [LanguageToggleButton(onGradient: true)],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () async {
            if (_started && (_running || _focusedSeconds > 0)) {
               final ok = await showDialog<bool>(
                 context: context,
                 builder: (_) => const _ExitDialog(),
               );
               if (ok != true) return;
            }
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Animated Animated Background
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, child) {
              return CustomPaint(
                painter: _MeshGradientPainter(_bgAnimController.value),
                size: Size.infinite,
              );
            },
          ),

          // 2. Ambient Particles
          const _ParticleOverlay(),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Task Label
                _GlassChip(text: _isBreak ? AppLocalizations.of(context).breakTime : widget.block.title.toUpperCase()),

                const SizedBox(height: 40),

                // Timer Display
                ScaleTransition(
                  scale: _started && _running ? _pulseScale : const AlwaysStoppedAnimation(1.0),
                  child: _GlassTimerCircle(
                    timeStr: _timeStr,
                    subtitle: _statusStr,
                    isRunning: _running,
                  ),
                ),

                const Spacer(flex: 2),

                // Controls
                if (!_started) 
                   _buildSetupPanel()
                else 
                   _buildActiveControls(),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _timeStr {
    if (!_started) return "$_plannedMinutes:00";
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String get _statusStr {
    final l = AppLocalizations.of(context);
    if (!_started) return l.readyToStart;
    return _running ? l.focusingStatus : l.pausedStatus;
  }

  Widget _buildSetupPanel() {
    final chips = _isBreak ? [5, 10, 15, 20] : [15, 25, 45, 60];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...chips.map((m) {
                final selected = _plannedMinutes == m;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _plannedMinutes = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24, 
                          width: 1
                        ),
                      ),
                      child: Text(
                        "$m",
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),

              // Custom Time Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () async {
                     final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 0, minute: 30),
                        initialEntryMode: TimePickerEntryMode.inputOnly,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.blueAccent,
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: const Color(0xFF1A1A2E),
                            ),
                            child: child!,
                          );
                        },
                        helpText: AppLocalizations.of(context).enterDuration,
                     );
                     if (picked != null) {
                       final totalMins = picked.hour * 60 + picked.minute;
                       if (totalMins > 0) {
                         setState(() => _plannedMinutes = totalMins);
                       }
                     }
                  },
                  child: AnimatedContainer(
                       duration: const Duration(milliseconds: 200),
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                       decoration: BoxDecoration(
                         color: Colors.white10,
                         borderRadius: BorderRadius.circular(20),
                         border: Border.all(color: Colors.white24, width: 1),
                       ),
                       child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                     ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: _startSession,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Text(
              _isBreak ? AppLocalizations.of(context).startBreak : AppLocalizations.of(context).startFocus,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildActiveControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: _toggle,
        ),
        const SizedBox(width: 40),
        _ControlBtn(
          icon: Icons.stop_rounded,
          isDestructive: true,
          onTap: () => _finishSession(auto: false),
        ),
      ],
    );
  }

  void _showFinishedSheet({required int planned, required int focused, required bool auto, bool isBreak = false}) {
    // Re-use standard bottom sheet or make a glass one? Standard is safer for now.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // For custom glass sheet
      builder: (_) => _GlassSummarySheet(
        planned: planned, 
        focused: focused,
        onTakeBreak: isBreak ? null : _startBreak,
        isBreakSession: isBreak,
      ),
    );
  }
}

// ---------------- CUSTOM WIDGETS ----------------

class _GlassTimerCircle extends StatelessWidget {
  final String timeStr;
  final String subtitle;
  final bool isRunning;

  const _GlassTimerCircle({
    required this.timeStr,
    required this.subtitle,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(200),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                timeStr,
                 style: const TextStyle(
                   color: Colors.white,
                   fontSize: 68,
                   fontWeight: FontWeight.w100, // Thin font
                   letterSpacing: -2,
                 ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  color: isRunning ? Colors.white : Colors.white54,
                  fontSize: 12,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String text;
  const _GlassChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70, 
              fontSize: 12, 
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ControlBtn({required this.icon, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isDestructive ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDestructive ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.2)
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}

// ---------------- PAINTERS & ANIMATIONS ----------------

class _MeshGradientPainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0

  _MeshGradientPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // Animate color stops or centers based on value
    // We'll move centers in a circular motion
    final t = animationValue * 2 * math.pi;
    final center1 = Offset(
      size.width * 0.5 + size.width * 0.2 * math.cos(t),
      size.height * 0.4 + size.height * 0.1 * math.sin(t)
    );
    final center2 = Offset(
      size.width * 0.5 + size.width * 0.2 * math.sin(t),
      size.height * 0.6 + size.height * 0.1 * math.cos(t)
    );

    // Background Base
    final paint = Paint()..color = const Color(0xFF0F0C29); // Deep purple/black
    canvas.drawRect(rect, paint);
    
    // Orb 1 (Teal/Blue)
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
           Colors.purpleAccent.withOpacity(0.4),
           Colors.transparent,
        ],
        radius: 0.6,
      ).createShader(Rect.fromCircle(center: center1, radius: size.width * 0.8));
    canvas.drawRect(rect, p1);

    // Orb 2 (Pink/Red)
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
           Colors.blueAccent.withOpacity(0.4),
           Colors.transparent,
        ],
        radius: 0.7,
      ).createShader(Rect.fromCircle(center: center2, radius: size.width * 0.9));
    canvas.drawRect(rect, p2);
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _ParticleOverlay extends StatefulWidget {
  const _ParticleOverlay();

  @override
  State<_ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<_ParticleOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    // Generate particles
    for (int i=0; i<20; i++) {
      _particles.add(_Particle(_rnd));
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlePainter(_particles, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  late double x;
  late double y;
  late double speed;
  late double size;
  late double opacity;

  _Particle(math.Random rnd) {
    _reset(rnd, true);
  }

  void _reset(math.Random rnd, bool randomY) {
    x = rnd.nextDouble();
    y = randomY ? rnd.nextDouble() : 1.1; // Start below screen if resetting
    speed = 0.05 + rnd.nextDouble() * 0.05; // speed
    size = 2.0 + rnd.nextDouble() * 4.0; 
    opacity = 0.1 + rnd.nextDouble() * 0.4;
  }
  
  void update(double dt) {
    y -= speed * dt; // move up
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // used to trigger repaint
  
  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var p in particles) {
      // update sim logic in paint (simple hack for smooth animation)
      // typically update in tick, but this is visual only
      p.y -= 0.002; 
      if (p.y < -0.1) {
         p.y = 1.1;
         p.x = math.Random().nextDouble();
      }

      paint.color = Colors.white.withOpacity(p.opacity);
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _ExitDialog extends StatelessWidget {
  const _ExitDialog();
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.1),
          title: Text(AppLocalizations.of(context).exitSession, style: const TextStyle(color: Colors.white)),
          content: Text(AppLocalizations.of(context).progressWillBeLost, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel, style: const TextStyle(color: Colors.white54))
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(AppLocalizations.of(context).exitButton)
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassSummarySheet extends StatelessWidget {
  final int planned;
  final int focused;
  final VoidCallback? onTakeBreak;
  final bool isBreakSession;

  const _GlassSummarySheet({
    required this.planned, 
    required this.focused,
    this.onTakeBreak,
    this.isBreakSession = false,
  });

  @override
  Widget build(BuildContext context) {
    // Analysis Logic
    final efficiency = (planned > 0) ? (focused / planned * 100).clamp(0, 100).round() : 100;
    
    final l = AppLocalizations.of(context);
    String statusText;
    Color statusColor;
    if (efficiency >= 100) {
      statusText = l.perfectFocus;
      statusColor = Colors.greenAccent;
    } else if (efficiency >= 80) {
      statusText = l.greatJob;
      statusColor = Colors.blueAccent;
    } else if (efficiency >= 50) {
      statusText = l.goodEffort;
      statusColor = Colors.orangeAccent;
    } else {
      statusText = l.keepTrying;
      statusColor = Colors.redAccent;
    }

    if (isBreakSession) {
      statusText = ""; 
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0C29).withOpacity(0.90),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon & Title
                Icon(Icons.verified, color: statusColor, size: 50),
                const SizedBox(height: 12),
                Text(isBreakSession ? AppLocalizations.of(context).breakComplete : AppLocalizations.of(context).sessionComplete, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                if (!isBreakSession)
                  Text(statusText, style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
                
                const SizedBox(height: 32),

                // Efficiency Ring / Big Stat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatColumn(label: AppLocalizations.of(context).plannedLabel, value: "${planned}m", color: Colors.white54),
                    Column(
                      children: [
                        Text(
                          "$efficiency%",
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(AppLocalizations.of(context).efficiencyLabel, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                      ],
                    ),
                    _StatColumn(label: AppLocalizations.of(context).focusedLabel, value: "${focused}m", color: Colors.white),
                  ],
                ),

                const SizedBox(height: 32),
                const Divider(color: Colors.white10),
                const SizedBox(height: 20),


                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      if (onTakeBreak != null) ...[
                        Expanded(
                          child: TextButton(
                            onPressed: onTakeBreak,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            child: Text(AppLocalizations.of(context).takeABreak, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context, true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: statusColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                          ),
                          child: Text(AppLocalizations.of(context).doneButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }
}
