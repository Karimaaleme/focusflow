import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final String token;

  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.token,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? newImage;
  String? selectedUserType;
  late List<String> goals;

  // Extended profile fields
  String? focusStyle;
  String? mainStruggle;
  String? bestTimeOfDay;
  String? motivation;
  String? theme;

  final allUserTypes = ["Student", "Employee", "Freelancer", "Other"];

  final allGoals = [
    "Studies",
    "Work",
    "Health",
    "Fitness",
    "Personal Projects",
    "Habits",
    "Reading",
    "Side Hustle",
    "Mindfulness",
  ];

  @override
  void initState() {
    super.initState();

    selectedUserType = widget.profile.userType;
    goals = List<String>.from(widget.profile.goals);
    newImage = widget.profile.profileImageBytes;

    focusStyle = widget.profile.focusStyle;
    mainStruggle = widget.profile.mainStruggle;
    bestTimeOfDay = widget.profile.bestTimeOfDay;
    motivation = widget.profile.motivation;
    theme = widget.profile.theme;
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => newImage = bytes);
    }
  }

  Future<void> _saveChanges() async {
    if (selectedUserType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a user type")),
      );
      return;
    }

    await ApiService.saveProfile(
      token: widget.token,
      userType: selectedUserType!,
      goals: goals,
      imageBase64: newImage != null ? base64Encode(newImage!) : null,
      focusStyle: focusStyle,
      mainStruggle: mainStruggle,
      bestTimeOfDay: bestTimeOfDay,
      motivation: motivation,
      theme: theme,
    );

    if (!mounted) return;

    Navigator.pop(
      context,
      UserProfile(
        email: widget.profile.email,
        userType: selectedUserType!,
        goals: goals,
        profileImageBytes: newImage,
        focusStyle: focusStyle,
        mainStruggle: mainStruggle,
        bestTimeOfDay: bestTimeOfDay,
        motivation: motivation,
        theme: theme,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _singleChoice({
    required List<_Option> options,
    required String? value,
    required void Function(String v) onPick,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        return ChoiceChip(
          label: Text(o.label),
          selected: value == o.value,
          onSelected: (_) => setState(() => onPick(o.value)),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: "Save",
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 56,
                  backgroundImage:
                      newImage != null ? MemoryImage(newImage!) : null,
                  child: newImage == null
                      ? const Icon(Icons.camera_alt, size: 38)
                      : null,
                ),
              ),
            ),

            _sectionTitle("I am mainly a"),
            Wrap(
              spacing: 8,
              children: allUserTypes.map((type) {
                return ChoiceChip(
                  label: Text(type),
                  selected: selectedUserType == type,
                  onSelected: (_) => setState(() => selectedUserType = type),
                );
              }).toList(),
            ),

            _sectionTitle("My goals"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allGoals.map((goal) {
                return FilterChip(
                  label: Text(goal),
                  selected: goals.contains(goal),
                  onSelected: (v) {
                    setState(() {
                      v ? goals.add(goal) : goals.remove(goal);
                    });
                  },
                );
              }).toList(),
            ),

            _sectionTitle("Focus style"),
            _singleChoice(
              value: focusStyle,
              onPick: (v) => focusStyle = v,
              options: const [
                _Option("Deep Focus", "deep_focus"),
                _Option("Pomodoro", "pomodoro"),
                _Option("Flexible", "flexible"),
              ],
            ),

            _sectionTitle("Biggest struggle"),
            _singleChoice(
              value: mainStruggle,
              onPick: (v) => mainStruggle = v,
              options: const [
                _Option("Distractions", "distractions"),
                _Option("Procrastination", "procrastination"),
                _Option("Burnout", "burnout"),
              ],
            ),

            _sectionTitle("Best time of day"),
            _singleChoice(
              value: bestTimeOfDay,
              onPick: (v) => bestTimeOfDay = v,
              options: const [
                _Option("Morning", "morning"),
                _Option("Afternoon", "afternoon"),
                _Option("Night", "night"),
              ],
            ),

            _sectionTitle("What motivates you"),
            _singleChoice(
              value: motivation,
              onPick: (v) => motivation = v,
              options: const [
                _Option("Grades", "grades"),
                _Option("Career", "career"),
                _Option("Freedom", "freedom"),
                _Option("Growth", "growth"),
                _Option("Mastery", "mastery"),
              ],
            ),

            _sectionTitle("Theme preference"),
            _singleChoice(
              value: theme,
              onPick: (v) => theme = v,
              options: const [
                _Option("Light", "light"),
                _Option("Dark", "dark"),
                _Option("Focus", "focus"),
                _Option("Calm", "calm"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Option {
  final String label;
  final String value;
  const _Option(this.label, this.value);
}
