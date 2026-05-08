class ForestAchievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progress; // 0.0 to 1.0
  final String requirement;
  final int rewardCoins;

  const ForestAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
    required this.progress,
    required this.requirement,
    required this.rewardCoins,
  });

  factory ForestAchievement.fromFirestore(String id, Map<String, dynamic> d, Map<String, dynamic> def) {
    return ForestAchievement(
      id: id,
      title: def['title'] ?? '',
      description: def['description'] ?? '',
      icon: def['icon'] ?? '🏆',
      isUnlocked: d['unlocked'] ?? false,
      unlockedAt: d['unlocked_at'] != null
          ? (d['unlocked_at'] as dynamic).toDate()
          : null,
      progress: (d['progress'] ?? 0.0).toDouble(),
      requirement: def['requirement'] ?? '',
      rewardCoins: def['reward_coins'] ?? 50,
    );
  }

  static List<Map<String, dynamic>> definitions() => [
        {
          'id': 'first_tree',
          'title': 'First Seed',
          'description': 'Complete your very first focus session',
          'icon': '🌱',
          'requirement': '1 session',
          'reward_coins': 100,
          'target': 1,
          'metric': 'completed_sessions',
        },
        {
          'id': 'streak_7',
          'title': 'Week Warrior',
          'description': 'Focus for 7 consecutive days',
          'icon': '🔥',
          'requirement': '7-day streak',
          'reward_coins': 200,
          'target': 7,
          'metric': 'current_streak',
        },
        {
          'id': 'minutes_100',
          'title': 'Century Focuser',
          'description': 'Accumulate 100 total focus minutes',
          'icon': '⏱️',
          'requirement': '100 minutes',
          'reward_coins': 150,
          'target': 100,
          'metric': 'total_focus_minutes',
        },
        {
          'id': 'sessions_10',
          'title': 'Dedicated Grower',
          'description': 'Complete 10 focus sessions',
          'icon': '🌲',
          'requirement': '10 sessions',
          'reward_coins': 175,
          'target': 10,
          'metric': 'completed_sessions',
        },
        {
          'id': 'perfect_week',
          'title': 'Perfect Week',
          'description': 'Focus every day for 7 days straight',
          'icon': '👑',
          'requirement': 'Perfect week',
          'reward_coins': 300,
          'target': 7,
          'metric': 'current_streak',
        },
        {
          'id': 'minutes_500',
          'title': 'Focus Master',
          'description': 'Accumulate 500 total focus minutes',
          'icon': '🏆',
          'requirement': '500 minutes',
          'reward_coins': 400,
          'target': 500,
          'metric': 'total_focus_minutes',
        },
        {
          'id': 'sessions_50',
          'title': 'Forest Guardian',
          'description': 'Complete 50 focus sessions',
          'icon': '🌳',
          'requirement': '50 sessions',
          'reward_coins': 500,
          'target': 50,
          'metric': 'completed_sessions',
        },
        {
          'id': 'streak_30',
          'title': 'Monthly Master',
          'description': 'Maintain a 30-day focus streak',
          'icon': '💫',
          'requirement': '30-day streak',
          'reward_coins': 750,
          'target': 30,
          'metric': 'current_streak',
        },
        {
          'id': 'minutes_1000',
          'title': 'Zen Grandmaster',
          'description': 'Accumulate 1000 total focus minutes',
          'icon': '🧘',
          'requirement': '1000 minutes',
          'reward_coins': 1000,
          'target': 1000,
          'metric': 'total_focus_minutes',
        },
        {
          'id': 'sessions_100',
          'title': 'Century Club',
          'description': 'Complete 100 focus sessions',
          'icon': '🎖️',
          'requirement': '100 sessions',
          'reward_coins': 1000,
          'target': 100,
          'metric': 'completed_sessions',
        },
      ];
}