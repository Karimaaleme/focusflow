import 'dart:typed_data';

class UserProfile {
  final String email;
  final String userType;
  final List<String> goals;
  final Uint8List? profileImageBytes;

  // ✅ NEW optional fields (safe & backward compatible)
  // ✅ NEW optional fields (safe & backward compatible)
  final String? focusStyle;
  final String? mainStruggle;
  final String? bestTimeOfDay;
  final String? motivation;
  final String? theme;
  
  // ✅ NEW: Profile Update Fields
  final String? fullName;
  final bool notificationsPush;
  final bool notificationsEmail;
  final bool notificationsSummary;

  // ✅ NEW: Theme & UI Preferences
  final String? themeMode;    // 'light', 'dark', 'system'
  final String? accentColor;  // e.g. '#FF5722'
  final String? layoutDensity;// 'compact', 'spacious'

  // ✅ NEW: Goal Details (e.g. "Study" -> ["Exams", "Assignments"])
  final Map<String, List<String>>? goalDetails;

  UserProfile({
    required this.email,
    required this.userType,
    required this.goals,
    this.profileImageBytes,

    // NEW
    this.focusStyle,
    this.mainStruggle,
    this.bestTimeOfDay,
    this.motivation,
    this.theme,

    this.fullName,
    this.notificationsPush = false,
    this.notificationsEmail = false,
    this.notificationsSummary = false,
    this.goalDetails,

    this.themeMode,
    this.accentColor,
    this.layoutDensity,
  });

  /// Optional: helper for debugging / future backend mapping
  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "user_type": userType,
      "goals": goals,
      "focus_style": focusStyle,
      "main_struggle": mainStruggle,
      "best_time_of_day": bestTimeOfDay,
      "motivation": motivation,
      "theme": theme,
      "full_name": fullName,
      "notifications_push": notificationsPush,
      "notifications_email": notificationsEmail,
      "notifications_summary": notificationsSummary,
      "goal_details": goalDetails,
      "theme_mode": themeMode,
      "accent_color": accentColor,
      "layout_density": layoutDensity,
    };
  }
}
