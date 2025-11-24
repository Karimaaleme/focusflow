import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';

class OnboardingScreen extends StatefulWidget {
  final String email;

  const OnboardingScreen({super.key, required this.email});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedUserType;
  final Set<String> _selectedGoals = {};
  bool _loading = false;
  String? _error;

  Uint8List? _profileImageBytes; // 👈 holds picked image in memory
  final ImagePicker _picker = ImagePicker();

  final List<String> userTypes = ['Student', 'Employee', 'Freelancer', 'Other'];

  final List<String> goals = [
    'Studies',
    'Work',
    'Health',
    'Fitness',
    'Personal Projects',
    'Habits',
  ];

  Future<void> _pickProfileImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take a photo"),
                onTap: () async {
                  Navigator.pop(
                    context,
                    UserProfile(
                      email: widget.email,
                      userType: _selectedUserType!,
                      goals: _selectedGoals.toList(),
                      profileImageBytes: _profileImageBytes,
                    ),
                  );
                  final XFile? picked = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 75,
                  );
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    setState(() {
                      _profileImageBytes = bytes;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose from gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 75,
                  );
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    setState(() {
                      _profileImageBytes = bytes;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishOnboarding() async {
    if (_selectedUserType == null || _selectedGoals.isEmpty) {
      setState(() {
        _error = 'Please choose user type and at least one goal.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // כאן בהמשך אפשר:
      // 1. להעלות את התמונה לשרת (multipart upload)
      // 2. לשמור user_type + goals בפרופיל backend

      if (!mounted) return;
      Navigator.pop(context); // חוזר למסך הקודם (ואז ללוגין)
    } catch (e) {
      setState(() {
        _error = 'Failed to save preferences: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.email.isNotEmpty
        ? widget.email[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('FOCUSFLOW'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👇 Profile picture area
            Center(
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _profileImageBytes != null
                          ? MemoryImage(_profileImageBytes!)
                          : null,
                      child: _profileImageBytes == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Welcome, ${widget.email}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Let’s set up your focus profile:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),

            const Text(
              'I am mainly a…',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: userTypes.map((type) {
                final isSelected = _selectedUserType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedUserType = type;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            const Text(
              'My main goals:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: goals.map((goal) {
                final isSelected = _selectedGoals.contains(goal);
                return FilterChip(
                  label: Text(goal),
                  selected: isSelected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedGoals.add(goal);
                      } else {
                        _selectedGoals.remove(goal);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            const Spacer(),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _finishOnboarding,
                      child: const Text('Continue to login'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
