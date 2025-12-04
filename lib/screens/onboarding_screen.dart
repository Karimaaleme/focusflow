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

  Uint8List? _profileImageBytes;
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
  }

  Future<void> _finishOnboarding() async {
    if (_selectedUserType == null || _selectedGoals.isEmpty) {
      setState(() {
        _error = 'Please choose user type and at least one goal.';
      });
      return;
    }

    Navigator.pop(
      context,
      UserProfile(
        email: widget.email,
        userType: _selectedUserType!,
        goals: _selectedGoals.toList(),
        profileImageBytes: _profileImageBytes,
      ),
    );
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
            Center(
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: CircleAvatar(
                  radius: 45,
                  backgroundImage: _profileImageBytes != null
                      ? MemoryImage(_profileImageBytes!)
                      : null,
                  child: _profileImageBytes == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Welcome, ${widget.email}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 20),

            const Text(
              'I am mainly a:',
              style: TextStyle(fontWeight: FontWeight.bold),
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
                    setState(() => _selectedUserType = type);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            const Text(
              'My main goals:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: goals.map((goal) {
                final isSelected = _selectedGoals.contains(goal);
                return FilterChip(
                  label: Text(goal),
                  selected: isSelected,
                  onSelected: (v) {
                    setState(() {
                      v
                          ? _selectedGoals.add(goal)
                          : _selectedGoals.remove(goal);
                    });
                  },
                );
              }).toList(),
            ),

            const Spacer(),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finishOnboarding,
                child: const Text("Start Using FocusFlow"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
