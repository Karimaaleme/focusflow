import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

/// Single source of truth for the current user's public display name.
/// Priority: Firebase displayName → backend username → backend fullName → "User_<uid6>"
/// Never exposes the email address.
class UserDisplayService {
  static String? _cached;

  static Future<String> getMyDisplayName() async {
    if (_cached != null) return _cached!;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'User';

    // 1. Firebase Auth displayName (set during signup / updated on profile save)
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _cached = user.displayName!;
      return _cached!;
    }

    // 2. Backend profile (username or fullName)
    try {
      final profile = await ApiService.loadProfile(user.email ?? '');
      final name = profile.username?.isNotEmpty == true
          ? profile.username!
          : (profile.fullName?.isNotEmpty == true ? profile.fullName : null);
      if (name != null) {
        // Sync back to Firebase so subsequent calls are instant
        await user.updateDisplayName(name);
        _cached = name;
        return _cached!;
      }
    } catch (_) {}

    // 3. Use email prefix — looks like a real name, never exposes full email
    final email = user.email ?? '';
    _cached = email.contains('@') ? email.split('@')[0] : (email.isNotEmpty ? email : 'User');
    return _cached!;
  }

  /// Synchronous read — returns cached value or Firebase displayName.
  /// Use only when you cannot await (e.g. inside synchronous getters).
  static String getSync() {
    if (_cached != null) return _cached!;
    final u = FirebaseAuth.instance.currentUser;
    if (u?.displayName != null && u!.displayName!.isNotEmpty) return u.displayName!;
    return 'User';
  }

  /// Call on logout so the next login fetches fresh data.
  static void invalidate() => _cached = null;
}
