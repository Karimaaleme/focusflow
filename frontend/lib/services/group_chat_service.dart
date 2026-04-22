import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupChatMessage {
  final String senderEmail;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String type; // 'text' | 'goal' | 'session_summary'
  final Map<String, dynamic>? metadata;

  GroupChatMessage({
    required this.senderEmail,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.type,
    this.metadata,
  });

  factory GroupChatMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupChatMessage(
      senderEmail: d['sender_email'] ?? '',
      senderName: d['sender_name'] ?? 'Member',
      message: d['message'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: d['type'] ?? 'text',
      metadata: d['metadata'] as Map<String, dynamic>?,
    );
  }
}

class GroupChatService {
  static final _db = FirebaseFirestore.instance;

  static String get _email =>
      FirebaseAuth.instance.currentUser?.email ?? 'unknown';

  static String get _name {
    final u = FirebaseAuth.instance.currentUser;
    return u?.displayName ?? u?.email?.split('@').first ?? 'Member';
  }

  static CollectionReference<Map<String, dynamic>> _col(int groupId) =>
      _db.collection('group_chats').doc('group_$groupId').collection('messages');

  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(int groupId) =>
      _col(groupId).orderBy('timestamp').snapshots();

  static Future<void> sendText(int groupId, String text) =>
      _col(groupId).add({
        'sender_email': _email,
        'sender_name': _name,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

  static Future<void> shareGoal(int groupId, String goal) =>
      _col(groupId).add({
        'sender_email': _email,
        'sender_name': _name,
        'message': '🎯 Goal: $goal',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'goal',
        'metadata': {'goal': goal},
      });

  static Future<void> postSessionSummary({
    required int groupId,
    required String senderEmail,
    required String senderName,
    required int focusedMinutes,
    String? taskName,
  }) {
    final label = taskName != null ? '"$taskName"' : 'a focus session';
    return _col(groupId).add({
      'sender_email': senderEmail,
      'sender_name': senderName,
      'message': '✅ Completed $label — ${focusedMinutes}m focused',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'session_summary',
      'metadata': {
        'focused_minutes': focusedMinutes,
        'task_name': taskName,
      },
    });
  }
}
