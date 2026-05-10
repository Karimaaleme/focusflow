import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/notification_item.dart';

/// Shows a live notification toast at the top of the screen via Overlay.
void showNotificationToast(
  BuildContext context,
  NotificationItem notif, {
  VoidCallback? onTap,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastWidget(
      notification: notif,
      onDismiss: () {
        try { entry.remove(); } catch (_) {}
      },
      onTap: onTap,
    ),
  );
  overlay.insert(entry);
}

class _ToastWidget extends StatefulWidget {
  final NotificationItem notification;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const _ToastWidget({required this.notification, required this.onDismiss, this.onTap});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    _autoTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    if (mounted) {
      await _ctrl.reverse();
    }
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 14;

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: _ToastCard(
              notification: widget.notification,
              onDismiss: _dismiss,
              onTap: widget.onTap != null
                  ? () async {
                      await _dismiss();
                      widget.onTap!();
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const _ToastCard({required this.notification, required this.onDismiss, this.onTap});

  Color get _accent {
    switch (notification.type) {
      case 'invitation': return const Color(0xFF7C3AED);
      case 'task': return const Color(0xFF2563EB);
      case 'message': return const Color(0xFF0891B2);
      default: return const Color(0xFF374151);
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case 'invitation': return Icons.group_add_rounded;
      case 'task': return Icons.task_alt_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

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
      if (displayBody.startsWith('__from:')) {
        final end = displayBody.indexOf('__|');
        if (end != -1) displayBody = displayBody.substring(end + 3);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coloured top strip
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accent, _accent.withValues(alpha: 0.4)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon bubble
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(_icon, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 12),

                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displayBody,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Dismiss
                  GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 15, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ), // Container
    ); // GestureDetector
  }
}
