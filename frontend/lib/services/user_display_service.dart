import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';

/// Single source of truth for the current user's public display name.
/// Priority: Firebase displayName → backend username → email prefix.
/// Never exposes the full email address in the UI.
class UserDisplayService {
  static String? _cached;

  static Future<String> getMyDisplayName() async {
    if (_cached != null) return _cached!;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'User';

    // 1. Firebase Auth displayName (set during signup / updated on profile save)
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _cached = user.displayName!;
      _syncToFirestore(_cached!);
      return _cached!;
    }

    // 2. Backend profile (username preferred, then nothing else is returned)
    try {
      final profile = await ApiService.loadProfile(user.email ?? '');
      final name = profile.username?.isNotEmpty == true ? profile.username : null;
      if (name != null) {
        await user.updateDisplayName(name);
        _cached = name;
        _syncToFirestore(_cached!);
        return _cached!;
      }
    } catch (_) {}

    // 3. Email prefix — readable, never exposes full email
    final email = user.email ?? '';
    _cached = email.contains('@') ? email.split('@')[0] : (email.isNotEmpty ? email : 'User');
    _syncToFirestore(_cached!);
    return _cached!;
  }

  /// Synchronous read — returns cached value or Firebase displayName.
  static String getSync() {
    if (_cached != null) return _cached!;
    final u = FirebaseAuth.instance.currentUser;
    if (u?.displayName != null && u!.displayName!.isNotEmpty) return u.displayName!;
    return 'User';
  }

  /// Call on logout so the next login fetches fresh data.
  static void invalidate() => _cached = null;

  /// Push the resolved display name into the Firestore forest profile and
  /// leaderboard entry so they always reflect the current username.
  static void _syncToFirestore(String name) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || name.isEmpty) return;
    final db = FirebaseFirestore.instance;
    // Fire-and-forget — do not await, never block the caller
    db
        .collection('users')
        .doc(uid)
        .collection('forest_data')
        .doc('profile')
        .set({'username': name, 'display_name': name}, SetOptions(merge: true))
        .catchError((_) {});
    db
        .collection('leaderboard')
        .doc(uid)
        .set({'username': name, 'display_name': name, 'uid': uid},
            SetOptions(merge: true))
        .catchError((_) {});
  }
}
