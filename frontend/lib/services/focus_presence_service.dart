import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FocusPresenceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _currentEmail =>
      FirebaseAuth.instance.currentUser?.email ?? 'unknown';

  static CollectionReference<Map<String, dynamic>> _groupRef(int groupId) =>
      _db
          .collection('focus_presence')
          .doc('group_$groupId')
          .collection('members')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data()!,
            toFirestore: (data, _) => data,
          );

  static Future<void> startFocusing({
    required int groupId,
    required String displayName,
  }) async {
    await _db
        .collection('focus_presence')
        .doc('group_$groupId')
        .collection('members')
        .doc(_currentEmail)
        .set({
      'is_focusing': true,
      'started_at': FieldValue.serverTimestamp(),
      'display_name': displayName,
      'email': _currentEmail,
    });
  }

  static Future<void> stopFocusing(int groupId) async {
    try {
      await _db
          .collection('focus_presence')
          .doc('group_$groupId')
          .collection('members')
          .doc(_currentEmail)
          .set({
        'is_focusing': false,
        'started_at': null,
        'email': _currentEmail,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> presenceStream(
      int groupId) {
    return _db
        .collection('focus_presence')
        .doc('group_$groupId')
        .collection('members')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data()!,
          toFirestore: (data, _) => data,
        )
        .snapshots();
  }
}
