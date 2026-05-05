// lib/screens/edit_profile_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';

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
        SnackBar(content: Text(AppLocalizations.of(context).pleaseSelectUserType)),
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
          SnackBar(content: Text("${AppLocalizations.of(context).errorUpdatingUsername}: $e"), backgroundColor: Colors.red),
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
        SnackBar(content: Text("${AppLocalizations.of(context).errorSavingProfile}: $e")),
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

  String _userTypeLabel(String type, AppLocalizations l) {
    switch (type) {
      case 'Student': return l.userTypeStudent;
      case 'Employee': return l.userTypeEmployee;
      case 'Freelancer': return l.userTypeFreelancer;
      case 'Other': return l.userTypeOther;
      default: return type;
    }
  }

  String _goalLabel(String goal, AppLocalizations l) {
    switch (goal) {
      case 'Study': return l.categoryStudy;
      case 'Work': return l.categoryWork;
      case 'Health': return l.categoryHealth;
      case 'Personal': return l.categoryPersonal;
      case 'Projects': return l.goalProjects;
      case 'Freelance': return l.goalFreelance;
      default: return goal;
    }
  }

  String _subGoalLabel(String sub, AppLocalizations l) {
    switch (sub) {
      case 'Exams': return l.subGoalExams;
      case 'Assignments': return l.subGoalAssignments;
      case 'Lectures': return l.subGoalLectures;
      case 'Reading': return l.subGoalReading;
      case 'Meetings': return l.subGoalMeetings;
      case 'Deep Work': return l.subGoalDeepWork;
      case 'Emails': return l.subGoalEmails;
      case 'Coding': return l.subGoalCoding;
      case 'Gym': return l.subGoalGym;
      case 'Walking': return l.subGoalWalking;
      case 'Sleep': return l.subGoalSleep;
      case 'Nutrition': return l.subGoalNutrition;
      case 'Family': return l.subGoalFamily;
      case 'Home': return l.subGoalHome;
      case 'Shopping': return l.subGoalShopping;
      case 'Self-care': return l.subGoalSelfCare;
      case 'Planning': return l.subGoalPlanning;
      case 'Implementation': return l.subGoalImplementation;
      case 'Testing': return l.subGoalTesting;
      case 'Delivery': return l.subGoalDelivery;
      case 'Client Work': return l.subGoalClientWork;
      case 'Admin': return l.subGoalAdmin;
      case 'Marketing': return l.subGoalMarketing;
      case 'Learning': return l.subGoalLearning;
      default: return sub;
    }
  }

  Widget _buildGoalSelection(AppLocalizations l) {
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
                      _goalLabel(primaryGoal, l),
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
                        label: Text(_subGoalLabel(sub, l), style: const TextStyle(fontSize: 12)),
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).editProfile),
        actions: [
          const LanguageToggleButton(),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: AppLocalizations.of(context).save,
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
                      Text(
                        AppLocalizations.of(context).accountAndSecurity,
                        style: const TextStyle(
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
                      labelText: AppLocalizations.of(context).fullName,
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
                      labelText: AppLocalizations.of(context).username,
                      helperText: (widget.profile.username != null && widget.profile.username!.isNotEmpty)
                          ? AppLocalizations.of(context).usernamePermanent
                          : AppLocalizations.of(context).usernameSetPermanent,
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
                          label: Text(AppLocalizations.of(context).resetPasswordButton),
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
                          label: Text(AppLocalizations.of(context).delete),
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

            _sectionTitle(l.iAmMainlyA),
            Wrap(
              spacing: 8,
              children: allUserTypes.map((type) {
                return ChoiceChip(
                  label: Text(_userTypeLabel(type, l)),
                  selected: selectedUserType == type,
                  onSelected: (_) {
                    setState(() {
                      if (selectedUserType != type) {
                        selectedUserType = type;
                        _selectedPrimaryGoals.clear();
                        for (var k in _selectedSubGoals.keys) {
                          _selectedSubGoals[k]?.clear();
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),

            _sectionTitle(l.myGoals),
            Text(l.selectCategoryToExpand, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            _buildGoalSelection(l),

            _sectionTitle(AppLocalizations.of(context).focusStyleSection),
            _singleChoice(
              value: focusStyle,
              onPick: (v) => focusStyle = v,
              options: [
                _Option(AppLocalizations.of(context).deepFocus, "deep_focus"),
                _Option(AppLocalizations.of(context).pomodoroLabel, "pomodoro"),
                _Option(AppLocalizations.of(context).flexibleLabel, "flexible"),
              ],
            ),

            _sectionTitle(AppLocalizations.of(context).biggestStruggle),
            _singleChoice(
              value: mainStruggle,
              onPick: (v) => mainStruggle = v,
              options: [
                _Option(AppLocalizations.of(context).distractionsLabel, "distractions"),
                _Option(AppLocalizations.of(context).procrastinationLabel, "procrastination"),
                _Option(AppLocalizations.of(context).burnoutLabel, "burnout"),
              ],
            ),

            _sectionTitle(AppLocalizations.of(context).bestTimeOfDayLabel),
            _singleChoice(
              value: bestTimeOfDay,
              onPick: (v) => bestTimeOfDay = v,
              options: [
                _Option(AppLocalizations.of(context).morningLabel, "morning"),
                _Option(AppLocalizations.of(context).afternoonLabel, "afternoon"),
                _Option(AppLocalizations.of(context).nightLabel, "night"),
              ],
            ),

            _sectionTitle(AppLocalizations.of(context).whatMotivatesYou),
            _singleChoice(
              value: motivation,
              onPick: (v) => motivation = v,
              options: [
                _Option(AppLocalizations.of(context).gradesLabel, "grades"),
                _Option(AppLocalizations.of(context).careerLabel, "career"),
                _Option(AppLocalizations.of(context).freedomLabel, "freedom"),
                _Option(AppLocalizations.of(context).growthLabel, "growth"),
                _Option(AppLocalizations.of(context).masteryLabel, "mastery"),
              ],
            ),

            _sectionTitle(AppLocalizations.of(context).themeStyle),
            Text(
              AppLocalizations.of(context).themeStyleDesc,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _singleChoice(
              value: (theme == null || theme!.isEmpty || (theme != 'focus' && theme != 'calm')) ? 'standard' : theme,
              onPick: (v) {
                 theme = (v == 'standard') ? '' : v;
                 ThemeProvider.instance.update(
                   mode: (theme != null && theme!.isNotEmpty) ? theme! : (themeMode ?? 'system'),
                   accent: null,
                 );
              },
              options: [
                _Option(AppLocalizations.of(context).themeStandard, "standard"),
                _Option(AppLocalizations.of(context).themeFocusDark, "focus"),
                _Option(AppLocalizations.of(context).themeCalmBeige, "calm"),
              ],
            ),

            _sectionTitle(AppLocalizations.of(context).baseAppearance),
            Text(
              AppLocalizations.of(context).baseAppearanceDesc,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
             _singleChoice(
              value: themeMode,
              onPick: (v) {
                themeMode = v;
                ThemeProvider.instance.update(
                  mode: (theme != null && theme!.isNotEmpty) ? theme! : (themeMode ?? 'system'),
                  accent: null,
                );
              },
              options: [
                _Option(AppLocalizations.of(context).appearanceSystem, "system"),
                _Option(AppLocalizations.of(context).appearanceLight, "light"),
                _Option(AppLocalizations.of(context).appearanceDark, "dark"),
              ],
            ),
            

            
            const SizedBox(height: 32),
            GradientButton(
              text: AppLocalizations.of(context).saveChanges,
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
        SnackBar(content: Text(AppLocalizations.of(context).passwordResetSentTo(email))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context).unexpectedError}: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteAccountTitle),
        content: Text(AppLocalizations.of(context).deleteAccountContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).deletePermanently),
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
          SnackBar(content: Text("${AppLocalizations.of(context).deleteFailed}: $e"), backgroundColor: Colors.red),
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
