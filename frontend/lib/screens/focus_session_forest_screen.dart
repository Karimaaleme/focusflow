import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/forest_service.dart';

class FocusSessionForestScreen extends StatefulWidget {
  final int plannedMinutes;
  final String plantType;
  final bool forestModeEnabled;
  final String displayName;
  final String? taskTitle;

  const FocusSessionForestScreen({
    super.key,
    required this.plannedMinutes,
    required this.plantType,
    required this.forestModeEnabled,
    required this.displayName,
    this.taskTitle,
  });

  @override
  State<FocusSessionForestScreen> createState() =>
      _FocusSessionForestScreenState();
}

class _FocusSessionForestScreenState extends State<FocusSessionForestScreen>
    with TickerProviderStateMixin {
  // Timer state
  late int _totalSeconds;
  int _remainingSeconds = 0;
  int _focusedSeconds = 0;
  bool _started = false;
  bool _running = false;
  bool _completed = false;
  bool _failed = false;
  Timer? _timer;

  // Animations
  late final AnimationController _bgController;
  late final AnimationController _treeController; // drives tree growth
  late final AnimationController _pulseController;
  late final AnimationController _glowController;
  late final AnimationController _completionController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _glowAnim;

  // Break state
  SessionReward? _pendingReward;
  bool _isOnBreak = false;
  int _breakTotalSeconds = 0;
  int _breakSecondsLeft = 0;
  Timer? _breakTimer;

  double get _treeProgress =>
      _totalSeconds > 0 ? (_focusedSeconds / _totalSeconds).clamp(0.0, 1.0) : 0.0;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.plannedMinutes * 60;
    _remainingSeconds = _totalSeconds;

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _treeController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breakTimer?.cancel();
    _bgController.dispose();
    _treeController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  // ── Session Logic ─────────────────────────────────────────

  void _startSession() {
    setState(() {
      _started = true;
    });
    _treeController.forward();
    _pulseController.repeat(reverse: true);
    _resume();
  }

  void _resume() {
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _finishSession(success: true);
        return;
      }
      setState(() {
        _remainingSeconds--;
        _focusedSeconds++;
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    _treeController.stop();
    _pulseController.stop();
    setState(() => _running = false);
  }

  void _toggle() {
    if (!_started) return;
    if (_running) {
      _pause();
    } else {
      _treeController.forward();
      _pulseController.repeat(reverse: true);
      _resume();
    }
  }

  Future<void> _finishSession({required bool success}) async {
    _timer?.cancel();
    _treeController.stop();
    _pulseController.stop();
    setState(() {
      _running = false;
      _completed = success;
      _failed = !success;
    });

    if (success) {
      _glowController.repeat(reverse: true);
      _completionController.forward();
    }

    if (widget.forestModeEnabled) {
      try {
        final reward = await ForestService.saveCompletedSession(
          plantType: widget.plantType,
          focusedMinutes: (_focusedSeconds / 60).round(),
          plannedMinutes: widget.plannedMinutes,
          isSuccess: success,
          taskTitle: widget.taskTitle,
        );
        if (!mounted) return;
        if (success) {
          _startBreak(reward);
        } else {
          _showRewardSheet(reward, success);
        }
      } catch (e) {
        if (!mounted) return;
        if (success) {
          _startBreak(null);
        } else {
          _showRewardSheet(null, success);
        }
      }
    } else {
      if (!mounted) return;
      if (success) {
        _startBreak(null);
      } else {
        _showRewardSheet(null, success);
      }
    }
  }

  Future<bool> _confirmExit() async {
    if (!_started || (_focusedSeconds == 0 && !_running)) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ExitConfirmDialog(plantType: widget.plantType),
    );
    return ok ?? false;
  }

  void _showRewardSheet(SessionReward? reward, bool success) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _RewardSheet(
        reward: reward,
        success: success,
        focusedMinutes: (_focusedSeconds / 60).round(),
        plannedMinutes: widget.plannedMinutes,
        plantType: widget.plantType,
        forestMode: widget.forestModeEnabled,
        onDone: () {
          Navigator.pop(context); // sheet
          Navigator.pop(context); // session
        },
      ),
    );
  }

  static int _breakSecondsFor(int plannedMinutes) {
    if (plannedMinutes <= 20) return 3 * 60;
    if (plannedMinutes <= 35) return 5 * 60;
    if (plannedMinutes <= 60) return 10 * 60;
    return 20 * 60;
  }

  void _startBreak(SessionReward? reward) {
    if (!mounted) return;
    final seconds = _breakSecondsFor(widget.plannedMinutes);
    _pendingReward = reward;
    setState(() {
      _isOnBreak = true;
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
    _showRewardSheet(_pendingReward, true);
  }

  // ── UI ────────────────────────────────────────────────────

  String get _timeStr {
    if (!_started) return '${widget.plannedMinutes}:00';
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: (_completed || _failed) && !_isOnBreak,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isOnBreak) {
          _breakTimer?.cancel();
          if (mounted) setState(() => _isOnBreak = false);
          if (mounted) _showRewardSheet(_pendingReward, true);
          return;
        }
        if (_completed || _failed) {
          Navigator.pop(context);
          return;
        }
        final ok = await _confirmExit();
        if (ok && mounted) {
          if (_started) {
            await _finishSession(success: false);
            // Sheet is now showing; onDone handles navigation
          } else if (mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF060E18),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            onPressed: () async {
              if (_isOnBreak) {
                _breakTimer?.cancel();
                if (mounted) setState(() => _isOnBreak = false);
                if (mounted) _showRewardSheet(_pendingReward, true);
                return;
              }
              if (_completed || _failed) {
                Navigator.pop(context);
                return;
              }
              final ok = await _confirmExit();
              if (ok && mounted) {
                if (_started && !_completed && !_failed) {
                  await _finishSession(success: false);
                } else if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
          title: widget.forestModeEnabled
              ? Text(
                  '${widget.plantType[0].toUpperCase()}${widget.plantType.substring(1)} · ${widget.plannedMinutes}min',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                )
              : null,
        ),
        body: Stack(
          children: [
            // Animated forest background
            AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) => CustomPaint(
                painter: _DarkForestBgPainter(_bgController.value),
                size: Size.infinite,
              ),
            ),

            // Firefly particles
            if (widget.forestModeEnabled) const _FireflyOverlay(),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Task chip
                  if (widget.taskTitle != null)
                    _GlassChip(text: widget.taskTitle!),

                  const SizedBox(height: 32),

                  // Tree + ring + timer
                  _buildCenterDisplay(),

                  const Spacer(flex: 2),

                  // Controls
                  if (!_completed && !_failed) _buildControls(),

                  const SizedBox(height: 48),
                ],
              ),
            ),
            if (_isOnBreak) _buildBreakOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterDisplay() {
    final timerColor = _completed
        ? const Color(0xFFFFD700)
        : _failed
            ? Colors.redAccent
            : Colors.white;
    final l = AppLocalizations.of(context);
    final statusText = _completed
        ? l.statusComplete
        : _failed
            ? l.statusSessionEnded
            : _running
                ? (_started ? l.statusGrowing : l.statusFocusing)
                : (_started ? l.statusPaused : l.statusReady);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring
              AnimatedBuilder(
                animation: _treeController,
                builder: (_, __) => CustomPaint(
                  size: const Size(300, 300),
                  painter: _ProgressRingPainter(_treeProgress, _completed, _failed),
                ),
              ),

              // Tree visualization
              if (widget.forestModeEnabled)
                ScaleTransition(
                  scale: _started && _running && !_completed
                      ? _pulseScale
                      : const AlwaysStoppedAnimation(1.0),
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: AnimatedBuilder(
                      animation: _treeController,
                      builder: (_, __) => CustomPaint(
                        painter: TreeGrowthPainter(
                          progress: _treeProgress,
                          plantType: widget.plantType,
                          isDead: _failed,
                          isCompleted: _completed,
                          glowIntensity: _completed ? _glowAnim.value : 0.0,
                        ),
                      ),
                    ),
                  ),
                ),

              // Timer centered — only when forest mode is off or session hasn't started yet
              if (!widget.forestModeEnabled || !_started)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w100,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      _started ? (_running ? AppLocalizations.of(context).statusFocusing : AppLocalizations.of(context).statusPaused) : AppLocalizations.of(context).statusReady,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Timer displayed below the ring when forest mode is active and session has started
        if (widget.forestModeEnabled && _started)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              children: [
                Text(
                  _timeStr,
                  style: TextStyle(
                    color: timerColor,
                    fontSize: 44,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: _completed
                        ? const Color(0xFFFFD700)
                        : Colors.white.withOpacity(0.45),
                    fontSize: 10,
                    letterSpacing: 3.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    if (!_started) {
      return _StartButton(onTap: _startSession);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: _toggle,
          color: Colors.white.withOpacity(0.15),
          borderColor: Colors.white.withOpacity(0.25),
        ),
        const SizedBox(width: 32),
        _ControlBtn(
          icon: Icons.stop_rounded,
          onTap: () => _finishSession(success: false),
          color: Colors.redAccent.withOpacity(0.15),
          borderColor: Colors.redAccent.withOpacity(0.35),
        ),
      ],
    );
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
        color: const Color(0xFF060E18).withOpacity(0.88),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('☕', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text(
                'BREAK TIME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Great focus! Take a $breakLabel',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 44),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
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
                            fontSize: 44,
                            fontWeight: FontWeight.w200,
                            letterSpacing: -2,
                          ),
                        ),
                        Text(
                          'REST',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
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
                  _showRewardSheet(_pendingReward, true);
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
}

// ── Tree Growth Painter ───────────────────────────────────────────────────────

class TreeGrowthPainter extends CustomPainter {
  final double progress;
  final String plantType;
  final bool isDead;
  final bool isCompleted;
  final double glowIntensity;

  TreeGrowthPainter({
    required this.progress,
    required this.plantType,
    this.isDead = false,
    this.isCompleted = false,
    this.glowIntensity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.82;
    final cx = size.width / 2;

    _drawGround(canvas, size, groundY);

    if (isDead) {
      _drawDeadPlant(canvas, size, cx, groundY);
      return;
    }

    switch (plantType) {
      case 'pine':
        _drawPine(canvas, size, cx, groundY);
        break;
      case 'bonsai':
        _drawBonsai(canvas, size, cx, groundY);
        break;
      case 'flower':
        _drawFlower(canvas, size, cx, groundY);
        break;
      case 'cherry':
        _drawCherry(canvas, size, cx, groundY);
        break;
      case 'cactus':
        _drawCactus(canvas, size, cx, groundY);
        break;
      default:
        _drawOak(canvas, size, cx, groundY);
    }

    if (isCompleted && glowIntensity > 0) {
      _drawGlow(canvas, size, cx, groundY);
    }
  }

  // ── Ground ──────────────────────────────────────────────

  void _drawGround(Canvas canvas, Size size, double groundY) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF1B4332), const Color(0xFF0D2B1F)],
      ).createShader(Rect.fromLTWH(0, groundY, size.width, size.height - groundY));

    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, size.height - groundY), paint);

    // Ground highlight
    final hPaint = Paint()
      ..color = const Color(0xFF52B788).withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), hPaint);

    // Grass tufts
    if (progress > 0.05) {
      final gPaint = Paint()
        ..color = const Color(0xFF40916C).withOpacity(0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 7; i++) {
        final gx = size.width * (0.1 + i * 0.13);
        final h = 5 + (i % 3) * 3.0;
        canvas.drawLine(Offset(gx, groundY), Offset(gx - 2, groundY - h), gPaint);
        canvas.drawLine(Offset(gx, groundY), Offset(gx + 2, groundY - h), gPaint);
      }
    }
  }

  // ── Dead plant ──────────────────────────────────────────

  void _drawDeadPlant(Canvas canvas, Size size, double cx, double groundY) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.7)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Wilted stem
    final path = Path();
    path.moveTo(cx, groundY);
    path.cubicTo(cx, groundY - 30, cx - 20, groundY - 50, cx - 10, groundY - 70);
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);

    // Wilted leaves
    final leafPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - 18, groundY - 60), width: 28, height: 14),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, groundY - 80), width: 22, height: 10),
      leafPaint,
    );
  }

  // ── Oak ────────────────────────────────────────────────

  void _drawOak(Canvas canvas, Size size, double cx, double groundY) {
    final trunkH = size.height * 0.38 * _easeIn(progress);
    final trunkW = 12.0 + progress * 6;
    final canopyR = size.width * 0.32 * _easeOut(math.max(0, progress - 0.2) / 0.8);

    // Trunk
    if (progress > 0.05) {
      final trunkPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF6B3E1A), const Color(0xFF3D2009)],
        ).createShader(Rect.fromLTWH(
            cx - trunkW / 2, groundY - trunkH, trunkW, trunkH));
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - trunkW / 2, groundY - trunkH, trunkW, trunkH),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      );
      canvas.drawRRect(rect, trunkPaint);

      // Bark texture lines
      if (progress > 0.4) {
        final bPaint = Paint()
          ..color = const Color(0xFF3D2009).withOpacity(0.5)
          ..strokeWidth = 1;
        for (int i = 1; i < 4; i++) {
          final y = groundY - trunkH * (i / 5.0);
          canvas.drawLine(
              Offset(cx - trunkW / 2 + 2, y), Offset(cx + trunkW / 2 - 2, y), bPaint);
        }
      }
    }

    // Seed stage
    if (progress < 0.15) {
      final seedP = progress / 0.15;
      final sPaint = Paint()
        ..color = const Color(0xFF8B5E3C)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, groundY - 6),
            width: 16 + seedP * 6,
            height: 12 + seedP * 4),
        sPaint,
      );
      if (seedP > 0.6) {
        final sPaint2 = Paint()
          ..color = const Color(0xFF52B788).withOpacity((seedP - 0.6) / 0.4)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(cx, groundY - 12),
          Offset(cx, groundY - 12 - 8 * seedP),
          sPaint2,
        );
      }
      return;
    }

    // Sprout leaves at early stage
    if (progress < 0.35) {
      final sp = (progress - 0.15) / 0.20;
      _drawLeafPair(canvas, cx, groundY - trunkH * 0.8, sp * 14, Colors.green.shade400);
    }

    // Canopy
    if (canopyR > 4) {
      final canopyY = groundY - trunkH - canopyR * 0.6;

      // Canopy layers for depth
      final layers = [
        {'r': canopyR * 1.0, 'dy': 0.0, 'color': const Color(0xFF1B4332)},
        {'r': canopyR * 0.9, 'dy': -canopyR * 0.12, 'color': const Color(0xFF2D6A4F)},
        {'r': canopyR * 0.75, 'dy': -canopyR * 0.22, 'color': const Color(0xFF40916C)},
        {'r': canopyR * 0.55, 'dy': -canopyR * 0.30, 'color': const Color(0xFF52B788)},
      ];

      for (final l in layers) {
        final r = l['r'] as double;
        final dy = l['dy'] as double;
        final col = l['color'] as Color;
        canvas.drawCircle(
          Offset(cx, canopyY + dy),
          r,
          Paint()..color = col,
        );
      }

      // Highlight
      canvas.drawCircle(
        Offset(cx - canopyR * 0.3, canopyY - canopyR * 0.35),
        canopyR * 0.25,
        Paint()..color = const Color(0xFF74C69D).withOpacity(0.5),
      );
    }
  }

  // ── Pine ──────────────────────────────────────────────

  void _drawPine(Canvas canvas, Size size, double cx, double groundY) {
    if (progress < 0.1) {
      _drawSeedStage(canvas, cx, groundY, progress / 0.1);
      return;
    }

    final maxH = size.height * 0.65 * _easeIn(progress);
    final trunkW = 8.0;
    final trunkH = maxH * 0.3;

    // Trunk
    if (progress > 0.15) {
      final trunkPaint = Paint()..color = const Color(0xFF5C3317);
      canvas.drawRect(
        Rect.fromLTWH(cx - trunkW / 2, groundY - trunkH, trunkW, trunkH),
        trunkPaint,
      );
    }

    // Triangular layers (bottom to top, progressively revealed)
    final numLayers = (progress * 4).ceil().clamp(1, 4);
    final layerColors = [
      const Color(0xFF1B4332),
      const Color(0xFF2D6A4F),
      const Color(0xFF40916C),
      const Color(0xFF52B788),
    ];

    for (int i = 0; i < numLayers; i++) {
      final layerProgress = math.min(1.0, (progress * 4 - i).clamp(0.0, 1.0));
      final baseY = groundY - trunkH - (maxH - trunkH) * (i / 4.0);
      final layerH = (maxH - trunkH) / 3.5;
      final layerW = size.width * 0.30 * (1.0 - i * 0.18) * layerProgress;

      final path = Path();
      path.moveTo(cx, baseY - layerH * layerProgress);
      path.lineTo(cx - layerW, baseY + layerH * 0.15);
      path.lineTo(cx + layerW, baseY + layerH * 0.15);
      path.close();

      canvas.drawPath(
        path,
        Paint()..color = layerColors[i % layerColors.length],
      );
    }
  }

  // ── Bonsai ────────────────────────────────────────────

  void _drawBonsai(Canvas canvas, Size size, double cx, double groundY) {
    if (progress < 0.1) {
      _drawSeedStage(canvas, cx, groundY, progress / 0.1);
      return;
    }

    // Pot
    final potPaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, groundY - 6), width: 44, height: 12),
        const Radius.circular(4),
      ),
      potPaint,
    );

    // Curved trunk
    final trunkH = 50.0 * _easeIn(progress);
    if (progress > 0.15) {
      final trunkPaint = Paint()
        ..color = const Color(0xFF6B3E1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(cx, groundY - 12);
      path.cubicTo(
        cx + 15, groundY - trunkH * 0.5,
        cx - 10, groundY - trunkH * 0.7,
        cx + 5, groundY - trunkH,
      );
      canvas.drawPath(path, trunkPaint);
    }

    // Leaf clusters
    final clusters = [
      {'dx': 0.0, 'dy': -50.0, 'r': 22.0},
      {'dx': -22.0, 'dy': -35.0, 'r': 16.0},
      {'dx': 22.0, 'dy': -30.0, 'r': 14.0},
    ];

    for (int i = 0; i < clusters.length; i++) {
      final clusterProgress = math.min(1.0, (progress * 3 - i * 0.7).clamp(0.0, 1.0));
      if (clusterProgress <= 0) continue;
      final c = clusters[i];
      final r = (c['r'] as double) * clusterProgress;
      canvas.drawCircle(
        Offset(cx + (c['dx'] as double), groundY - 12 + (c['dy'] as double)),
        r,
        Paint()..color = const Color(0xFF2D6A4F),
      );
      canvas.drawCircle(
        Offset(cx + (c['dx'] as double) - r * 0.2, groundY - 12 + (c['dy'] as double) - r * 0.2),
        r * 0.5,
        Paint()..color = const Color(0xFF52B788).withOpacity(0.7),
      );
    }
  }

  // ── Flower ────────────────────────────────────────────

  void _drawFlower(Canvas canvas, Size size, double cx, double groundY) {
    if (progress < 0.1) {
      _drawSeedStage(canvas, cx, groundY, progress / 0.1);
      return;
    }

    // Stem
    final stemH = size.height * 0.30 * _easeIn(progress);
    final stemPaint = Paint()
      ..color = const Color(0xFF40916C)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, groundY),
      Offset(cx, groundY - stemH),
      stemPaint,
    );

    // Side leaves
    if (progress > 0.3) {
      final leafP = math.min(1.0, (progress - 0.3) / 0.3);
      _drawLeafPair(canvas, cx, groundY - stemH * 0.5, leafP * 18, const Color(0xFF52B788));
    }

    // Flower head
    if (progress > 0.4) {
      final flowerP = math.min(1.0, (progress - 0.4) / 0.6);
      final flowerCenter = Offset(cx, groundY - stemH);

      // Petals (8 petals)
      final petalCount = (flowerP * 8).round().clamp(1, 8);
      for (int i = 0; i < petalCount; i++) {
        final angle = (i / 8) * 2 * math.pi;
        final petalR = 14.0 * flowerP;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              flowerCenter.dx + math.cos(angle) * 16,
              flowerCenter.dy + math.sin(angle) * 16,
            ),
            width: petalR * 2,
            height: petalR * 0.9,
          ),
          Paint()
            ..color = const Color(0xFFFF85A1).withOpacity(0.85)
            ..style = PaintingStyle.fill,
        );
      }

      // Center
      canvas.drawCircle(
        flowerCenter,
        9.0 * flowerP,
        Paint()..color = const Color(0xFFFFD700),
      );
      canvas.drawCircle(
        flowerCenter,
        5.0 * flowerP,
        Paint()..color = const Color(0xFFFF8C00),
      );
    }
  }

  // ── Cherry Blossom ─────────────────────────────────────

  void _drawCherry(Canvas canvas, Size size, double cx, double groundY) {
    if (progress < 0.1) {
      _drawSeedStage(canvas, cx, groundY, progress / 0.1);
      return;
    }

    final trunkH = size.height * 0.38 * _easeIn(progress);
    final trunkW = 10.0 + progress * 4;

    // Trunk
    if (progress > 0.15) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - trunkW / 2, groundY - trunkH, trunkW, trunkH),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFF7B3F00),
      );
    }

    // Canopy (pink cherry blossom)
    if (progress > 0.25) {
      final canopyP = math.min(1.0, (progress - 0.25) / 0.75);
      final canopyR = size.width * 0.30 * canopyP;
      final canopyY = groundY - trunkH - canopyR * 0.5;

      canvas.drawCircle(
        Offset(cx, canopyY),
        canopyR,
        Paint()..color = const Color(0xFFFFB7C5),
      );
      canvas.drawCircle(
        Offset(cx - canopyR * 0.3, canopyY - canopyR * 0.2),
        canopyR * 0.7,
        Paint()..color = const Color(0xFFFF85A1),
      );
      canvas.drawCircle(
        Offset(cx + canopyR * 0.25, canopyY - canopyR * 0.1),
        canopyR * 0.6,
        Paint()..color = const Color(0xFFFFB7C5).withOpacity(0.7),
      );

      // Pink petal highlight
      canvas.drawCircle(
        Offset(cx, canopyY - canopyR * 0.3),
        canopyR * 0.25,
        Paint()..color = Colors.white.withOpacity(0.25),
      );
    }
  }

  // ── Cactus ────────────────────────────────────────────

  void _drawCactus(Canvas canvas, Size size, double cx, double groundY) {
    if (progress < 0.1) {
      _drawSeedStage(canvas, cx, groundY, progress / 0.1);
      return;
    }

    final bodyH = size.height * 0.42 * _easeIn(progress);
    final bodyW = 20.0 + progress * 6;
    final cactusColor = const Color(0xFF40916C);
    final cactusLight = const Color(0xFF52B788);

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [cactusLight, cactusColor],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(
          Rect.fromLTWH(cx - bodyW / 2, groundY - bodyH, bodyW, bodyH));

    // Main body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - bodyW / 2, groundY - bodyH, bodyW, bodyH),
        const Radius.circular(10),
      ),
      bodyPaint,
    );

    // Left arm
    if (progress > 0.45) {
      final armP = math.min(1.0, (progress - 0.45) / 0.3);
      final armH = 30.0 * armP;
      final armW = 13.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bodyW / 2 - armW,
              groundY - bodyH * 0.65 - armH, armW, armH),
          const Radius.circular(7),
        ),
        Paint()..color = cactusColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bodyW / 2 - armW,
              groundY - bodyH * 0.65 - armH, armW, 14),
          const Radius.circular(7),
        ),
        Paint()..color = cactusColor,
      );
    }

    // Right arm
    if (progress > 0.65) {
      final armP = math.min(1.0, (progress - 0.65) / 0.3);
      final armH = 25.0 * armP;
      final armW = 12.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + bodyW / 2,
              groundY - bodyH * 0.5 - armH, armW, armH),
          const Radius.circular(7),
        ),
        Paint()..color = cactusColor,
      );
    }

    // Spines
    if (progress > 0.2) {
      final spinePaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..strokeWidth = 1;
      for (int row = 0; row < 4; row++) {
        final ry = groundY - bodyH * 0.15 - row * bodyH * 0.25;
        canvas.drawLine(
            Offset(cx - bodyW / 2 - 4, ry), Offset(cx - bodyW / 2, ry), spinePaint);
        canvas.drawLine(
            Offset(cx + bodyW / 2, ry), Offset(cx + bodyW / 2 + 4, ry), spinePaint);
      }
    }
  }

  // ── Shared helpers ─────────────────────────────────────

  void _drawSeedStage(
      Canvas canvas, double cx, double groundY, double stageP) {
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, groundY - 8),
          width: 16 + stageP * 6,
          height: 11 + stageP * 4),
      Paint()..color = const Color(0xFF8B5E3C),
    );
    if (stageP > 0.6) {
      canvas.drawLine(
        Offset(cx, groundY - 12),
        Offset(cx, groundY - 12 - 8 * stageP),
        Paint()
          ..color = const Color(0xFF52B788).withOpacity((stageP - 0.6) / 0.4)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawLeafPair(
      Canvas canvas, double cx, double y, double size, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - size * 0.8, y), width: size * 1.8, height: size * 0.9), paint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + size * 0.8, y - size * 0.1), width: size * 1.6, height: size * 0.8), paint);
  }

  void _drawGlow(Canvas canvas, Size size, double cx, double groundY) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withOpacity(0.35 * glowIntensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(cx, groundY * 0.5), radius: size.width * 0.55));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // Stars/sparkles
    final sPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.7 * glowIntensity)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final positions = [
      Offset(cx - 60, groundY * 0.25),
      Offset(cx + 65, groundY * 0.3),
      Offset(cx - 40, groundY * 0.45),
      Offset(cx + 50, groundY * 0.2),
      Offset(cx + 20, groundY * 0.15),
    ];
    for (final p in positions) {
      canvas.drawLine(Offset(p.dx - 5, p.dy), Offset(p.dx + 5, p.dy), sPaint);
      canvas.drawLine(Offset(p.dx, p.dy - 5), Offset(p.dx, p.dy + 5), sPaint);
    }
  }

  double _easeIn(double t) => t * t;
  double _easeOut(double t) => 1 - (1 - t) * (1 - t);

  @override
  bool shouldRepaint(covariant TreeGrowthPainter old) =>
      old.progress != progress ||
      old.isDead != isDead ||
      old.isCompleted != isCompleted ||
      old.glowIntensity != glowIntensity;
}

