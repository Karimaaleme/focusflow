import 'dart:typed_data';

class UserProfile {
  final String email;
  final String userType;
  final List<String> goals;
  final Uint8List? profileImageBytes;

  // ✅ NEW optional fields (safe & backward compatible)
  final String? focusStyle;
  final String? mainStruggle;
  final String? bestTimeOfDay;
  final String? motivation;
  final String? theme;

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
    };
  }
}
