import 'package:cloud_firestore/cloud_firestore.dart';

class ForestTree {
  final String id;
  final String plantType; // oak, pine, bonsai, flower, cherry, cactus
  final int focusedMinutes;
  final int plannedMinutes;
  final bool isSuccess;
  final String? taskTitle;
  final int coinsEarned;
  final int xpEarned;
  final DateTime completedAt;

  const ForestTree({
    required this.id,
    required this.plantType,
    required this.focusedMinutes,
    required this.plannedMinutes,
    required this.isSuccess,
    this.taskTitle,
    required this.coinsEarned,
    required this.xpEarned,
    required this.completedAt,
  });

  factory ForestTree.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ForestTree(
      id: doc.id,
      plantType: d['plant_type'] ?? 'oak',
      focusedMinutes: d['focused_minutes'] ?? 0,
      plannedMinutes: d['planned_minutes'] ?? 25,
      isSuccess: d['is_success'] ?? false,
      taskTitle: d['task_title'],
      coinsEarned: d['coins_earned'] ?? 0,
      xpEarned: d['xp_earned'] ?? 0,
      completedAt: (d['completed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'plant_type': plantType,
    'focused_minutes': focusedMinutes,
    'planned_minutes': plannedMinutes,
    'is_success': isSuccess,
    if (taskTitle != null) 'task_title': taskTitle,
    'coins_earned': coinsEarned,
    'xp_earned': xpEarned,
    'completed_at': Timestamp.fromDate(completedAt),
  };

  String get emoji {
    if (!isSuccess) return '🥀';
    switch (plantType) {
      case 'pine': return '🌲';
      case 'bonsai': return '🪴';
      case 'flower': return '🌺';
      case 'cherry': return '🌸';
      case 'cactus': return '🌵';
      default: return '🌳';
    }
  }

  String get label {
    switch (plantType) {
      case 'pine': return 'Pine';
      case 'bonsai': return 'Bonsai';
      case 'flower': return 'Flower';
      case 'cherry': return 'Cherry';
      case 'cactus': return 'Cactus';
      default: return 'Oak';
    }
  }

  static int computeCoins(int focusedMinutes, double efficiency) {
    final base = (focusedMinutes * 2.0).round();
    final bonus = efficiency >= 1.0 ? (base * 0.25).round() : 0;
    return base + bonus;
  }

  static int computeXP(int focusedMinutes, int streakDays) {
    final base = (focusedMinutes * 3.0).round();
    final streakMult = streakDays >= 30
        ? 2.0
        : streakDays >= 14
            ? 1.5
            : streakDays >= 7
                ? 1.25
                : streakDays >= 3
                    ? 1.1
                    : 1.0;
    return (base * streakMult).round();
  }
}

class ForestProfile {
  final int totalCoins;
  final int totalXP;
  final int currentStreak;
  final int longestStreak;
  final int totalFocusMinutes;
  final int totalSessions;
  final int completedSessions;
  final int weeklyMinutes;
  final int weeklySessions;
  final String username;
  final String? displayName;

  const ForestProfile({
    required this.totalCoins,
    required this.totalXP,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalFocusMinutes,
    required this.totalSessions,
    required this.completedSessions,
    required this.weeklyMinutes,
    required this.weeklySessions,
    required this.username,
    this.displayName,
  });

  factory ForestProfile.fromFirestore(Map<String, dynamic> d) => ForestProfile(
        totalCoins: d['total_coins'] ?? 0,
        totalXP: d['total_xp'] ?? 0,
        currentStreak: d['current_streak'] ?? 0,
        longestStreak: d['longest_streak'] ?? 0,
        totalFocusMinutes: d['total_focus_minutes'] ?? 0,
        totalSessions: d['total_sessions'] ?? 0,
        completedSessions: d['completed_sessions'] ?? 0,
        weeklyMinutes: d['weekly_minutes'] ?? 0,
        weeklySessions: d['weekly_sessions'] ?? 0,
        username: d['username'] ?? '',
        displayName: d['display_name'],
      );

  factory ForestProfile.empty() => const ForestProfile(
        totalCoins: 0,
        totalXP: 0,
        currentStreak: 0,
        longestStreak: 0,
        totalFocusMinutes: 0,
        totalSessions: 0,
        completedSessions: 0,
        weeklyMinutes: 0,
        weeklySessions: 0,
        username: '',
      );

  Map<String, dynamic> toFirestore() => {
        'total_coins': totalCoins,
        'total_xp': totalXP,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'total_focus_minutes': totalFocusMinutes,
        'total_sessions': totalSessions,
        'completed_sessions': completedSessions,
        'weekly_minutes': weeklyMinutes,
        'weekly_sessions': weeklySessions,
        'username': username,
        if (displayName != null) 'display_name': displayName,
      };

  int get level => (totalXP / 500).floor() + 1;
  int get xpToNextLevel => 500 - (totalXP % 500);
  double get levelProgress => (totalXP % 500) / 500.0;
}