// ── Progress Ring Painter ─────────────────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final bool completed;
  final bool failed;

  _ProgressRingPainter(this.progress, this.completed, this.failed);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.46;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    if (progress > 0) {
      final color = completed
          ? const Color(0xFFFFD700)
          : failed
              ? Colors.redAccent
              : const Color(0xFF52B788);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );

      // Dot at tip
      final tipAngle = startAngle + 2 * math.pi * progress;
      canvas.drawCircle(
        Offset(
          center.dx + radius * math.cos(tipAngle),
          center.dy + radius * math.sin(tipAngle),
        ),
        6,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress ||
      old.completed != completed ||
      old.failed != failed;
}

// ── Background Painter ────────────────────────────────────────────────────────

class _DarkForestBgPainter extends CustomPainter {
  final double t;
  _DarkForestBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060E18), Color(0xFF0A1F14)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final angle = t * 2 * math.pi;
    final c = Offset(
      size.width * 0.5 + size.width * 0.2 * math.cos(angle),
      size.height * 0.4 + size.height * 0.1 * math.sin(angle),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF1B4332).withOpacity(0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.8)),
    );
  }

  @override
  bool shouldRepaint(covariant _DarkForestBgPainter old) => old.t != t;
}

// ── Firefly overlay ──────────────────────────────────────────────────────────

