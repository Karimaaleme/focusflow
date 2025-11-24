import 'dart:typed_data';

class UserProfile {
  final String email;
  final String userType;
  final List<String> goals;
  final Uint8List? profileImageBytes;

  UserProfile({
    required this.email,
    required this.userType,
    required this.goals,
    this.profileImageBytes,
  });
}
