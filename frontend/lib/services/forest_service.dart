import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/forest_tree.dart';
import '../models/forest_achievement.dart';
import '../models/focus_room.dart';
import 'user_display_service.dart';

class ForestService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser?.uid ?? '';

  // ── Collection references ──────────────────────────────────

  static CollectionReference get _treesRef =>
      _db.collection('users').doc(_uid).collection('forest_trees');

  static DocumentReference get _profileRef =>
      _db.collection('users').doc(_uid).collection('forest_data').doc('profile');

  static CollectionReference get _achievementsRef =>
      _db.collection('users').doc(_uid).collection('achievements');

  static CollectionReference get _leaderboardRef =>
      _db.collection('leaderboard');

  static CollectionReference get _roomsRef =>
      _db.collection('focus_rooms');

  // ── Forest Profile ─────────────────────────────────────────

  static Future<ForestProfile> getProfile() async {
    final doc = await _profileRef.get();
    if (!doc.exists) return ForestProfile.empty();
    return ForestProfile.fromFirestore(doc.data() as Map<String, dynamic>);
  }

  static Stream<ForestProfile> profileStream() {
    return _profileRef.snapshots().map((doc) {
      if (!doc.exists) return ForestProfile.empty();
      return ForestProfile.fromFirestore(doc.data() as Map<String, dynamic>);
    });
  }

  /// Sync the user's current display name into the Firestore forest profile
  /// and leaderboard so both stay up-to-date when the username changes.
  static Future<void> syncUsername() async {
    if (_uid.isEmpty) return;
    final name = await UserDisplayService.getMyDisplayName();
    try {
      await _profileRef.set({
        'username': name,
        'display_name': name,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _leaderboardRef.doc(_uid).set({
        'username': name,
        'display_name': name,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Save a completed session ───────────────────────────────

  static Future<SessionReward> saveCompletedSession({
    required String plantType,
    required int focusedMinutes,
    required int plannedMinutes,
    required bool isSuccess,
    String? taskTitle,
  }) async {
    final username = await UserDisplayService.getMyDisplayName();
    final profile = await getProfile();
    final efficiency = plannedMinutes > 0 ? focusedMinutes / plannedMinutes : 0.0;
    final coins = ForestTree.computeCoins(focusedMinutes, efficiency);
    final xp = ForestTree.computeXP(focusedMinutes, profile.currentStreak);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int newStreak = profile.currentStreak;
    if (isSuccess) {
      newStreak = profile.currentStreak + 1;
    }

    // Save tree
    final treeData = ForestTree(
      id: '',
      plantType: plantType,
      focusedMinutes: focusedMinutes,
      plannedMinutes: plannedMinutes,
      isSuccess: isSuccess,
      taskTitle: taskTitle,
      coinsEarned: isSuccess ? coins : 0,
      xpEarned: isSuccess ? xp : 0,
      completedAt: now,
    );
    await _treesRef.add(treeData.toFirestore());

    // Update profile (keep username in sync)
    final newProfile = {
      'username': username,
      'display_name': username,
      'total_coins': FieldValue.increment(isSuccess ? coins : 0),
      'total_xp': FieldValue.increment(isSuccess ? xp : 0),
      'current_streak': isSuccess ? newStreak : 0,
      'longest_streak': FieldValue.increment(0),
      'total_focus_minutes': FieldValue.increment(isSuccess ? focusedMinutes : 0),
      'total_sessions': FieldValue.increment(1),
      'completed_sessions': FieldValue.increment(isSuccess ? 1 : 0),
      'weekly_minutes': FieldValue.increment(isSuccess ? focusedMinutes : 0),
      'weekly_sessions': FieldValue.increment(isSuccess ? 1 : 0),
      'last_session_date': Timestamp.fromDate(today),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await _profileRef.set(newProfile, SetOptions(merge: true));

    if (isSuccess && newStreak > profile.longestStreak) {
      await _profileRef.update({'longest_streak': newStreak});
    }

    await _updateLeaderboard(username, focusedMinutes, isSuccess, newStreak);

    final newlyUnlocked = await _checkAndUpdateAchievements(
      completedSessions: profile.completedSessions + (isSuccess ? 1 : 0),
      totalFocusMinutes: profile.totalFocusMinutes + (isSuccess ? focusedMinutes : 0),
      currentStreak: isSuccess ? newStreak : 0,
    );

    return SessionReward(
      coinsEarned: isSuccess ? coins : 0,
      xpEarned: isSuccess ? xp : 0,
      newStreak: isSuccess ? newStreak : 0,
      efficiency: efficiency,
      newAchievements: newlyUnlocked,
    );
  }

  static Future<void> _updateLeaderboard(
    String username,
    int focusedMinutes,
    bool isSuccess,
    int newStreak,
  ) async {
    if (_uid.isEmpty) return;
    try {
      await _leaderboardRef.doc(_uid).set({
        'uid': _uid,
        'username': username,
        'display_name': username,
        'total_focus_minutes': FieldValue.increment(isSuccess ? focusedMinutes : 0),
        'completed_sessions': FieldValue.increment(isSuccess ? 1 : 0),
        'current_streak': isSuccess ? newStreak : 0,
        'weekly_minutes': FieldValue.increment(isSuccess ? focusedMinutes : 0),
        'weekly_sessions': FieldValue.increment(isSuccess ? 1 : 0),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Trees ──────────────────────────────────────────────────

  static Future<List<ForestTree>> getTrees() async {
    final snap = await _treesRef
        .orderBy('completed_at', descending: true)
        .get();
    return snap.docs.map((d) => ForestTree.fromFirestore(d)).toList();
  }

  static Stream<List<ForestTree>> treesStream() {
    return _treesRef
        .orderBy('completed_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ForestTree.fromFirestore(d)).toList());
  }

  // ── Achievements ───────────────────────────────────────────

  static Future<List<ForestAchievement>> getAchievements() async {
    final defs = ForestAchievement.definitions();
    final List<ForestAchievement> result = [];

    for (final def in defs) {
      final doc = await _achievementsRef.doc(def['id'] as String).get();
      final data = doc.exists ? (doc.data() as Map<String, dynamic>) : <String, dynamic>{};
      result.add(ForestAchievement.fromFirestore(def['id'] as String, data, def));
    }
    return result;
  }

  static Future<List<String>> _checkAndUpdateAchievements({
    required int completedSessions,
    required int totalFocusMinutes,
    required int currentStreak,
  }) async {
    final defs = ForestAchievement.definitions();
    final newlyUnlocked = <String>[];

    final metricValues = {
      'completed_sessions': completedSessions,
      'total_focus_minutes': totalFocusMinutes,
      'current_streak': currentStreak,
    };

    final batch = _db.batch();

    for (final def in defs) {
      final id = def['id'] as String;
      final metric = def['metric'] as String;
      final target = def['target'] as int;
      final currentValue = metricValues[metric] ?? 0;
      final progress = (currentValue / target).clamp(0.0, 1.0);

      final docRef = _achievementsRef.doc(id);
      final doc = await docRef.get();
      final alreadyUnlocked = doc.exists && ((doc.data() as Map<String, dynamic>)['unlocked'] ?? false);

      if (!alreadyUnlocked && currentValue >= target) {
        newlyUnlocked.add(def['title'] as String);
        batch.set(docRef, {
          'unlocked': true,
          'progress': 1.0,
          'unlocked_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (!alreadyUnlocked) {
        batch.set(docRef, {
          'progress': progress,
          'unlocked': false,
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
    return newlyUnlocked;
  }

  // ── Leaderboard ────────────────────────────────────────────

  static Future<List<LeaderboardEntry>> getLeaderboard({bool weekly = false}) async {
    final field = weekly ? 'weekly_minutes' : 'total_focus_minutes';
    final snap = await _leaderboardRef
        .orderBy(field, descending: true)
        .limit(50)
        .get();

    return snap.docs.asMap().entries.map((e) {
      final d = e.value.data() as Map<String, dynamic>;
      return LeaderboardEntry(
        rank: e.key + 1,
        uid: e.value.id,
        username: d['username'] as String? ?? '',
        displayName: d['display_name'] as String? ?? d['username'] as String? ?? '',
        totalFocusMinutes: d['total_focus_minutes'] as int? ?? 0,
        completedSessions: d['completed_sessions'] as int? ?? 0,
        currentStreak: d['current_streak'] as int? ?? 0,
        weeklyMinutes: d['weekly_minutes'] as int? ?? 0,
        weeklySessions: d['weekly_sessions'] as int? ?? 0,
      );
    }).toList();
  }

  static Future<int> getMyRank({bool weekly = false}) async {
    final entries = await getLeaderboard(weekly: weekly);
    final idx = entries.indexWhere((e) => e.uid == _uid);
    return idx == -1 ? entries.length + 1 : idx + 1;
  }

  // ── Focus Rooms ────────────────────────────────────────────

  static Future<FocusRoom> createRoom({
    required String name,
    required int durationMinutes,
    required String plantType,
    required String hostName,
  }) async {
    final code = _generateCode();
    final ref = await _roomsRef.add({
      'host_uid': _uid,
      'host_name': hostName,
      'name': name,
      'duration_minutes': durationMinutes,
      'plant_type': plantType,
      'status': 'waiting',
      'invite_code': code,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await ref.collection('members').doc(_uid).set({
      'display_name': hostName,
      'plant_type': plantType,
      'status': 'ready',
      'joined_at': FieldValue.serverTimestamp(),
    });

    // Post join announcement
    await _postAnnouncement(ref.id, '$hostName created the room 🌱');

    final doc = await ref.get();
    return FocusRoom.fromFirestore(doc);
  }

  static Future<FocusRoom?> joinRoomByCode(String code, String displayName, String plantType) async {
    final snap = await _roomsRef
        .where('invite_code', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    await doc.reference.collection('members').doc(_uid).set({
      'display_name': displayName,
      'plant_type': plantType,
      'status': 'ready',
      'joined_at': FieldValue.serverTimestamp(),
    });

    await _postAnnouncement(doc.id, '$displayName joined the room 👋');

    return FocusRoom.fromFirestore(doc);
  }

  /// Fetch the current user's recent rooms (last 10), any status.
  static Future<List<FocusRoom>> getMyRooms() async {
    if (_uid.isEmpty) return [];
    try {
      // Rooms where I'm the host
      final hostSnap = await _roomsRef
          .where('host_uid', isEqualTo: _uid)
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();

      // Rooms where I'm a member (sub-collection query workaround: stored member doc)
      // We use a top-level collection group query approach via collectionGroup
      final memberSnap = await _db
          .collectionGroup('members')
          .where(FieldPath.documentId, isEqualTo: _uid)
          .limit(20)
          .get();

      final Set<String> seen = {};
      final List<FocusRoom> rooms = [];

      for (final doc in hostSnap.docs) {
        if (seen.add(doc.id)) {
          rooms.add(FocusRoom.fromFirestore(doc));
        }
      }

      for (final memberDoc in memberSnap.docs) {
        final roomRef = memberDoc.reference.parent.parent;
        if (roomRef == null) continue;
        if (!seen.add(roomRef.id)) continue;
        final roomDoc = await roomRef.get();
        if (roomDoc.exists) {
          rooms.add(FocusRoom.fromFirestore(roomDoc));
        }
      }

      rooms.sort((a, b) {
        final ta = a.createdAt ?? DateTime(2000);
        final tb = b.createdAt ?? DateTime(2000);
        return tb.compareTo(ta);
      });

      return rooms.take(10).toList();
    } catch (_) {
      return [];
    }
  }

  static Stream<List<FocusRoomMember>> roomMembersStream(String roomId) {
    return _roomsRef
        .doc(roomId)
        .collection('members')
        .snapshots()
        .map((s) => s.docs.map((d) => FocusRoomMember.fromFirestore(d)).toList());
  }

  static Stream<FocusRoom> roomStream(String roomId) {
    return _roomsRef.doc(roomId).snapshots().map((d) => FocusRoom.fromFirestore(d));
  }

  static Future<void> updateRoomMemberStatus(String roomId, String status) async {
    await _roomsRef
        .doc(roomId)
        .collection('members')
        .doc(_uid)
        .update({'status': status, 'updated_at': FieldValue.serverTimestamp()});
  }

  static Future<void> startRoom(String roomId) async {
    await _roomsRef.doc(roomId).update({
      'status': 'active',
      'start_time': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    await updateRoomMemberStatus(roomId, 'focusing');
  }

  /// Mark the room as completed (host only action).
  static Future<void> endRoomAsHost(String roomId) async {
    await _roomsRef.doc(roomId).update({
      'status': 'completed',
      'ended_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> completeRoom(String roomId, bool success) async {
    await updateRoomMemberStatus(roomId, success ? 'completed' : 'failed');
  }

  static Future<void> leaveRoom(String roomId, String displayName) async {
    await _roomsRef.doc(roomId).collection('members').doc(_uid).delete();
    await _postAnnouncement(roomId, '$displayName left the room 🚪');
  }

  /// Post a system-level announcement into the room chat.
  static Future<void> _postAnnouncement(String roomId, String text) async {
    try {
      await _roomsRef.doc(roomId).collection('messages').add({
        'sender_uid': 'system',
        'sender_name': 'Room',
        'message': text,
        'is_announcement': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Public wrapper used by screens
  static Future<void> sendRoomAnnouncement(String roomId, String text) =>
      _postAnnouncement(roomId, text);

  // ── Helpers ────────────────────────────────────────────────

  static String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}

// ── Data classes ──────────────────────────────────────────────

class SessionReward {
  final int coinsEarned;
  final int xpEarned;
  final int newStreak;
  final double efficiency;
  final List<String> newAchievements;

  const SessionReward({
    required this.coinsEarned,
    required this.xpEarned,
    required this.newStreak,
    required this.efficiency,
    required this.newAchievements,
  });
}

class LeaderboardEntry {
  final int rank;
  final String uid;
  final String username;
  final String displayName;
  final int totalFocusMinutes;
  final int completedSessions;
  final int currentStreak;
  final int weeklyMinutes;
  final int weeklySessions;

  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.username,
    required this.displayName,
    required this.totalFocusMinutes,
    required this.completedSessions,
    required this.currentStreak,
    required this.weeklyMinutes,
    required this.weeklySessions,
  });
}