class _FireflyOverlay extends StatefulWidget {
  const _FireflyOverlay();
  @override
  State<_FireflyOverlay> createState() => _FireflyOverlayState();
}

class _FireflyOverlayState extends State<_FireflyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rnd = math.Random();
  late final List<_Firefly> _flies;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _flies = List.generate(18, (_) => _Firefly(_rnd));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _FireflyPainter(_flies, _ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _Firefly {
  late double x, y, speed, size, opacity, dx, dy;
  _Firefly(math.Random rnd) {
    x = rnd.nextDouble();
    y = rnd.nextDouble();
    speed = 0.008 + rnd.nextDouble() * 0.012;
    size = 2 + rnd.nextDouble() * 3;
    opacity = 0.2 + rnd.nextDouble() * 0.6;
    dx = (rnd.nextDouble() - 0.5) * 0.015;
    dy = -(0.005 + rnd.nextDouble() * 0.01);
  }
}

class _FireflyPainter extends CustomPainter {
  final List<_Firefly> flies;
  final double t;
  _FireflyPainter(this.flies, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in flies) {
      f.x += f.dx * 0.5;
      f.y += f.dy * 0.5;
      if (f.y < -0.05) {
        f.y = 1.05;
        f.x = math.Random().nextDouble();
      }
      if (f.x < 0 || f.x > 1) f.dx = -f.dx;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFB7E4C7).withOpacity(f.opacity * 0.8),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(f.x * size.width, f.y * size.height),
          radius: f.size * 4,
        ));
      canvas.drawCircle(
          Offset(f.x * size.width, f.y * size.height), f.size * 3, glowPaint);
      canvas.drawCircle(
        Offset(f.x * size.width, f.y * size.height),
        f.size * 0.8,
        Paint()..color = const Color(0xFFD8F3DC).withOpacity(f.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyPainter old) => true;
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF52B788), Color(0xFF2D6A4F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF52B788).withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Builder(builder: (context) => Text(
          AppLocalizations.of(context).startGrowing,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        )),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color borderColor;

  const _ControlBtn({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

class _ExitConfirmDialog extends StatelessWidget {
  final String plantType;
  const _ExitConfirmDialog({required this.plantType});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D2B1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Text('🥀', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Text(AppLocalizations.of(context).leaveEarlyTitle, style: const TextStyle(color: Colors.white, fontSize: 18)),
      ]),
      content: Text(
        AppLocalizations.of(context).plantWillWither,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context).keepGrowing, style: const TextStyle(color: Color(0xFF52B788))),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
          child: Text(AppLocalizations.of(context).leave),
        ),
      ],
    );
  }
}

