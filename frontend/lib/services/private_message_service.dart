import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivateMessage {
  final String senderEmail;
  final String senderName;
  final String message;
  final DateTime timestamp;

  PrivateMessage({
    required this.senderEmail,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  factory PrivateMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PrivateMessage(
      senderEmail: d['sender_email'] ?? '',
      senderName: d['sender_name'] ?? 'Member',
      message: d['message'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class PrivateMessageService {
  static final _db = FirebaseFirestore.instance;

  static String get _myEmail =>
      FirebaseAuth.instance.currentUser?.email ?? '';

  static String get _myName {
    final u = FirebaseAuth.instance.currentUser;
    return u?.displayName ?? u?.email?.split('@').first ?? 'Me';
  }

  /// Deterministic chat ID: always sorted so A↔B == B↔A
  static String chatId(String emailA, String emailB) {
    final sorted = [emailA, emailB]..sort();
    return sorted.join('__');
  }

  static CollectionReference<Map<String, dynamic>> _col(String otherEmail) =>
      _db
          .collection('private_chats')
          .doc(chatId(_myEmail, otherEmail))
          .collection('messages');

  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(String otherEmail) =>
      _col(otherEmail).orderBy('timestamp').snapshots();

  static Future<void> send(String otherEmail, String text) =>
      _col(otherEmail).add({
        'sender_email': _myEmail,
        'sender_name': _myName,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

  /// Returns a stream of recent DM conversations (last message per partner).
  /// Firestore doesn't support cross-collection queries, so we track
  /// conversation partners in a user-level doc.
  static Future<void> markConversation(String otherEmail, String otherName) =>
      _db
          .collection('dm_conversations')
          .doc(_myEmail)
          .collection('partners')
          .doc(otherEmail)
          .set({
        'partner_email': otherEmail,
        'partner_name': otherName,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  static Stream<QuerySnapshot<Map<String, dynamic>>> conversationsStream() =>
      _db
          .collection('dm_conversations')
          .doc(_myEmail)
          .collection('partners')
          .orderBy('updated_at', descending: true)
          .snapshots();
}
