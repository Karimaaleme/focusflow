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
  final picker = ImagePicker();

  Uint8List? newImage;
  String? selectedUserType;
  late List<String> goals;

  final allUserTypes = ["Student", "Employee", "Freelancer", "Other"];
  final allGoals = [
    "Studies",
    "Work",
    "Health",
    "Fitness",
    "Personal Projects",
    "Habits",
  ];

  @override
  void initState() {
    super.initState();
    selectedUserType = widget.profile.userType;
    goals = List<String>.from(widget.profile.goals);
    newImage = widget.profile.profileImageBytes;
  }

  Future<void> pickImage() async {
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => newImage = bytes);
    }
  }

  Future<void> saveChanges() async {
    if (selectedUserType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select user type")));
      return;
    }

    await ApiService.saveProfile(
      token: widget.token, // 👈 CORRECT
      userType: selectedUserType!,
      goals: goals,
      imageBase64: newImage != null ? base64Encode(newImage!) : null,
    );

    Navigator.pop(
      context,
      UserProfile(
        email: widget.profile.email,
        userType: selectedUserType!,
        goals: goals,
        profileImageBytes: newImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: newImage != null
                      ? MemoryImage(newImage!)
                      : null,
                  child: newImage == null
                      ? const Icon(Icons.camera_alt, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "I am mainly a:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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

              const SizedBox(height: 20),

              const Text(
                "My goals:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: allGoals.map((goal) {
                  final selected = goals.contains(goal);
                  return FilterChip(
                    label: Text(goal),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        value ? goals.add(goal) : goals.remove(goal);
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 30),
              ElevatedButton(onPressed: saveChanges, child: const Text("Save")),
            ],
          ),
        ),
      ),
    );
  }
}