// ── Reward Sheet ──────────────────────────────────────────────────────────────

class _RewardSheet extends StatefulWidget {
  final SessionReward? reward;
  final bool success;
  final int focusedMinutes;
  final int plannedMinutes;
  final String plantType;
  final bool forestMode;
  final VoidCallback onDone;

  const _RewardSheet({
    required this.reward,
    required this.success,
    required this.focusedMinutes,
    required this.plannedMinutes,
    required this.plantType,
    required this.forestMode,
    required this.onDone,
  });

  @override
  State<_RewardSheet> createState() => _RewardSheetState();
}

class _RewardSheetState extends State<_RewardSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slideIn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideIn = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eff = widget.plannedMinutes > 0
        ? (widget.focusedMinutes / widget.plannedMinutes * 100).clamp(0, 100).round()
        : 100;

    final Color accent = widget.success
        ? (eff >= 100
            ? const Color(0xFFFFD700)
            : eff >= 80
                ? const Color(0xFF52B788)
                : Colors.orangeAccent)
        : Colors.redAccent;

    final l = AppLocalizations.of(context);
    final String headline = widget.success
        ? (eff >= 100
            ? l.perfectBloom
            : eff >= 80
                ? l.greatGrowth
                : l.goodEffortForest)
        : l.sessionEndedLabel;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(_slideIn),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            decoration: BoxDecoration(
              color: const Color(0xFF060E18).withOpacity(0.94),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border:
                  Border(top: BorderSide(color: accent.withOpacity(0.3), width: 1.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Headline
                Text(
                  headline,
                  style: TextStyle(
                    color: accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RewardStat(
                        label: l.focusedLabel,
                        value: '${widget.focusedMinutes}m',
                        color: Colors.white),
                    _RewardStat(
                        label: l.efficiencyLabel,
                        value: '$eff%',
                        color: accent),
                    _RewardStat(
                        label: l.plannedLabel,
                        value: '${widget.plannedMinutes}m',
                        color: Colors.white54),
                  ],
                ),

                if (widget.forestMode && widget.success && widget.reward != null) ...[
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),

                  // Reward chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RewardChip(
                          emoji: '🪙',
                          value: '+${widget.reward!.coinsEarned}',
                          color: const Color(0xFFFFD700)),
                      const SizedBox(width: 12),
                      _RewardChip(
                          emoji: '⚡',
                          value: '+${widget.reward!.xpEarned} XP',
                          color: const Color(0xFF52B788)),
                      const SizedBox(width: 12),
                      _RewardChip(
                          emoji: '🔥',
                          value: '${widget.reward!.newStreak}d',
                          color: Colors.orangeAccent),
                    ],
                  ),

                  // New achievements
                  if (widget.reward!.newAchievements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A1D96).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.purple.withOpacity(0.4)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(context).newAchievementsUnlocked,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...widget.reward!.newAchievements.map(
                            (a) => Text(
                              '✓ $a',
                              style: const TextStyle(
                                  color: Colors.purple, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 28),

                // Done button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      widget.success ? AppLocalizations.of(context).returnToZone : AppLocalizations.of(context).backToZone,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RewardStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(),
            style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                letterSpacing: 1)),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String emoji;
  final String value;
  final Color color;

  const _RewardChip(
      {required this.emoji, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
