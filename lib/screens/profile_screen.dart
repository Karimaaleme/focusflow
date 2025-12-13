import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
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
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool loading = true;

  @override
  void initState() {
    super.initState();

    if (widget.profile != null) {
      _profile = widget.profile;
      loading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final p =
          await ApiService.loadProfile(widget.token, widget.fallbackEmail);
      if (!mounted) return;
      setState(() {
        _profile = p;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final email = _profile?.email ?? widget.fallbackEmail;
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
                backgroundImage: _profile?.profileImageBytes != null
                    ? MemoryImage(_profile!.profileImageBytes!)
                    : null,
                child: _profile?.profileImageBytes == null
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

            if (_profile != null) ...[
              const Text(
                "User Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(_profile!.userType, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),

              const Text(
                "Goals",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _profile!.goals
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
                "No profile details yet.",
                style: TextStyle(fontSize: 14),
              ),
            ],

            const Spacer(),

            Center(
              child: ElevatedButton(
                onPressed: _profile == null
                    ? null
                    : () async {
                        final updatedProfile =
                            await Navigator.push<UserProfile?>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(
                              profile: _profile!,
                              token: widget.token,
                            ),
                          ),
                        );

                        if (updatedProfile != null && mounted) {
                          setState(() => _profile = updatedProfile);
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
