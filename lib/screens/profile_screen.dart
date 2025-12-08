import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final UserProfile? profile;
  final String fallbackEmail;
  final String token; 

  const ProfileScreen({
    super.key,
    this.profile,
    required this.token,
    this.fallbackEmail = '',
  });

  @override
  Widget build(BuildContext context) {
    final email = profile?.email ?? fallbackEmail;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blueGrey[200],
                backgroundImage: profile?.profileImageBytes != null
                    ? MemoryImage(profile!.profileImageBytes!)
                    : null,
                child: profile?.profileImageBytes == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            Center(
              child: Text(
                email.isNotEmpty ? email : 'No email',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (profile != null) ...[
              const Text(
                "User Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(profile!.userType, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),

              const Text(
                "Goals",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: profile!.goals
                    .map(
                      (g) => Chip(
                        label: Text(g),
                        backgroundColor: Colors.blue[50],
                      ),
                    )
                    .toList(),
              ),
            ] else ...[
              const Text(
                "No extra profile details yet.\nComplete onboarding to set goals and user type.",
                style: TextStyle(fontSize: 14),
              ),
            ],

            const Spacer(),

            Center(
              child: ElevatedButton(
                onPressed: () async {
                  print("Edit button pressed!");
                  if (profile == null) return;

                  final updatedProfile = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        profile: profile!,
                        token: token, // <-- REQUIRED
                      ),
                    ),
                  );

                  if (updatedProfile != null) {
                    Navigator.pop(context, updatedProfile);
                  }
                },
                child: const Text("Edit Profile"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
