// lib/screens/edit_profile_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/group_service.dart'; // NEW
import '../theme/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW
import '../widgets/gradient_header.dart';
import '../widgets/gradient_button.dart'; // NEW

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController(); 
  final TextEditingController _usernameController = TextEditingController(); // NEW

  Uint8List? newImage;
  String? selectedUserType;
  
  // Goals State
  late Set<String> _selectedPrimaryGoals;
  late Map<String, Set<String>> _selectedSubGoals;

  // Extended profile fields
  String? focusStyle;
  String? mainStruggle;
  String? bestTimeOfDay;
  String? motivation;
  String? theme;
  String? themeMode;

  final allUserTypes = ["Student", "Employee", "Freelancer", "Other"];

  // Hierarchical Goals Definition
  final Map<String, List<String>> goalDefinitions = {
    'Study': ['Exams', 'Assignments', 'Lectures', 'Reading'],
    'Work': ['Meetings', 'Deep Work', 'Emails', 'Coding'],
    'Health': ['Gym', 'Walking', 'Sleep', 'Nutrition'],
    'Personal': ['Family', 'Home', 'Shopping', 'Self-care'],
    'Projects': ['Planning', 'Implementation', 'Testing', 'Delivery'],
    'Freelance': ['Client Work', 'Admin', 'Marketing', 'Learning'],
  };

  List<String> get _relevantGoalKeys {
    switch (selectedUserType) {
      case 'Student':
        return ['Study', 'Health', 'Personal', 'Projects'];
      case 'Employee':
        return ['Work', 'Health', 'Personal', 'Projects'];
      case 'Freelancer':
        return ['Freelance', 'Work', 'Health', 'Personal'];
      default:
        return goalDefinitions.keys.toList();
    }
  }

  @override
  void initState() {
    super.initState();

    selectedUserType = widget.profile.userType;
    newImage = widget.profile.profileImageBytes;
    _nameController.text = widget.profile.fullName ?? ""; 
    _usernameController.text = widget.profile.username ?? ""; // NEW

    focusStyle = widget.profile.focusStyle;
    mainStruggle = widget.profile.mainStruggle;
    bestTimeOfDay = widget.profile.bestTimeOfDay;
    motivation = widget.profile.motivation;
    theme = widget.profile.theme;
    themeMode = widget.profile.themeMode ?? 'system';

    // Restore goals
    _selectedPrimaryGoals = widget.profile.goals.toSet();
    _selectedSubGoals = {};
    
    // Initialize empty maps for all definitions
    for (var key in goalDefinitions.keys) {
      _selectedSubGoals[key] = {};
    }

    // Populate from existing deep link
    if (widget.profile.goalDetails != null) {
      widget.profile.goalDetails!.forEach((key, value) {
        if (_selectedSubGoals.containsKey(key)) {
          _selectedSubGoals[key]!.addAll(value);
        }
      });
    }
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

    // 1. Update Username if changed (only allowed if it was empty before)
    bool originalWasEmpty = (widget.profile.username == null || widget.profile.username!.isEmpty);
    if (originalWasEmpty && _usernameController.text.trim().isNotEmpty) {
      try {
        await GroupService().updateUsername(_usernameController.text.trim());
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating username: $e"), backgroundColor: Colors.red),
        );
        return; // Stop saving other things if username fails
      }
    }

    // Prepare lists
    final goalDetails = _selectedSubGoals.map((key, value) => MapEntry(key, value.toList()));

    try {
      await ApiService.saveProfile(
        userType: selectedUserType!,
        goals: _selectedPrimaryGoals.toList(),
        fullName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(), 
        imageBase64: newImage != null ? base64Encode(newImage!) : null,
        focusStyle: focusStyle,
        mainStruggle: mainStruggle,
        bestTimeOfDay: bestTimeOfDay,
        motivation: motivation,
        theme: theme,
        themeMode: themeMode,
        goalDetails: goalDetails,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        UserProfile(
          email: widget.profile.email,
          userType: selectedUserType!,
          goals: _selectedPrimaryGoals.toList(),
          profileImageBytes: newImage,
          focusStyle: focusStyle,
          mainStruggle: mainStruggle,
          bestTimeOfDay: bestTimeOfDay,
          motivation: motivation,
          theme: theme,
          themeMode: themeMode,
          goalDetails: goalDetails,

          fullName: _nameController.text.trim(), 
          username: _usernameController.text.trim(), // Return new username
          notificationsPush: widget.profile.notificationsPush,
          notificationsEmail: widget.profile.notificationsEmail,
          notificationsSummary: widget.profile.notificationsSummary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    }
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

  Widget _buildGoalSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _relevantGoalKeys.map((primaryGoal) {
        final isSelected = _selectedPrimaryGoals.contains(primaryGoal);
        final subOptions = goalDefinitions[primaryGoal]!;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary Goal Header
              InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedPrimaryGoals.remove(primaryGoal);
                      // Optional: clear subs when unchecking primary? 
                      // _selectedSubGoals[primaryGoal]?.clear();
                    } else {
                      _selectedPrimaryGoals.add(primaryGoal);
                    }
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.blue : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      primaryGoal,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isSelected ? Colors.blue[900] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Sub Goals
              if (isSelected) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: subOptions.map((sub) {
                      final isSubSelected = _selectedSubGoals[primaryGoal]?.contains(sub) ?? false;
                      return FilterChip(
                        label: Text(sub, style: TextStyle(fontSize: 12)),
                        selected: isSubSelected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedSubGoals[primaryGoal]?.add(sub);
                            } else {
                              _selectedSubGoals[primaryGoal]?.remove(sub);
                            }
                          });
                        },
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
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

            const SizedBox(height: 10),

            const SizedBox(height: 24),
            
            // ==========================================
            // 🆕 ACCOUNT SETTINGS (Moved to Top)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.manage_accounts, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        "Account & Security",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Full Name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.person, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Username (Permanent once set)
                  TextField(
                    controller: _usernameController,
                    // Only read-only if we already had a username
                    readOnly: (widget.profile.username != null && widget.profile.username!.isNotEmpty),
                    style: TextStyle(
                         color: (widget.profile.username != null && widget.profile.username!.isNotEmpty) 
                            ? Colors.grey.shade600 
                            : Colors.black87
                    ),
                    decoration: InputDecoration(
                      labelText: "Username",
                      helperText: (widget.profile.username != null && widget.profile.username!.isNotEmpty) 
                          ? "Username is permanent" 
                          : "Set your unique username (Permanent)",
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      filled: true,
                      fillColor: (widget.profile.username != null && widget.profile.username!.isNotEmpty)
                          ? Colors.grey.shade200
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.alternate_email, size: 20, color: Colors.grey),
                      // Show lock if locked, else nothing or edit icon
                      suffixIcon: (widget.profile.username != null && widget.profile.username!.isNotEmpty)
                          ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                          : const Icon(Icons.edit, size: 16, color: Colors.blue),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const SizedBox(height: 16),

                  // Reset Password & Delete Account as Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetPassword,
                          icon: const Icon(Icons.lock_reset, size: 18),
                          label: const Text("Reset Password"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                       Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _deleteAccount,
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: const Text("Delete"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),


            
            const SizedBox(height: 32),
            const Divider(),

            _sectionTitle("I am mainly a"),
            Wrap(
              spacing: 8,
              children: allUserTypes.map((type) {
                return ChoiceChip(
                  label: Text(type),
                  selected: selectedUserType == type,
                  onSelected: (_) {
                    setState(() {
                      if (selectedUserType != type) {
                        selectedUserType = type;
                        // Reset goals on type switch to keep data clean
                        _selectedPrimaryGoals.clear();
                        for(var k in _selectedSubGoals.keys) {
                           _selectedSubGoals[k]?.clear();
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),

            _sectionTitle("My goals"),
            const Text("Select category to expand", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            _buildGoalSelection(),

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

            _sectionTitle("Theme Style"),
            const Text(
              "Select 'Focus' or 'Calm' to override standard mode.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _singleChoice(
              value: (theme == null || theme!.isEmpty || (theme != 'focus' && theme != 'calm')) ? 'standard' : theme,
              onPick: (v) {
                 theme = (v == 'standard') ? '' : v;
                 // Instant Preview
                 ThemeProvider.instance.update(
                   mode: (theme != null && theme!.isNotEmpty) ? theme! : (themeMode ?? 'system'),
                   accent: null, 
                 );
              },
              options: const [
                _Option("Standard", "standard"),
                _Option("Focus (Dark Blue)", "focus"),
                _Option("Calm (Soft Beige)", "calm"),
              ],
            ),

            _sectionTitle("Base Appearance"),
            const Text(
              "Applies when Style is 'Standard'.",
               style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
             _singleChoice(
              value: themeMode,
              onPick: (v) {
                themeMode = v;
                // Instant Preview
                 ThemeProvider.instance.update(
                   mode: (theme != null && theme!.isNotEmpty) ? theme! : (themeMode ?? 'system'),
                   accent: null,
                 );
              },
              options: const [
                _Option("System", "system"),
                _Option("Light", "light"),
                _Option("Dark", "dark"),
              ],
            ),
            

            
            const SizedBox(height: 32),
            GradientButton(
              text: "Save Changes",
              onPressed: _saveChanges,
              height: 54,
              colors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
              icon: Icons.check_circle_outline,
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = widget.profile.email;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password reset email sent to $email")),
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text(
          "This action is permanent. All your data, tasks, and history will be erased.\n\nAre you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteAccount();
        await FirebaseAuth.instance.signOut();
        // AuthGate will handle navigation
        if (!mounted) return;
        Navigator.popUntil(context, (route) => route.isFirst);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _Option {
  final String label;
  final String value;
  const _Option(this.label, this.value);
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.label,
    this.controller,
    required this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final ValueChanged<String> onSelect;

  const _ThemeOption(this.label, this.value, this.isSelected, this.onSelect);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
