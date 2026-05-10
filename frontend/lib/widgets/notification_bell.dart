import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../l10n/app_localizations.dart';
import '../models/notification_item.dart';
import '../screens/group_chat_screen.dart';
import '../screens/private_chat_screen.dart';
import '../screens/study_together_screen.dart';
import '../services/api_service.dart';
import 'notification_toast.dart';

class NotificationBell extends StatefulWidget {
  final bool onGradient;
  const NotificationBell({super.key, this.onGradient = false});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  List<NotificationItem> _notifications = [];
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _disposed = false;

  // Bell shake animation
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  // Used to measure the bell's position on screen
  final GlobalKey _bellKey = GlobalKey();

  // Store context for overlay
  BuildContext? _ctx;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.18), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: -0.18), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.18, end: 0.14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.14, end: -0.10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.10, end: 0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _fetchInitial();
    _connect();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Initial HTTP fetch ──────────────────────────────────────────────────────

  Future<void> _fetchInitial() async {
    try {
      final raw = await ApiService.getNotifications();
      if (!_disposed && mounted) {
        setState(() => _notifications = raw.map(NotificationItem.fromJson).toList());
      }
    } catch (_) {}
  }

  // ── WebSocket ───────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final wsBase = ApiService.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$wsBase/ws/notifications?token=${Uri.encodeComponent(token!)}');

      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final notif = NotificationItem.fromJson(data);
      if (!_disposed && mounted) {
        setState(() => _notifications.insert(0, notif));

        // Ring the bell
        _shakeCtrl.forward(from: 0);

        // Show toast — tapping it navigates to the relevant screen
        if (_ctx != null) {
          showNotificationToast(_ctx!, notif, onTap: () => _navigateForNotification(notif));
        }
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _markRead(int id) async {
    await ApiService.markNotificationRead(id);
    if (!_disposed && mounted) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList();
      });
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsRead();
    if (!_disposed && mounted) {
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      });
    }
  }

  void _navigateForNotification(NotificationItem notif) {
    if (_ctx == null) return;
    // Wait one frame so the dialog close animation finishes before pushing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _ctx == null) return;
      switch (notif.type) {
        case 'invitation':
          Navigator.push(_ctx!, MaterialPageRoute(builder: (_) => const StudyTogetherScreen()));
          break;
        case 'message':
          if (notif.relatedId != null) {
            // Group message — related_id is the group_id, title is the group name
            Navigator.push(
              _ctx!,
              MaterialPageRoute(
                builder: (_) => GroupChatScreen(
                  groupId: notif.relatedId!,
                  groupName: notif.title,
                ),
              ),
            );
          } else {
            // DM — parse sender email from hidden body prefix "__from:email__|..."
            final senderEmail = _parseDmEmail(notif.body);
            if (senderEmail != null) {
              Navigator.push(
                _ctx!,
                MaterialPageRoute(
                  builder: (_) => PrivateChatScreen(
                    otherEmail: senderEmail,
                    otherName: notif.title,
                  ),
                ),
              );
            }
            // Old notifications without the prefix: panel already closed, nothing more to do
          }
          break;
        default:
          break;
      }
    });
  }

  static String? _parseDmEmail(String body) {
    if (!body.startsWith('__from:')) return null;
    final end = body.indexOf('__|');
    if (end == -1) return null;
    return body.substring(7, end);
  }

  void _openPanel() {
    final box = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _ctx == null) return;

    final bellPos = box.localToGlobal(Offset.zero);
    final bellSize = box.size;
    final screen = MediaQuery.of(_ctx!).size;
    const panelWidth = 320.0;
    const margin = 8.0;
    final panelTop = bellPos.dy + bellSize.height + 8;

    // Bell centre relative to screen width
    final bellCentreX = bellPos.dx + bellSize.width / 2;
    final bellIsOnLeftHalf = bellCentreX < screen.width / 2;

    // Left-align with bell when on left, right-align when on right
    double? left, right;
    if (bellIsOnLeftHalf) {
      left = (bellPos.dx).clamp(margin, screen.width - panelWidth - margin);
    } else {
      right = (screen.width - bellPos.dx - bellSize.width)
          .clamp(margin, screen.width - panelWidth - margin);
    }

    showGeneralDialog(
      context: _ctx!,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) => Stack(
        children: [
          Positioned(
            top: panelTop,
            left: left,
            right: right,
            width: panelWidth,
            child: _NotificationPanel(
              notifications: _notifications,
              onMarkRead: _markRead,
              onMarkAllRead: _markAllRead,
              onTapNotification: (notif) {
                Navigator.pop(ctx);
                _navigateForNotification(notif);
              },
            ),
          ),
        ],
      ),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _ctx = context;
    final iconColor = widget.onGradient ? Colors.white : const Color(0xFF374151);

    return Tooltip(
      message: AppLocalizations.of(context).notifications,
      child: GestureDetector(
        onTap: _openPanel,
        child: SizedBox(
          key: _bellKey,
          width: 40,
          height: 40,
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.rotate(
              angle: _shakeAnim.value,
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_rounded, size: 24, color: iconColor),
                if (_unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: _Badge(count: _unreadCount),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: count > 0 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Container(
        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Side panel ────────────────────────────────────────────────────────────────

class _NotificationPanel extends StatelessWidget {
  final List<NotificationItem> notifications;
  final Future<void> Function(int) onMarkRead;
  final Future<void> Function() onMarkAllRead;
  final void Function(NotificationItem) onTapNotification;

  const _NotificationPanel({
    required this.notifications,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onTapNotification,
  });

  static const _accent = Color(0xFF7C3AED);

  Color _colorForType(String type) {
    switch (type) {
      case 'invitation': return _accent;
      case 'task': return const Color(0xFF2563EB);
      case 'message': return const Color(0xFF0891B2);
      default: return const Color(0xFF6B7280);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'invitation': return Icons.group_add_rounded;
      case 'task': return Icons.task_alt_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime dt, AppLocalizations l) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return l.justNow;
    if (d.inMinutes < 60) return l.notifMinutesAgo(d.inMinutes);
    if (d.inHours < 24) return l.notifHoursAgo(d.inHours);
    return l.notifDaysAgo(d.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final unread = notifications.where((n) => !n.isRead).length;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ───────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.notifications,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l.notificationsNewCount(unread),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    if (unread > 0)
                      GestureDetector(
                        onTap: () async {
                          await onMarkAllRead();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l.markAllRead,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // ── List ─────────────────────────────────────────────
              Flexible(
                child: notifications.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: notifications.length,
                        itemBuilder: (ctx, i) {
                          final n = notifications[i];
                          final color = _colorForType(n.type);
                          return _NotifTile(
                            notification: n,
                            icon: _iconForType(n.type),
                            color: color,
                            timeAgo: _timeAgo(n.createdAt, l),
                            isLast: i == notifications.length - 1,
                            invitationHint: n.type == 'invitation'
                                ? l.tapToViewInvitation
                                : n.type == 'message'
                                    ? l.tapToOpenChat
                                    : null,
                            onTap: () async {
                              if (!n.isRead) await onMarkRead(n.id);
                              onTapNotification(n);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 52, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(
            l.allCaughtUp,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.notificationsEmptyDesc,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationItem notification;
  final IconData icon;
  final Color color;
  final String timeAgo;
  final bool isLast;
  final VoidCallback onTap;
  final String? invitationHint;

  const _NotifTile({
    required this.notification,
    required this.icon,
    required this.color,
    required this.timeAgo,
    required this.isLast,
    required this.onTap,
    this.invitationHint,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isUnread = !notification.isRead;

    // Resolve display title/body based on notification type
    String displayTitle = notification.title;
    String displayBody = notification.body;
    if (notification.type == 'invitation') {
      displayTitle = l.newStudyInvitation;
      final parts = notification.body.split(' invited you to join ');
      if (parts.length == 2) {
        final sender = parts[0].trim();
        final group = parts[1].trim();
        displayBody = '${l.invitationFromUser(sender)} ${l.toJoinGroupLabel(group)}';
      }
    } else if (notification.type == 'message') {
      // Strip hidden DM email prefix "__from:email__|" if present
      final body = notification.body;
      if (body.startsWith('__from:')) {
        final end = body.indexOf('__|');
        if (end != -1) displayBody = body.substring(end + 3);
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isUnread ? color.withValues(alpha: 0.04) : Colors.transparent,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left colour bar
            Container(
              width: 3,
              height: 44,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isUnread ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 11),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6, top: 3),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displayBody,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      if (invitationHint != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 9, color: color.withValues(alpha: 0.7)),
                        const SizedBox(width: 2),
                        Text(
                          invitationHint!,
                          style: TextStyle(
                            fontSize: 10,
                            color: color.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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
